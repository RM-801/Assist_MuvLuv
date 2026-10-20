#include "..\Libs\autoit-opencv-com\udf\opencv_udf_utils.au3"
#include "..\Libs\MazeAreaDigits.au3"
Global $root=@ScriptDir & "\..\"
_OpenCV_Open($root & "Libs\opencv\build\x64\vc16\bin\opencv_world4120.dll",$root & "Libs\autoit-opencv-com\autoit_opencv_com4120.dll")
Global $cv=_OpenCV_get()
If Not IsObj($cv) Then Exit 1
Local $fixtures[19][2] = [ _
    ["100",100],["130",130],["140",140],["156",156],["178",178],["190",190],["200",200], _
    ["composed-210",210],["composed-234",234],["composed-567",567],["composed-890",890],["composed-999",999], _
    ["composed-1",1],["composed-20",20],["composed-0",0],["composed-012",0],["composed-1000",0], _
    ["blank",0],["unknown",0] ]
Local $scales[3]=[0.9,1,1.25],$checks=0,$started=TimerInit()
For $i=0 To UBound($fixtures)-1
    Local $source=_OpenCV_imread_and_check(@ScriptDir & "\Fixtures\AreaDigits\" & $fixtures[$i][0] & ".png")
    For $scale In $scales
        Local $scaled=_AssistResize($cv,$source,Int($source.width*$scale),Int($source.height*$scale))
        Local $actual=MazeAreaDigitNumber($scaled,$cv,$root & "Games\MuvLuv\")
        If $actual<>$fixtures[$i][1] Then
            ConsoleWrite("FAIL " & $fixtures[$i][0] & " scale=" & $scale & " expected=" & $fixtures[$i][1] & " actual=" & $actual & @CRLF)
            Exit 2
        EndIf
        $checks+=1
    Next
Next
; The same visible number must not be accepted when a digit is cut off.
Local $source=_OpenCV_imread_and_check(@ScriptDir & "\Fixtures\AreaDigits\200.png")
Local $cut=_OpenCV_ObjCreate("cv.Mat").create($source,_OpenCV_Rect(40,0,270,100))
If MazeAreaDigitNumber($cut,$cv,$root & "Games\MuvLuv\")<>0 Then Exit 3
If MazeAreaDigitNumber(False,$cv,$root & "Games\MuvLuv\")<>0 Then Exit 4
If MazeAreaDigitNumber($source,$cv,@ScriptDir & "\missing-assets\")<>0 Then Exit 5
ConsoleWrite("PASS " & $checks & " number/scale cases; real and composed numbers; invalid, missing and clipped inputs rejected; elapsed ms=" & Int(TimerDiff($started)) & @CRLF)
_OpenCV_Close()
Exit 0
