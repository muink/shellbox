:: ref: http://www.bathome.net/thread-33196-1-1.html
@echo off
set "SrcFile=%~1"
set "Args=%~2"
set "LnkFile=%~3"
set "IconPath=%~4"
call :CreateShort "%SrcFile%" "%Args%" "%LnkFile%" "%IconPath%"
exit

::Arguments              Target program arguments
::Description            Shortcut notes
::Hotkey                 Hotkey for shortcuts
::IconLocation           Shortcut icon, the default icon will be used if empty
::TargetPath             Target
::WindowStyle            1: Default 3: Maximized 7: Minimized
::WorkingDirectory       Working directory

:CreateShort
mshta VBScript:Execute("Set a=CreateObject(""WScript.Shell""):Set b=a.CreateShortcut(""%~3""):b.TargetPath=""%~1"":b.WorkingDirectory=""%~dp1"":b.Arguments=""%~2"":b.IconLocation=""%~4"":b.Save:close")
