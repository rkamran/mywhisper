using System.Globalization;
using System.Windows;
using System.Windows.Data;
using MyWhisper.Models;

namespace MyWhisper.Views;

/// <summary>true → Collapsed, false → Visible. The inverse of the built-in converter.</summary>
public sealed class InverseBoolToVisibilityConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
        => value is true ? Visibility.Collapsed : Visibility.Visible;

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => value is Visibility.Visible;
}

/// <summary>true → Visible, false → Collapsed.</summary>
public sealed class BoolToVisibilityConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
        => value is true ? Visibility.Visible : Visibility.Collapsed;

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => value is Visibility.Visible;
}

/// <summary>Renders the current <see cref="DictationState"/> as a short status line.</summary>
public sealed class DictationStatusConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        if (value is not DictationState state)
            return "";
        return state.Phase switch
        {
            DictationPhase.Idle => "Idle — hold Right Alt to dictate",
            DictationPhase.Recording => "Recording…",
            DictationPhase.Transcribing => "Transcribing…",
            DictationPhase.Typing => "Typing…",
            DictationPhase.NoSpeech => "No speech detected",
            DictationPhase.Error => state.Message ?? "Error",
            _ => ""
        };
    }

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => throw new NotSupportedException();
}
