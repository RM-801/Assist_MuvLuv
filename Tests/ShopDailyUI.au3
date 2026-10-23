#include "..\Libs\autoit-opencv-com\udf\opencv_udf_utils.au3"
#include "..\Libs\ImageScaleSafe.au3"
Global $root=@ScriptDir & "\..\",$sGameResDir=$root & "Games\MuvLuv\",$sGameWinTitle="offline",$bRunning=True
_OpenCV_Open($root & "Libs\opencv\build\x64\vc16\bin\opencv_world4120.dll",$root & "Libs\autoit-opencv-com\autoit_opencv_com4120.dll")
Global $cv=_OpenCV_get(),$screen=0,$clicks=0
#include "..\Libs\ShopDailyUI.au3"
If Not IsObj($cv) Then Exit 99
Local $names[4]=["report1","report2","disk","unit"],$scales[3]=[0.9,1,1.25]
For $page=0 To 3
    Local $source=_OpenCV_imread_and_check(@ScriptDir & "\Fixtures\ShopDaily\" & $names[$page] & ".png")
    For $scale In $scales
        $screen=_AssistResize($cv,$source,Int(1264*$scale),Int(712*$scale))
        For $i=0 To 3
            Check(ShopDailySelected($i)=($page=$i),"selected page=" & $page & "; tested=" & $i & "; scale=" & $scale)
        Next
        Check(ShopDailyOpen() And ShopDailySelect($page) And $clicks=0,"already selected daily page requires no category click")
        Local $n=($page<2) ? 6 : 1
        For $slot=0 To $n-1
            Check(ShopDailyIdentity($page,$slot),"item identity page=" & $page & "; slot=" & $slot & "; scale=" & $scale)
        Next
    Next
Next
ConsoleWrite("PASS captured Daily tabs and all item identities at three scales; already-selected category/tab requires no click." & @CRLF)
_OpenCV_Close()
Exit 0
Func Check($ok,$label)
    If $ok Then Return
    ConsoleWrite("FAIL " & $label & @CRLF)
    Exit 1
EndFunc
Func ImageSearch($path,$threshold,$area,$baseHeight,$size)
    Local $scale=$screen.height/$baseHeight
    Local $crop=_OpenCV_ObjCreate("cv.Mat").create($screen,_OpenCV_Rect(Int($area[0]*$scale),Int($area[1]*$scale),Int($area[2]*$scale),Int($area[3]*$scale)))
    Local $templ=_OpenCV_imread_and_check($path)
    $templ=_AssistResize($cv,$templ,Int($templ.width*$scale*$size),Int($templ.height*$scale*$size))
    If $templ.width>$crop.width Or $templ.height>$crop.height Then Return False
    Local $matches=_OpenCV_FindTemplate($cv.cvtColor($crop,$CV_COLOR_BGR2GRAY),$cv.cvtColor($templ,$CV_COLOR_BGR2GRAY),$threshold)
    If Not IsArray($matches) Then Return False
    If UBound($matches)=0 Then Return False
    Local $hit[4]=[0,0,$templ.width,$templ.height]
    Return $hit
EndFunc
Func MazeAreaPoint($x,$y)
    $clicks+=1
    Return False
EndFunc
Func _WinAPI_GetPosWithoutShadow($title)
    Return False
EndFunc
Func MazeAreaOCR($area,$language,$scale)
    Return ""
EndFunc
Func ClickImage($path,$threshold,$x,$y,$cooldown,$factor,$area)
    Return False
EndFunc
Func ShopPurchaseUncertain($reason)
EndFunc
