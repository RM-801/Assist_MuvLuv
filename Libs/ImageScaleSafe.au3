#include-once
Global $g_AssistResizeError = ""

Func _AssistResize($cvObject, $source, $width, $height)
    $g_AssistResizeError = ""
    If Not IsObj($source) Or Not IsObj($cvObject) Then Return SetError(1, 0, False)
    If $width < 1 Or $height < 1 Or $width > 16384 Or $height > 16384 Then
        $g_AssistResizeError = "Invalid resize dimensions: " & $width & "x" & $height
        Return SetError(2, 0, False)
    EndIf
    Local $handler = ObjEvent("AutoIt.Error", "_AssistResizeComError")
    Local $result = $cvObject.resize($source, _OpenCV_Size(Int($width), Int($height)))
    If $g_AssistResizeError <> "" Or Not IsObj($result) Then Return SetError(3, 0, False)
    Return $result
EndFunc

Func _AssistResizeComError($error)
    $g_AssistResizeError = "COM " & Hex($error.number) & ": " & $error.description & " " & $error.windescription
EndFunc
