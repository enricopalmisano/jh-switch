; ============================================================
;  jhSwitch  –  Inno Setup 6 installer script
; ============================================================
;  Requirements: Inno Setup 6  (https://jrsoftware.org/isinfo.php)
;
;  Build options:
;    GUI  : open this file in the Inno Setup Compiler → Build → Compile
;    CLI  : "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\jhswitch.iss
;
;  The compiled installer is placed in installer\Output\jhswitch-setup.exe
; ============================================================

#define MyAppName      "jhSwitch"
#define MyAppVersion   "1.0.0"
#define MyAppPublisher "jhSwitch"
#define MyAppURL       "https://github.com/enricopalmisano/jh-switch"

[Setup]
; Unique ID — do NOT change after the first public release
AppId={{E6EB9933-F6E1-4348-BD8C-9A91662B8317}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; Install to %APPDATA%\jhswitch — no administrator elevation needed
DefaultDirName={userappdata}\jhswitch
DisableDirPage=yes
DisableProgramGroupPage=yes

; Output
OutputDir=Output
OutputBaseFilename=jhswitch-setup
Compression=lzma
SolidCompression=yes

; User-scope install (no UAC prompt)
PrivilegesRequired=lowest

; Windows 10 x64 minimum (jhSwitch is Windows x64 only)
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0

; Tell Windows to refresh environment variables in running shells
ChangesEnvironment=yes

; Control Panel registration (Add/Remove Programs)
UninstallDisplayName={#MyAppName} {#MyAppVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "..\jhswitch.cmd";   DestDir: "{app}"; Flags: ignoreversion
Source: "..\jhswitch.ps1";   DestDir: "{app}"; Flags: ignoreversion
Source: "..\providers.ps1";  DestDir: "{app}"; Flags: ignoreversion

[Messages]
; Shown on the final installer page
FinishedLabel=jhSwitch has been installed successfully.%n%nOpen a new terminal and run:%n    jhswitch --help

[Code]
{ ===========================================================
  User-scoped PATH helpers
  =========================================================== }

function GetUserPath: string;
begin
  if not RegQueryStringValue(HKCU, 'Environment', 'Path', Result) then
    Result := '';
end;

procedure SetUserPath(const Value: string);
begin
  { REG_EXPAND_SZ preserves any %VAR% references already in PATH }
  RegWriteExpandStringValue(HKCU, 'Environment', 'Path', Value);
end;

{ Add Dir to the user PATH if not already present (case-insensitive) }
procedure AddToUserPath(const Dir: string);
var
  Path, DirLower, Norm: string;
begin
  Path     := GetUserPath;
  DirLower := Lowercase(Dir);
  Norm     := ';' + Lowercase(Path) + ';';
  if Pos(';' + DirLower + ';', Norm) > 0 then Exit;   { already there }
  if (Length(Path) > 0) and (Path[Length(Path)] <> ';') then
    Path := Path + ';';
  SetUserPath(Path + Dir);
end;

{ Remove all occurrences of Dir from the user PATH (case-insensitive) }
procedure RemoveFromUserPath(const Dir: string);
var
  Path, DirLower, Work: string;
  P: Integer;
begin
  Path := GetUserPath;
  if Path = '' then Exit;

  DirLower := Lowercase(Dir);
  Work     := ';' + Path + ';';        { sentinel semicolons for uniform matching }

  repeat
    P := Pos(';' + DirLower + ';', Lowercase(Work));
    if P = 0 then Break;
    Delete(Work, P, 1 + Length(Dir));  { remove ;Dir, keep the trailing ; }
  until False;

  { strip sentinel semicolons }
  if (Length(Work) > 0) and (Work[1] = ';') then
    Delete(Work, 1, 1);
  if (Length(Work) > 0) and (Work[Length(Work)] = ';') then
    Delete(Work, Length(Work), 1);

  SetUserPath(Work);
end;

{ ===========================================================
  Inno Setup step hooks
  =========================================================== }

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
    AddToUserPath(ExpandConstant('{app}'));
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
    RemoveFromUserPath(ExpandConstant('{app}'));
end;
