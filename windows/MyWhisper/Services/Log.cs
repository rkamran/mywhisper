using System;
using System.Diagnostics;
using System.IO;

namespace MyWhisper.Services;

/// <summary>
/// Minimal file + debug logger. Writes to %LOCALAPPDATA%\MyWhisper\mywhisper.log
/// so dictation issues can be diagnosed the same way the macOS app uses OSLog.
/// </summary>
public static class Log
{
    private static readonly object Gate = new();
    private static string LogPath => Path.Combine(AppPaths.DataDirectory, "mywhisper.log");

    public static void Info(string message) => Write("INFO", message);
    public static void Warn(string message) => Write("WARN", message);
    public static void Error(string message) => Write("ERROR", message);

    private static void Write(string level, string message)
    {
        string line = $"{DateTime.Now:yyyy-MM-dd HH:mm:ss.fff} [{level}] {message}";
        Debug.WriteLine(line);
        try
        {
            lock (Gate)
                File.AppendAllText(LogPath, line + Environment.NewLine);
        }
        catch
        {
            // Logging must never throw into the dictation path.
        }
    }
}
