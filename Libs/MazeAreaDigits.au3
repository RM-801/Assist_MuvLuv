#include-once
#include "ImageScaleSafe.au3"

; Input is only the START AREA number rectangle, without rank/reward labels.
; Split dark glyphs by empty columns; classify each independently of the target.
Func MazeAreaDigitNumber($source, $cvObject, $directory)
    If Not IsObj($source) Or Not IsObj($cvObject) Then Return 0
    If $source.empty() Then Return 0
    Local $gray = $cvObject.cvtColor($source, $CV_COLOR_BGR2GRAY)
    Local $mask = $cvObject.inRange($gray, _OpenCV_Scalar(0), _OpenCV_Scalar(110))
    Local $width = $mask.width, $height = $mask.height
    If $width<20 Or $height<20 Then Return 0
    ; Reduce in OpenCV once instead of making a COM call for every pixel column.
    Local $columns = $cvObject.reduce($mask,0,$CV_REDUCE_SUM,Default,$CV_32S).asArray()
    Local $start = -1, $result = "", $glyphs = 0
    For $x = 0 To $width
        Local $ink = False
        If $x<$width Then
            $ink = $columns[0][$x] >= 3*255
        EndIf
        If $ink And $start<0 Then $start = $x
        If $ink Or $start<0 Then ContinueLoop
        Local $glyphWidth = $x-$start
        ; Reject edge fragments even when they are too thin to classify.
        If $start=0 Or $x=$width Then Return 0
        If $glyphWidth>=8 Then
            Local $top = -1, $bottom = -1
            Local $strip = _OpenCV_ObjCreate("cv.Mat").create($mask,_OpenCV_Rect($start,0,$glyphWidth,$height))
            Local $rows = $cvObject.reduce($strip,1,$CV_REDUCE_SUM,Default,$CV_32S).asArray()
            For $y = 0 To $height-1
                If $rows[$y]<2*255 Then ContinueLoop
                If $top<0 Then $top = $y
                $bottom = $y
            Next
            Local $glyphHeight = $bottom-$top+1
            If $top<=0 Or $bottom>=$height-1 Then Return 0
            If $glyphHeight<$height*0.50 Or $glyphHeight>$height*0.95 Then Return 0
            If $glyphWidth/$glyphHeight<0.20 Or $glyphWidth/$glyphHeight>1.3 Then Return 0
            Local $glyph = _OpenCV_ObjCreate("cv.Mat").create($mask, _OpenCV_Rect($start,$top,$glyphWidth,$glyphHeight))
            Local $digit = MazeAreaClassifyDigit($glyph, $cvObject, $directory)
            If $digit<0 Then Return 0
            If $glyphs=0 And $digit=0 Then Return 0
            $result &= String($digit)
            $glyphs += 1
            If $glyphs>3 Then Return 0
        EndIf
        $start = -1
    Next
    If $glyphs=0 Then Return 0
    Return Int($result)
EndFunc

Func MazeAreaNormalizeDigit($glyph, $cvObject)
    Local $resized = _AssistResize($cvObject, $glyph, 32, 48)
    If Not IsObj($resized) Then Return False
    Return $cvObject.inRange($resized, _OpenCV_Scalar(128), _OpenCV_Scalar(255))
EndFunc

Func MazeAreaClassifyDigit($glyph, $cvObject, $directory)
    Static $templates[10], $loadedDirectory = ""
    If $loadedDirectory<>$directory Then
        For $i=0 To 9
            Local $path = $directory & "MazeDigits\" & $i & ".png"
            If Not FileExists($path) Then Return -1
            Local $image = _OpenCV_imread_and_check($path)
            If Not IsObj($image) Then Return -1
            $templates[$i] = MazeAreaNormalizeDigit($cvObject.cvtColor($image,$CV_COLOR_BGR2GRAY),$cvObject)
            If Not IsObj($templates[$i]) Then Return -1
        Next
        $loadedDirectory = $directory
    EndIf
    Local $candidate = MazeAreaNormalizeDigit($glyph,$cvObject)
    If Not IsObj($candidate) Then Return -1
    Local $best = 1, $second = 1, $answer = -1
    For $i=0 To 9
        Local $difference = $cvObject.absdiff($candidate,$templates[$i])
        Local $error = $cvObject.countNonZero($difference)/(32*48)
        If $error<$best Then
            $second = $best
            $best = $error
            $answer = $i
        ElseIf $error<$second Then
            $second = $error
        EndIf
    Next
    ; Require both a good fit and separation from the next-best digit.
    If $best>0.12 Or $second-$best<0.04 Then Return -1
    Return $answer
EndFunc
