using System;
using System.Collections.Generic;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using NAudio.CoreAudioApi;
using NAudio.Wave;
using NAudio.Wave.SampleProviders;

namespace MyWhisper.Services;

/// <summary>
/// Captures microphone audio via WASAPI and resamples it to the 16 kHz mono
/// float format Whisper expects. One <see cref="Start"/>/<see cref="StopAsync"/>
/// pair per dictation session.
/// </summary>
public sealed class AudioRecorder : IDisposable
{
    private const int TargetSampleRate = 16_000;

    private readonly object _lock = new();
    private WasapiCapture? _capture;
    private MMDevice? _device;
    private MemoryStream _raw = new();
    private WaveFormat? _captureFormat;
    private TaskCompletionSource? _stopped;

    /// <summary>Friendly name of the device bound on the last <see cref="Start"/>.</summary>
    public string? LastDeviceName { get; private set; }

    /// <summary>
    /// Begins capturing from <paramref name="device"/>, taking ownership of it
    /// (the device is disposed when capture stops). Captured in WASAPI shared
    /// mode at the device's native mix format; conversion happens on stop.
    /// </summary>
    public void Start(MMDevice device)
    {
        StopImmediate();

        lock (_lock)
        {
            _raw = new MemoryStream();
        }

        _device = device;
        LastDeviceName = device.FriendlyName;
        _capture = new WasapiCapture(device);
        _captureFormat = _capture.WaveFormat;
        _stopped = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        _capture.DataAvailable += OnDataAvailable;
        _capture.RecordingStopped += OnRecordingStopped;
        _capture.StartRecording();
    }

    /// <summary>
    /// Stops capture, waits for the device to settle, and returns the recorded
    /// audio as 16 kHz mono float samples.
    /// </summary>
    public async Task<float[]> StopAsync()
    {
        var capture = _capture;
        if (capture is null)
            return Array.Empty<float>();

        capture.StopRecording();
        if (_stopped is not null)
            await _stopped.Task.ConfigureAwait(false);

        capture.DataAvailable -= OnDataAvailable;
        capture.RecordingStopped -= OnRecordingStopped;
        capture.Dispose();
        _capture = null;
        _device?.Dispose();
        _device = null;

        byte[] rawBytes;
        WaveFormat? format;
        lock (_lock)
        {
            rawBytes = _raw.ToArray();
            format = _captureFormat;
        }

        if (rawBytes.Length == 0 || format is null)
            return Array.Empty<float>();

        return Resample(rawBytes, format);
    }

    private void OnDataAvailable(object? sender, WaveInEventArgs e)
    {
        lock (_lock)
        {
            _raw.Write(e.Buffer, 0, e.BytesRecorded);
        }
    }

    private void OnRecordingStopped(object? sender, StoppedEventArgs e)
        => _stopped?.TrySetResult();

    /// <summary>Synchronous best-effort teardown used to guarantee a clean Start.</summary>
    private void StopImmediate()
    {
        var capture = _capture;
        if (capture is null)
            return;
        try
        {
            capture.DataAvailable -= OnDataAvailable;
            capture.RecordingStopped -= OnRecordingStopped;
            capture.StopRecording();
            capture.Dispose();
        }
        catch { /* best effort */ }
        _capture = null;
        _device?.Dispose();
        _device = null;
    }

    /// <summary>Decodes captured bytes, downmixes to mono, and resamples to 16 kHz.</summary>
    private static float[] Resample(byte[] rawBytes, WaveFormat format)
    {
        using var ms = new MemoryStream(rawBytes);
        using var rawStream = new RawSourceWaveStream(ms, format);

        // ToSampleProvider yields interleaved float samples at the capture rate.
        ISampleProvider source = rawStream.ToSampleProvider();
        float[] interleaved = ReadAll(source);

        int channels = format.Channels;
        float[] mono;
        if (channels <= 1)
        {
            mono = interleaved;
        }
        else
        {
            mono = new float[interleaved.Length / channels];
            for (int i = 0; i < mono.Length; i++)
            {
                float sum = 0f;
                for (int c = 0; c < channels; c++)
                    sum += interleaved[(i * channels) + c];
                mono[i] = sum / channels;
            }
        }

        if (format.SampleRate == TargetSampleRate)
            return mono;

        var monoProvider = new FloatArraySampleProvider(mono, format.SampleRate);
        var resampler = new WdlResamplingSampleProvider(monoProvider, TargetSampleRate);
        return ReadAll(resampler);
    }

    private static float[] ReadAll(ISampleProvider provider)
    {
        int chunk = Math.Max(4096, provider.WaveFormat.SampleRate);
        var buffer = new float[chunk];
        var all = new List<float>();
        int read;
        while ((read = provider.Read(buffer, 0, buffer.Length)) > 0)
            all.AddRange(new ArraySegment<float>(buffer, 0, read));
        return all.ToArray();
    }

    public void Dispose() => StopImmediate();
}

/// <summary>Exposes a fixed mono float buffer as an <see cref="ISampleProvider"/>.</summary>
internal sealed class FloatArraySampleProvider : ISampleProvider
{
    private readonly float[] _samples;
    private int _position;

    public FloatArraySampleProvider(float[] samples, int sampleRate)
    {
        _samples = samples;
        WaveFormat = WaveFormat.CreateIeeeFloatWaveFormat(sampleRate, 1);
    }

    public WaveFormat WaveFormat { get; }

    public int Read(float[] buffer, int offset, int count)
    {
        int available = Math.Min(count, _samples.Length - _position);
        if (available <= 0)
            return 0;
        Array.Copy(_samples, _position, buffer, offset, available);
        _position += available;
        return available;
    }
}
