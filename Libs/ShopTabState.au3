#include-once

; Test only a known type-tab rectangle, never the whole shop screen.
; The filled blue background survives cursors/hover effects that corrupt glyph templates.
Func ShopTabPixelsSelected($mat, $cvObject)
    If Not IsObj($mat) Or Not IsObj($cvObject) Then Return False
    If $mat.empty() Then Return False
    Local $hsv = $cvObject.cvtColor($mat, $CV_COLOR_BGR2HSV)
    Local $mask = $cvObject.inRange($hsv, _OpenCV_Scalar(85,100,100), _OpenCV_Scalar(115,255,255))
    Return $cvObject.countNonZero($mask) / ($mat.width * $mat.height) >= 0.40
EndFunc
