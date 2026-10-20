#include-once
#include "MazeAreaTemplates.au3"
Global $g_TargetArea = 100, $g_AreaSteps = 0, $g_AreaLastRows = "", $g_AreaStuck = 0

Func MazeAreaFail($reason)
    WriteLog("Area stopped: " & $reason)
    ActionStop()
    GUICtrlSetData($lblStatus, "Area: Check log")
    MsgBox(48, "Maze area", $reason)
EndFunc

; OCR is limited to the area number/list, and never used to scan the shop.
Func MazeAreaOCR($region, $language = "ja*", $magnify = 1)
    Local $bounds = _WinAPI_GetPosWithoutShadow($sGameWinTitle)
    If Not IsArray($bounds) Then Return ""
    Local $scale = $bounds[3] / 712
    Local $crop[4] = [$bounds[0]+Int($region[0]*$scale), $bounds[1]+Int($region[1]*$scale), Int($region[2]*$scale), Int($region[3]*$scale)]
    Local $mat = _OpenCV_GetDesktopScreenMat($crop)
    If Not IsObj($mat) Then Return ""
    $mat = _AssistResize($cv, $mat, $region[2]*$magnify, $region[3]*$magnify)
    If Not IsObj($mat) Then Return ""
    Local $path = @ScriptDir & "\Data\AreaRead-" & @AutoItPID
    $cv.imwrite($path & ".png", $mat)
    FileDelete($path & ".txt")
    Local $pid = Run('"' & @SystemDir & '\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -File "' & @ScriptDir & '\Libs\ReadImageText.ps1" -ImagePath "' & $path & '.png" -OutputPath "' & $path & '.txt" -PreferredLanguage "' & $language & '"', @ScriptDir, @SW_HIDE)
    If $pid = 0 Then Return ""
    Local $timer = TimerInit()
    While ProcessExists($pid)
        If Not $bRunning Or TimerDiff($timer) > 12000 Then
            ProcessClose($pid)
            Return ""
        EndIf
        Sleep(50)
    WEnd
    Local $text = FileRead($path & ".txt")
    If StringLeft($text, 2) <> "OK" Then Return ""
    Return $text
EndFunc

Func MazeAreaPoint($x, $y, $wheel = "", $wheelTicks = 5)
    If Not $bRunning Or Not WinActive($sGameWinTitle) Then Return False
    Local $bounds = _WinAPI_GetPosWithoutShadow($sGameWinTitle)
    If Not IsArray($bounds) Then Return False
    Local $scale = $bounds[3]/712
    MouseMove($bounds[0]+Int($x*$scale), $bounds[1]+Int($y*$scale), 0)
    If $wheel = "" Then
        MouseClick("left")
    Else
        MouseWheel($wheel, $wheelTicks)
    EndIf
    Return True
EndFunc

; Fast travel far from the visible range; small steps near the target prevent overshoot.
Func MazeAreaWheelTicks($target, $min, $max)
    Local $distance = ($target < $min) ? $min-$target : $target-$max
    If $distance >= 30 Then Return 15
    If $distance >= 10 Then Return 8
    Return 2
EndFunc

; Exact digits only: a truncated row or OCR punctuation is not an area ID.
Func MazeAreaParse($text, $list = False)
    $text = StringRegExpReplace($text, "\s", "")
    If Not $list Then $text = StringReplace(StringReplace($text, "ø", "0"), "Ø", "0")
    If $list Then
        If Not StringRegExp($text, "^[エ工]リア[1-9][0-9]{0,2}$") Then Return 0
        $text = StringRegExpReplace($text, "^[エ工]リア", "")
    EndIf
    If Not StringRegExp($text, "^[1-9][0-9]{0,2}$") Then Return 0
    Return Int($text)
EndFunc

Func MazeAreaHandle()
    Local $dialog[4] = [450, 55, 370, 70], $entry[4] = [1000, 550, 245, 80]
    If IsArray(ImageSearch($sGameResDir & "Maze_AreaDialog.png", 0.88, $dialog)) Then
        $g_AreaSteps += 1
        If $g_AreaSteps > 130 Then
            MazeAreaFail("Area selection timed out. Check the requested area is unlocked.")
            Return True
        EndIf
        Local $rows[4] = [372, 195, 145, 410]
        Local $text = MazeAreaOCR($rows)
        If Not $bRunning Then Return True
        If $text = $g_AreaLastRows Then
            $g_AreaStuck += 1
        Else
            $g_AreaStuck = 0
        EndIf
        $g_AreaLastRows = $text
        Local $lines = StringSplit(StringStripCR($text), @LF, 1), $min = 1000, $max = 0
        For $i = 1 To $lines[0]
            Local $parts = StringSplit($lines[$i], "|", 1)
            If $parts[0] <> 5 Then ContinueLoop
            Local $number = MazeAreaParse($parts[5], True)
            If $number = 0 Then ContinueLoop
            If $number < $min Then $min = $number
            If $number > $max Then $max = $number
            If $number = $g_TargetArea Then
                If Not MazeAreaPoint(550, 195+Number($parts[2])+Number($parts[4])/2) Then Return True
                Sleep(600)
                If Not $bRunning Or Not WinActive($sGameWinTitle) Then Return True
                Local $confirm[4] = [650, 610, 210, 65]
                If Not ClickImage($sGameResDir & "Maze_AreaConfirm.png", 0.90, 0, 0, False, 2, $confirm) Then MazeAreaFail("Area confirmation button was not found.")
                ActionPause(1200)
                Return True
            EndIf
        Next
        If $max = 0 Or $g_AreaStuck >= 3 Then
            MazeAreaFail("Cannot read/find the target area. Check the area list and try again.")
            Return True
        EndIf
        MazeAreaPoint(570, 450, ($g_TargetArea < $min) ? "down" : "up", MazeAreaWheelTicks($g_TargetArea, $min, $max))
        ActionPause(350)
        Return True
    EndIf
    If Not IsArray(ImageSearch($sGameResDir & "Maze_Enter.png", 0.85, $entry)) Then Return False
    $g_ShopDetectedArea = 0
    Local $numberArea[4] = [875, 230, 270, 90]
    ; Windows OCR reads the stylized 190 as "1 so". Prefer verified artwork.
    Local $current = MazeAreaTemplateNumber($numberArea, $sGameResDir)
    If $current = 0 Then
        Local $text = MazeAreaOCR($numberArea, "en*")
        Local $lines = StringSplit(StringStripCR($text), @LF, 1)
        For $i = 1 To $lines[0]
            Local $parts = StringSplit($lines[$i], "|", 1)
            If $parts[0] <> 5 Then ContinueLoop
            Local $n = MazeAreaParse($parts[5])
            If $n > 0 Then
                If $current > 0 Then
                    $current = 0
                    ExitLoop
                EndIf
                $current = $n
            EndIf
        Next
    EndIf
    If Not $bRunning Or Not WinActive($sGameWinTitle) Then Return True
    If $current = $g_TargetArea Then
        $g_ShopDetectedArea = $current
        $g_AreaSteps = 0
        WriteLog("Maze area verified: " & $current)
        ClickImage($sGameResDir & "Maze_Enter.png", 0.85, 0, 0, False, 2, $entry)
        ActionPause(1500)
    ElseIf $g_AreaSteps > 0 And $current = 0 Then
        MazeAreaFail("Selected area's number cannot be verified. Exploration has not started.")
    Else
        Local $select[4] = [1000, 155, 170, 65]
        If Not ClickImage($sGameResDir & "Maze_AreaSelect.png", 0.88, 0, 0, False, 2, $select) Then MazeAreaFail("Area selection button was not found.")
        ActionPause(700)
    EndIf
    Return True
EndFunc
