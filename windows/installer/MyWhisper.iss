; Inno Setup script for MyWhisper.
;
; Invoked by windows/scripts/package.ps1 when iscc.exe is on PATH. Two values
; are passed in on the command line:
;
;   /DProductVersion=1.0.3                       (from .csproj <Version>)
;   /DPublishDir=...absolute path to publish...  (output of `dotnet publish`)
;
; If you invoke iscc.exe directly without those, defaults are used so the
; script still compiles for testing.

#ifndef ProductVersion
  #define ProductVersion "0.0.0"
#endif
#ifndef PublishDir
  #define PublishDir "..\.publish\win-x64"
#endif

[Setup]
; A stable AppId is required for clean upgrades and uninstall registration.
; Do NOT regenerate this GUID across releases.
AppId={{8B4C9B6A-7A9D-4A6E-9C3F-B9A1E0B7F3A2}
AppName=MyWhisper
AppVersion={#ProductVersion}
AppVerName=MyWhisper {#ProductVersion}
AppPublisher=Sociobot Inc
AppPublisherURL=https://github.com/rkamran/mywhisper
AppSupportURL=https://github.com/rkamran/mywhisper/issues
AppUpdatesURL=https://github.com/rkamran/mywhisper/releases
VersionInfoVersion={#ProductVersion}
VersionInfoProductName=MyWhisper
VersionInfoCompany=Sociobot Inc

; Default to per-user install (no admin prompt). Let the user opt up to
; "all users" via the standard PrivilegesRequiredOverridesAllowed dialog.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

DefaultDirName={autopf}\MyWhisper
DefaultGroupName=MyWhisper
DisableProgramGroupPage=yes

ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible

OutputDir=..\dist
OutputBaseFilename=MyWhisper-{#ProductVersion}-Setup
SetupIconFile=..\MyWhisper\Assets\app.ico
UninstallDisplayIcon={app}\MyWhisper.exe
Compression=lzma2/ultra
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked
Name: "autostart";   Description: "Start MyWhisper when I sign in to Windows"; GroupDescription: "Startup:"; Flags: unchecked

[Files]
Source: "{#PublishDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\MyWhisper";                              Filename: "{app}\MyWhisper.exe"
Name: "{group}\{cm:UninstallProgram,MyWhisper}";        Filename: "{uninstallexe}"
Name: "{autodesktop}\MyWhisper";                        Filename: "{app}\MyWhisper.exe"; Tasks: desktopicon

[Registry]
; Optional "run at login" entry, mirrored under HKCU so it follows the user
; without admin rights. Removed on uninstall.
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; \
    ValueName: "MyWhisper"; ValueData: """{app}\MyWhisper.exe"""; \
    Flags: uninsdeletevalue; Tasks: autostart

[Run]
Filename: "{app}\MyWhisper.exe"; Description: "Launch MyWhisper"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; Try to close a running MyWhisper before the uninstaller deletes files.
Filename: "{cmd}"; Parameters: "/C taskkill /IM MyWhisper.exe /F"; Flags: runhidden; RunOnceId: "KillMyWhisper"
