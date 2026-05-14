using MyWhisper.Models;
using NAudio.CoreAudioApi;

namespace MyWhisper.Services;

/// <summary>Enumerates WASAPI capture endpoints and resolves the system default.</summary>
public static class AudioDeviceProbe
{
    /// <summary>All active capture (input) devices, sorted by friendly name.</summary>
    public static IReadOnlyList<AudioInputDevice> ListInputDevices()
    {
        try
        {
            using var enumerator = new MMDeviceEnumerator();
            var devices = enumerator
                .EnumerateAudioEndPoints(DataFlow.Capture, DeviceState.Active)
                .Select(d =>
                {
                    var device = new AudioInputDevice(d.ID, d.FriendlyName);
                    d.Dispose();
                    return device;
                })
                .OrderBy(d => d.Name, StringComparer.CurrentCultureIgnoreCase)
                .ToList();
            return devices;
        }
        catch
        {
            return Array.Empty<AudioInputDevice>();
        }
    }

    /// <summary>Friendly name of the current default capture device, or null.</summary>
    public static string? DefaultInputDeviceName()
    {
        try
        {
            using var enumerator = new MMDeviceEnumerator();
            if (!enumerator.HasDefaultAudioEndpoint(DataFlow.Capture, Role.Communications))
                return null;
            using var device = enumerator.GetDefaultAudioEndpoint(DataFlow.Capture, Role.Communications);
            return device.FriendlyName;
        }
        catch
        {
            return null;
        }
    }

    /// <summary>
    /// Resolves an <see cref="MMDevice"/> by its stable endpoint ID. Returns null
    /// if the device is gone (unplugged); caller should fall back to default.
    /// Caller owns the returned device and must dispose it.
    /// </summary>
    public static MMDevice? DeviceById(string id)
    {
        try
        {
            using var enumerator = new MMDeviceEnumerator();
            return enumerator.GetDevice(id);
        }
        catch
        {
            return null;
        }
    }

    /// <summary>Default capture device, or null. Caller owns and disposes it.</summary>
    public static MMDevice? DefaultInputDevice()
    {
        try
        {
            using var enumerator = new MMDeviceEnumerator();
            if (!enumerator.HasDefaultAudioEndpoint(DataFlow.Capture, Role.Communications))
                return null;
            return enumerator.GetDefaultAudioEndpoint(DataFlow.Capture, Role.Communications);
        }
        catch
        {
            return null;
        }
    }
}
