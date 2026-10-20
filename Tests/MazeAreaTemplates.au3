#include "..\Libs\autoit-opencv-com\udf\opencv_udf_utils.au3"
#include "..\Libs\ImageScaleSafe.au3"
#include "..\Libs\MazeAreaTemplates.au3"

Global $root = @ScriptDir & "\..\"
_OpenCV_Open($root & "Libs\opencv\build\x64\vc16\bin\opencv_world4120.dll", $root & "Libs\autoit-opencv-com\autoit_opencv_com4120.dll")
Global $cv = _OpenCV_get(), $screen = 0, $scale = 1, $forceAmbiguous = False
If Not IsObj($cv) Then Exit 1
Local $region[4] = [0, 0, 270, 90], $scales[3] = [1, 0.9, 1.25]
Local $source = _OpenCV_imread_and_check(@ScriptDir & "\Fixtures\Maze_Area190.png")
For $i = 0 To UBound($scales)-1
    $scale = $scales[$i]
    $screen = _AssistResize($cv, $source, Int($source.width*$scale), Int($source.height*$scale))
    If MazeAreaTemplateNumber($region, $root & "Games\MuvLuv\") <> 190 Then Exit 2+$i
Next
$scale = 1
Local $oldAreas[2] = [100, 130]
For $i = 0 To 1
    $screen = _OpenCV_imread_and_check($root & "Games\MuvLuv\Maze_Area" & $oldAreas[$i] & ".png")
    If MazeAreaTemplateNumber($region, $root & "Games\MuvLuv\") <> $oldAreas[$i] Then Exit 5+$i
Next
$screen = _OpenCV_imread_and_check($root & "Games\MuvLuv\Maze_AreaSelect.png")
If MazeAreaTemplateNumber($region, $root & "Games\MuvLuv\") <> 0 Then Exit 7
$forceAmbiguous = True
If MazeAreaTemplateNumber($region, $root & "Games\MuvLuv\") <> 0 Then Exit 8
ConsoleWrite("PASS: captured 190 at three scales; 100/130 stay distinct; unrelated and conflicting matches rejected." & @CRLF)
_OpenCV_Close()
Exit 0

; Feed offline pixels into the same grayscale matcher used by ImageSearch.
Func ImageSearch($path, $threshold, $region)
    Local $hit[4] = [0, 0, 1, 1]
    If $forceAmbiguous Then Return $hit
    Local $templ = _OpenCV_imread_and_check($path)
    $templ = _AssistResize($cv, $templ, Int($templ.width*$scale), Int($templ.height*$scale))
    If $templ.width > $screen.width Or $templ.height > $screen.height Then Return False
    Local $grayScreen = $cv.cvtColor($screen, $CV_COLOR_BGR2GRAY)
    Local $grayTemplate = $cv.cvtColor($templ, $CV_COLOR_BGR2GRAY)
    Local $matches = _OpenCV_FindTemplate($grayScreen, $grayTemplate, $threshold)
    If IsArray($matches) And UBound($matches)>0 Then Return $hit
    Return False
EndFunc
