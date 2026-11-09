Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
psScriptPath = scriptDir & "\overlay.ps1"

sh.CurrentDirectory = scriptDir
command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & psScriptPath & """ > """ & scriptDir & "\overlay_log.txt"" 2>&1"
sh.Run command, 0, False