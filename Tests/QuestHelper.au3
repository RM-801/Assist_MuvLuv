#include "..\Libs\autoit-opencv-com\udf\opencv_udf_utils.au3"
#include "..\Libs\ImageScaleSafe.au3"
Global $root=@ScriptDir & "\..\"
_OpenCV_Open($root & "Libs\opencv\build\x64\vc16\bin\opencv_world4120.dll",$root & "Libs\autoit-opencv-com\autoit_opencv_com4120.dll")
Global $cv=_OpenCV_get(),$sGameResDir=$root & "Games\MuvLuv\",$sGameWinTitle="offline fixture",$bRunning=True
Global $screen=0,$clicks=0,$lastX=0,$lastY=0,$lastWheel="",$failure="",$omit=""
#include "..\Libs\QuestHelper.au3"
If Not IsObj($cv) Then Exit 99

Local $scales[3]=[0.9,1,1.25]
For $scale In $scales
    $clicks=0
    QuestHelperReset()
    $g_AutoHelper=False
    LoadScreen("prep",$scale)
    Check(Not TryQuestHelper() And $clicks=0,"disabled does nothing")
    $g_AutoHelper=True
    Check(TryQuestHelper() And $g_HelperStage=1 And $clicks=1,"open helper slot")
    Check($lastX>290 And $lastX<450 And $lastY>480 And $lastY<530,"click observed empty slot")
    LoadScreen("formation",$scale)
    Check(TryQuestHelper() And $lastWheel="up","scroll sorted roster to top")
    $lastWheel=""
    Check(TryQuestHelper() And $g_HelperStage=3,"select first helper")
    Check($lastX>670 And $lastX<805 And $lastY>225 And $lastY<365,"click first candidate")
    LoadScreen("selected",$scale)
    Check(TryQuestHelper() And $g_HelperStage=4,"verify selection then confirm")
    Check($lastX>1020 And $lastY>635,"confirm formation")
    LoadScreen("prep",$scale)
    $omit="Empty"
    Check(TryQuestHelper() And $g_HelperStage=5,"verify return to preparation")
    Local $before=$clicks
    Check(Not TryQuestHelper() And $clicks=$before,"allow deploy without reselecting")
    $omit=""
    LoadScreen("settings",$scale)
    Check(Not TryQuestHelper() And $g_HelperStage=0,"reset after leaving preparation")
Next

; Verify sort-setting and direction branches with the actual screenshot controls.
QuestHelperReset()
$g_HelperStage=2
$g_HelperStarted=TimerInit()
LoadScreen("formation",1)
$omit="Power"
Check(TryQuestHelper() And $lastX>1120 And $lastY<180,"open display settings")
$omit=""
LoadScreen("settings",1)
Check(TryQuestHelper() And $lastX>500 And $lastX<750 And $lastY>600,"accept combat-power sort")
$omit="PowerSelected"
Check(TryQuestHelper() And $lastX>900 And $lastY<330,"select combat-power radio")
$omit="PowerOption"
Check(TryQuestHelper() And $lastX>120 And $lastX<300 And $lastY>200 And $lastY<300,"open sort tab")
$omit="Descending"
LoadScreen("formation",1)
Check(TryQuestHelper() And $g_HelperDescendingToggled And $lastX>1170,"toggle ascending/unknown arrow once")
$omit=""
Check(TryQuestHelper() And $g_HelperScrolled,"verify down arrow after toggle")
$g_HelperStage=3
$failure=""
Check(TryQuestHelper() And Not $bRunning And $failure<>"","failed selection blocks deploy")
$bRunning=True
QuestHelperReset()
$g_HelperStage=2
$g_HelperStarted=TimerInit()
$g_HelperScrolled=True
LoadScreen("selected",1)
$before=$clicks
Check(TryQuestHelper() And $g_HelperStage=3 And $clicks=$before,"already selected first helper is not toggled off")
QuestHelperReset()
LoadScreen("prep",1)
$omit="Empty"
$before=$clicks
Check(Not TryQuestHelper() And $clicks=$before,"no helper slot does not replace a regular member")
$omit=""
$g_HelperStage=4
$g_HelperStarted=TimerInit()
$failure=""
Check(TryQuestHelper() And Not $bRunning And $failure<>"","empty slot after confirmation blocks deploy")
ConsoleWrite("PASS helper selection at three scales; sorting, descending verification, repeat frames, disabled mode, failed selection." & @CRLF)
_OpenCV_Close()
Exit 0

Func LoadScreen($name,$scale)
    $screen=_OpenCV_imread_and_check(@ScriptDir & "\Fixtures\QuestHelper\" & $name & ".png")
    If $scale<>1 Then $screen=_AssistResize($cv,$screen,Int(1264*$scale),Int(712*$scale))
EndFunc
Func Check($ok,$label)
    If $ok Then Return
    ConsoleWrite("FAIL " & $label & "; stage=" & $g_HelperStage & "; x=" & $lastX & "; y=" & $lastY & "; reason=" & $failure & @CRLF)
    Exit 1
EndFunc
Func _WinAPI_GetPosWithoutShadow($title)
    Local $r[4]=[0,0,$screen.width,$screen.height]
    Return $r
EndFunc
Func MazeAreaPoint($x,$y,$wheel="",$ticks=5)
    $clicks+=1
    $lastX=$x
    $lastY=$y
    $lastWheel=$wheel
    Return True
EndFunc
Func ActionPause($ms)
EndFunc
Func ActionStop()
    $bRunning=False
    QuestHelperReset()
EndFunc
Func QuestHelperNotifyFailure($reason)
    $failure=$reason
EndFunc
Func WriteLog($message)
    ConsoleWrite($message & @CRLF)
EndFunc
Func ImageSearch($path,$threshold,$area,$baseHeight,$size)
    If $omit<>"" And StringInStr($path,"\" & $omit & ".png") Then Return False
    Local $scale=$screen.height/$baseHeight
    Local $crop=_OpenCV_ObjCreate("cv.Mat").create($screen,_OpenCV_Rect(Int($area[0]*$scale),Int($area[1]*$scale),Int($area[2]*$scale),Int($area[3]*$scale)))
    Local $templ=_OpenCV_imread_and_check($path)
    $templ=_AssistResize($cv,$templ,Int($templ.width*$scale*$size),Int($templ.height*$scale*$size))
    If $templ.width>$crop.width Or $templ.height>$crop.height Then Return False
    Local $matches=_OpenCV_FindTemplate($cv.cvtColor($crop,$CV_COLOR_BGR2GRAY),$cv.cvtColor($templ,$CV_COLOR_BGR2GRAY),$threshold)
    If Not IsArray($matches) Then Return False
    If UBound($matches)=0 Then Return False
    Local $r[4]=[$matches[0][0],$matches[0][1],$templ.width,$templ.height]
    Return $r
EndFunc
