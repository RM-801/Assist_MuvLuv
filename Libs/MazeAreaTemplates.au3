#include-once

; Observed START AREA digits. Never infer the area from the configured target.
Func MazeAreaTemplateNumber($region, $directory)
    Local $files = FileFindFirstFile($directory & "Maze_Area*.png"), $current = 0
    If $files = -1 Then Return 0
    While True
        Local $name = FileFindNextFile($files)
        If @error Then ExitLoop
        Local $number = StringRegExp($name, "^Maze_Area([1-9][0-9]{0,2})\.png$", 1)
        If Not IsArray($number) Then ContinueLoop
        If Not IsArray(ImageSearch($directory & $name, 0.96, $region)) Then ContinueLoop
        ; Reject conflicting matches rather than choosing the first one.
        If $current > 0 Then
            FileClose($files)
            Return 0
        EndIf
        $current = Int($number[0])
    WEnd
    FileClose($files)
    Return $current
EndFunc
