#include "..\Libs\autoit-opencv-com\udf\opencv_udf_utils.au3"
#include "..\Libs\ImageScaleSafe.au3"
#include "..\Libs\ShopTabState.au3"
Global $root=@ScriptDir & "\..\"
_OpenCV_Open($root & "Libs\opencv\build\x64\vc16\bin\opencv_world4120.dll",$root & "Libs\autoit-opencv-com\autoit_opencv_com4120.dll")
Global $cv=_OpenCV_get()
If Not IsObj($cv) Then Exit 1
Local $names[3]=["physical","en","agile"],$scales[3]=[0.9,1,1.25]
For $selected=0 To 2
    Local $source=_OpenCV_imread_and_check(@ScriptDir & "\Fixtures\ShopTabs_" & $names[$selected] & ".png")
    For $i=0 To 2
        Local $tab=_OpenCV_ObjCreate("cv.Mat").create($source,_OpenCV_Rect(5+145*$i,5,135,35))
        For $scale In $scales
            Local $scaled=_AssistResize($cv,$tab,Int($tab.width*$scale),Int($tab.height*$scale))
            If ShopTabPixelsSelected($scaled,$cv) <> ($i=$selected) Then
                ConsoleWrite("FAIL: selected=" & $names[$selected] & "; tested=" & $names[$i] & "; scale=" & $scale & @CRLF)
                Exit 2
            EndIf
        Next
    Next
Next
If ShopTabPixelsSelected(False,$cv) Then Exit 3
ConsoleWrite("PASS: all three selected tabs, six unselected tabs and three scales, including cursor overlap." & @CRLF)
_OpenCV_Close()
Exit 0
