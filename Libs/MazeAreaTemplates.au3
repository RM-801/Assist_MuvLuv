#include-once

; Observed START AREA digits. Never infer the area from the configured target.
Func MazeAreaTemplateNumber($region, $directory)
    Local $known[3] = [100, 130, 190], $current = 0
    For $i = 0 To UBound($known)-1
        If Not IsArray(ImageSearch($directory & "Maze_Area" & $known[$i] & ".png", 0.96, $region)) Then ContinueLoop
        ; Reject conflicting matches rather than choosing the first one.
        If $current > 0 Then Return 0
        $current = $known[$i]
    Next
    Return $current
EndFunc
