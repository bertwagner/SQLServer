#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

^j::
; SAVE LAST FILE IN SNAGIT EDITOR AND IMPORT INTO PREMIERE OVERLAYS BIN

; CHECK THAT OVERLAYS FOLDER IS OPEN
if WinExist("Overlays")
    winactivate Overlays
else
	MsgBox, "An Overlays folder is not open"

; GET PATH OF OVERLAYS FOLDER
for window in ComObjCreate("Shell.Application").Windows
{
    try Fullpath := window.Document.Folder.Self.Path
    SplitPath, Fullpath, title
    If (title = "Overlays")
        break
}
; MsgBox, %Fullpath%

; SWITCH TO SNAGIT EDITOR WINDOW
IfWinExist ahk_exe SnagitEditor.exe
	winactivate ahk_exe SnagitEditor.exe
else
	Run, "C:\Program Files (x86)\TechSmith\Snagit 13\SnagitEditor.exe"
WinWait ahk_exe SnagitEditor.exe
WinActivate ahk_exe SnagitEditor.exe
WinWaitActive ahk_exe SnagitEditor.exe

; SAVE LAST IMAGE/VIDEO IN EDITOR WINDOW TO THE CURRENTLY OPEN OVERLAYS FOLDER
Send, ^a
Send, ^+s
Send, ^c
sleep 1000

Send, {HOME}
Send, %Fullpath%
Send, \
Send, {ENTER}
ClipWait
NewImageName := clipboard

; Wait for SnagitEditor to finish saving
sleep 1000


; SWITCH TO PREMIERE
IfWinExist ahk_exe Adobe Premiere Pro.exe
	winactivate ahk_exe Adobe Premiere Pro.exe
else
{
	MsgBox, "Premiere is not currently open"
    return
}
WinWait ahk_exe Adobe Premiere Pro.exe
WinActivate ahk_exe Adobe Premiere Pro.exe
WinWaitActive ahk_exe Adobe Premiere Pro.exe


; Assumes the Overlays bin is open
Send, ^i
Send, %Fullpath%
Send,  \
Send, %NewImageName%
Send, {ENTER}
return
