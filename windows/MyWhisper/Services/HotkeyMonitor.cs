using System.Diagnostics;
using System.Runtime.InteropServices;

namespace MyWhisper.Services;

/// <summary>
/// Global push-to-talk monitor. Installs a low-level keyboard hook and raises
/// <see cref="Pressed"/> / <see cref="Released"/> when the Right Alt key
/// transitions. The hook is listen-only — it never swallows the key, so AltGr
/// behaviour on international layouts is preserved.
///
/// Must be created on the UI thread (the hook callback is delivered on the
/// thread that installed it, which needs a running message loop).
/// </summary>
public sealed class HotkeyMonitor : IDisposable
{
    public event Action? Pressed;
    public event Action? Released;

    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;
    private const int WM_KEYUP = 0x0101;
    private const int WM_SYSKEYDOWN = 0x0104;
    private const int WM_SYSKEYUP = 0x0105;
    private const int VK_RMENU = 0xA5; // Right Alt

    // The delegate must be kept alive for the lifetime of the hook, otherwise
    // the GC collects it and the callback crashes the process.
    private readonly LowLevelKeyboardProc _proc;
    private IntPtr _hookHandle = IntPtr.Zero;
    private bool _isHeld;

    public HotkeyMonitor()
    {
        _proc = HookCallback;
    }

    public bool IsRunning => _hookHandle != IntPtr.Zero;

    /// <summary>Installs the keyboard hook. Throws if installation fails.</summary>
    public void Start()
    {
        if (_hookHandle != IntPtr.Zero)
            return;

        using var process = Process.GetCurrentProcess();
        using var module = process.MainModule!;
        _hookHandle = SetWindowsHookEx(WH_KEYBOARD_LL, _proc, GetModuleHandle(module.ModuleName), 0);

        if (_hookHandle == IntPtr.Zero)
            throw new InvalidOperationException(
                $"Failed to install keyboard hook (Win32 error {Marshal.GetLastWin32Error()}).");
    }

    public void Stop()
    {
        if (_hookHandle == IntPtr.Zero)
            return;
        UnhookWindowsHookEx(_hookHandle);
        _hookHandle = IntPtr.Zero;
        _isHeld = false;
    }

    private IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
    {
        if (nCode >= 0)
        {
            var data = Marshal.PtrToStructure<KBDLLHOOKSTRUCT>(lParam);
            if (data.vkCode == VK_RMENU)
            {
                int msg = (int)wParam;
                bool isDown = msg is WM_KEYDOWN or WM_SYSKEYDOWN;
                bool isUp = msg is WM_KEYUP or WM_SYSKEYUP;

                if (isDown && !_isHeld)
                {
                    _isHeld = true;
                    Pressed?.Invoke();
                }
                else if (isUp && _isHeld)
                {
                    _isHeld = false;
                    Released?.Invoke();
                }
            }
        }

        // Listen-only: always pass the event through.
        return CallNextHookEx(_hookHandle, nCode, wParam, lParam);
    }

    public void Dispose() => Stop();

    // ── Win32 interop ───────────────────────────────────────────────────────

    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential)]
    private struct KBDLLHOOKSTRUCT
    {
        public uint vkCode;
        public uint scanCode;
        public uint flags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern IntPtr GetModuleHandle(string lpModuleName);
}
