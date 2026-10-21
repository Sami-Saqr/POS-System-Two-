#define MyAppName "DietKing"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Codva"
#define MyAppExeName "DietKing.exe"

[Setup]
AppId={{D9E6C4F2-5E5A-4C2B-9D31-7A8D52C42026}

AppName={#MyAppName}
AppVersion={#MyAppVersion}

; Company / Developer
AppPublisher={#MyAppPublisher}
AppComments="DietKing software developed by Codva, a software development company specializing in innovative software solutions across multiple industries. Owned by Khaled Sameh.\nبرنامج DietKing تم تطويره بواسطة Codva، وهي شركة متخصصة في تطوير البرمجيات والحلول التقنية المبتكرة لمختلف القطاعات. مملوك لـ Khaled Sameh."
AppContact="Codva - Khaled Sameh"

; Version information
VersionInfoCompany="Codva"
VersionInfoDescription="DietKing Restaurant Management Software"
VersionInfoCopyright="Copyright (C) Codva - Khaled Sameh"

DefaultDirName={autopf}\DietKing
DefaultGroupName={#MyAppName}

OutputDir=output
OutputBaseFilename=DietKing Setup

Compression=lzma
SolidCompression=yes

ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=admin

; DietKing application icon - unchanged
SetupIconFile=dietking.ico
UninstallDisplayIcon={app}\{#MyAppExeName}

; Codva branding shown ONLY during installation
WizardImageFile=codva_setup.bmp

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{autodesktop}\DietKing"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{autoprograms}\DietKing"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "تشغيل DietKing"; Flags: nowait postinstall skipifsilent