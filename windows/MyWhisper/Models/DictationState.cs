namespace MyWhisper.Models;

/// <summary>Runtime phase of the dictation pipeline, surfaced in the tray tooltip/icon.</summary>
public enum DictationPhase
{
    Idle,
    Recording,
    Transcribing,
    Typing,
    NoSpeech,
    Error
}

/// <summary>Immutable snapshot of the current dictation state.</summary>
public readonly record struct DictationState(DictationPhase Phase, string? Message = null)
{
    public static readonly DictationState Idle = new(DictationPhase.Idle);
    public static readonly DictationState Recording = new(DictationPhase.Recording);
    public static readonly DictationState Transcribing = new(DictationPhase.Transcribing);
    public static readonly DictationState Typing = new(DictationPhase.Typing);
    public static readonly DictationState NoSpeech = new(DictationPhase.NoSpeech);

    public static DictationState Error(string message) => new(DictationPhase.Error, message);
}

/// <summary>A selectable audio capture device.</summary>
public readonly record struct AudioInputDevice(string Id, string Name)
{
    public override string ToString() => Name;
}
