# ChronaOverlay
Fellowship Aeona chrona bar marks

Lines over chrona bar for Oblivion/Restore continuity.

*Auto detects bar placement, UI scale from configs in AppData
*F9 to update (redraw) if changed placement, Ctrl+0 to close it.
*Hides when fellowship not in focus 

Made with powershell and winforms, nothing need to be installed on windows, can run direct from terminal or with extra vbs file for double-click and to hide terminal window.
Main script code (feel free to reuse, inspire, remake and recheck):
overlay.ps1
Save in any separate Folder.
For easier launch with double click and hidden terminal window, put RUN.vbs in same folder

For manual run via terminal use:
powershell -NoProfile -ExecutionPolicy Bypass -File C:\<YourFolderPath>\overlay.ps1
