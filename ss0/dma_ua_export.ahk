#SingleInstance Force
SetTitleMatchMode 2

; ---------------- Adjust paths here ----------------
InputFolder := "D:\Guien MEMS Lab Final\new_method\ss0\cerr_158"
ExportFolder := InputFolder . "\export"
UA_WindowTitle := "Universal Analysis"

x_Menu := 21    ; Replace with real X coordinate of "File" menu
y_Menu := 65    ; Replace with real Y coordinate of "File" menu

; Create export folder if it doesn't exist
DirCreate(ExportFolder)

; Loop through every file (excluding folders)
Loop Files, InputFolder "\*.*", "F"
{
    ; Skip the "export" folder if mistakenly included
    if (A_LoopFileName = "export")
        continue

    CurrentFile := A_LoopFileFullPath
    ExportedFile := ExportFolder "\" A_LoopFileName ".txt"

    ; Activate Universal Analysis window
    WinActivate(UA_WindowTitle)
    WinWaitActive(UA_WindowTitle)
    Sleep(500)

    MouseMove(x_Menu, y_Menu)
    Sleep(300)
    MouseClick "left"
    Sleep(500)

    Send("{Down}")    ; Navigate to "Open File"
    Sleep(300)
    Send("{Enter}")   ; Select "Open File"
    Sleep(1000)

    ; -------- Step 2: Type filename --------
    Send(CurrentFile)
    Sleep(500)
    Send("{Enter}")
    Sleep(800)
    Send("{Enter}")   ; Extra confirmation if appears
    Sleep(1500)

    ; ---- STEP 2: Export via File > Export Data File > TTS Signals ----
    Send("!f")  ; Alt+F to open "File" menu
    Sleep(300)
    Send("{Down 11}")
    Sleep(300)
    Send("{Right}")
    Sleep(300)
    Send("{Enter}")
    Sleep(1000) ; Wait for export dialog

    ; ---- STEP 3: Confirm Export Settings ----
    Send("{Enter}")  ; Accept defaults (Spreadsheet + Unicode)
    Sleep(500)

    ; ---- STEP 4: Save file to export folder ----
    Send(ExportedFile)
    Sleep(300)
    Send("{Enter}")
    Sleep(1000) ; Wait for save to complete

    ; ---- STEP 5: Close current file via Menu ----
    Send("!f")  ; Open File menu
    Sleep(300)
    Send("c")   ; Press "Close"
    Sleep(500)
    Send("{Enter}")
    ; Handle prompt to save analysis (press 'N' for No)
    Sleep(500)
}

; Completion Message
MsgBox("✅ Done exporting all files to: " ExportFolder)
