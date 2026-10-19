#include-once
Global $g_StoryWasVisible = False

; Match the white lettering, excluding the chapter illustration from both images.
Func StoryContinueRect()
    Local $bounds = _WinAPI_GetPosWithoutShadow($sGameWinTitle)
    If Not IsArray($bounds) Then Return False
    Local $scale = $bounds[3]/712
    Local $crop[4] = [$bounds[0]+Int(790*$scale), $bounds[1]+Int(570*$scale), Int(350*$scale), Int(110*$scale)]
    Local $scene = _OpenCV_GetDesktopScreenMat($crop)
    Local $templ = _OpenCV_imread_and_check($sGameResDir & "StoryUI\TapContinue.png")
    If Not IsObj($scene) Or Not IsObj($templ) Then Return False
    $scene = _AssistResize($cv, $scene, 350, 110)
    If Not IsObj($scene) Then Return False
    Local $whiteMin = _OpenCV_Scalar(205,205,205), $whiteMax = _OpenCV_Scalar(255,255,255)
    Local $screenLetters = $cv.GaussianBlur($cv.inRange($scene, $whiteMin, $whiteMax), _OpenCV_Size(3,3), 0)
    Local $sizes[5] = [1, 1.025, 1.05, 0.975, 0.95]
    For $size In $sizes
        Local $sized = _AssistResize($cv, $templ, Int($templ.width*$size), Int($templ.height*$size))
        If Not IsObj($sized) Then ContinueLoop
        Local $letters = $cv.GaussianBlur($cv.inRange($sized, $whiteMin, $whiteMax), _OpenCV_Size(3,3), 0)
        Local $matches = _OpenCV_FindTemplate($screenLetters, $letters, 0.70)
        If Not IsArray($matches) Then ContinueLoop
        If UBound($matches) = 0 Then ContinueLoop
        Local $rect[4] = [Int((790+$matches[0][0])*$scale), Int((570+$matches[0][1])*$scale), Int($sized.width*$scale), Int($sized.height*$scale)]
        Return $rect
    Next
    Return False
EndFunc

; Count actual icon colors, not grayscale template scores, so pink is never toggled off.
Func StoryFastColor($rect, $region)
    Local $bounds = _WinAPI_GetPosWithoutShadow($sGameWinTitle)
    If Not IsArray($bounds) Then Return "unknown"
    Local $scale = $bounds[3]/712
    Local $crop[4] = [$bounds[0]+Int($region[0]*$scale)+$rect[0], $bounds[1]+Int($region[1]*$scale)+$rect[1], $rect[2], $rect[3]]
    Local $mat = _OpenCV_GetDesktopScreenMat($crop)
    If Not IsObj($mat) Then Return "unknown"
    Local $pink = $cv.countNonZero($cv.inRange($mat, _OpenCV_Scalar(80, 0, 215), _OpenCV_Scalar(230, 145, 255)))
    Local $blue = $cv.countNonZero($cv.inRange($mat, _OpenCV_Scalar(180, 110, 0), _OpenCV_Scalar(255, 225, 100)))
    If $pink > 25*$scale*$scale And $pink > $blue*2 Then Return "pink"
    If $blue > 25*$scale*$scale And $blue > $pink*2 Then Return "blue"
    Return "unknown"
EndFunc

; Translucent choice backgrounds change with the scene. Recognize two long pink
; bands with the expected spacing instead of a textured rounded-end template.
Func StoryChoiceRect()
    Local $bounds = _WinAPI_GetPosWithoutShadow($sGameWinTitle)
    If Not IsArray($bounds) Then Return False
    Local $scale = $bounds[3]/712
    Local $crop[4] = [$bounds[0]+Int(650*$scale), $bounds[1]+Int(275*$scale), Int(560*$scale), Int(190*$scale)]
    Local $mat = _OpenCV_GetDesktopScreenMat($crop)
    If Not IsObj($mat) Then Return False
    $mat = _AssistResize($cv, $mat, 560, 190)
    If Not IsObj($mat) Then Return False
    Local $hsv = $cv.cvtColor($mat, $CV_COLOR_BGR2HSV)
    Local $mask = $cv.inRange($hsv, _OpenCV_Scalar(140, 55, 130), _OpenCV_Scalar(179, 255, 255))
    Local $starts[3], $ends[3], $count = 0, $start = -1, $lastFilled = -1
    ; Text/hover highlights can interrupt a band. Bridge small holes, but keep
    ; the larger gap between the two buttons separate. Re-evaluate every frame.
    For $y = 0 To 200 Step 2
        Local $filled = False
        If $y < 190 Then
            Local $row = _OpenCV_ObjCreate("cv.Mat").create($mask, _OpenCV_Rect(0, $y, 560, 2))
            $filled = ($cv.countNonZero($row) > 560*2*0.40)
        EndIf
        If $filled And $start < 0 Then $start = $y
        If $filled Then $lastFilled = $y+2
        If Not $filled And $start >= 0 And $y-$lastFilled >= 8 Then
            If $lastFilled-$start >= 24 Then
                If $count >= 3 Then Return False
                $starts[$count] = $start
                $ends[$count] = $lastFilled
                $count += 1
            EndIf
            $start = -1
        EndIf
    Next
    If $count <> 2 Then Return False
    Local $gap = $starts[1]-$ends[0]
    If $gap < 10 Or $gap > 50 Then Return False
    If $ends[0]-$starts[0] > 75 Or $ends[1]-$starts[1] > 75 Then Return False
    Local $rect[4] = [650, 275+$starts[0], 560, $ends[0]-$starts[0]]
    Return $rect
EndFunc

Func TryStoryUI()
    If Not $bRunning Or Not WinActive($sGameWinTitle) Then Return False
    Local $fastArea[4] = [790, 30, 110, 85], $expandArea[4] = [1170, 28, 94, 85]
    Local $fast = ImageSearch($sGameResDir & "StoryUI\Fast.png", 0.85, $fastArea)
    Local $expand = ImageSearch($sGameResDir & "StoryUI\Expand.png", 0.90, $expandArea)
    If Not IsArray($fast) And Not IsArray($expand) Then
        If $g_StoryWasVisible Then GUICtrlSetData($lblStatus, "Status: Running")
        $g_StoryWasVisible = False
        Return False
    EndIf
    $g_StoryWasVisible = True
    If Not $bRunning Or Not WinActive($sGameWinTitle) Then Return True

    Local $choice = StoryChoiceRect()
    If IsArray($choice) Then
        If $bRunning And WinActive($sGameWinTitle) Then
            Local $bounds = _WinAPI_GetPosWithoutShadow($sGameWinTitle)
            If IsArray($bounds) Then
                Local $scale = $bounds[3]/712
                Local $clickRect[4] = [Int($choice[0]*$scale), Int($choice[1]*$scale), Int($choice[2]*$scale), Int($choice[3]*$scale)]
                ClickRelateWindow($bounds, $clickRect)
                WriteLog("Story: clicked top dialogue option; will check again after pause.")
                ActionPause(1000)
            EndIf
        EndIf
        Return True
    EndIf
    If IsArray($fast) Then
        Local $color = StoryFastColor($fast, $fastArea)
        If $color = "pink" Then
            GUICtrlSetData($lblStatus, "Story: Fast ON")
        ElseIf $color = "blue" Then
            If $bRunning And WinActive($sGameWinTitle) Then
                If ClickImage($sGameResDir & "StoryUI\Fast.png", 0.85, 0, 0, False, 2, $fastArea) Then
                    WriteLog("Story: enabled fast-forward; verify pink on next frame.")
                    ActionPause(700)
                EndIf
            EndIf
        Else
            GUICtrlSetData($lblStatus, "Story: Check fast")
        EndIf
        Return True
    EndIf
    If ClickImage($sGameResDir & "StoryUI\Expand.png", 0.90, 0, 0, False, 2, $expandArea) Then
        WriteLog("Story: opened playback controls.")
        ActionPause(500)
    EndIf
    Return True
EndFunc
