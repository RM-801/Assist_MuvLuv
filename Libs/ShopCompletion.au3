#include-once
Global $g_ShopCompletionPages[7] = ["equipment.en", "equipment.agile", "equipment.physical", "excavate", "artifact.en", "artifact.agile", "artifact.physical"]
Global $g_ShopCompletionMax[7], $g_ShopCompletionLive[7]

Func ShopCompletionReset()
    For $i = 0 To 6
        $g_ShopCompletionMax[$i] = ShopCacheSkipPage($g_ShopCompletionPages[$i])
        $g_ShopCompletionLive[$i] = False
    Next
EndFunc

Func ShopCompletionRecord($page, $allMax)
    For $i = 0 To 6
        If $g_ShopCompletionPages[$i] <> $page Then ContinueLoop
        $g_ShopCompletionMax[$i] = $allMax
        $g_ShopCompletionLive[$i] = True
        Return
    Next
EndFunc

; 0: upgrades remain/unknown; 1: cached candidate needs review; 2: all live MAX.
Func ShopCompletionUpgradeState()
    Local $live = True
    For $i = 0 To 6
        If Not $g_ShopCompletionMax[$i] Then Return 0
        If Not $g_ShopCompletionLive[$i] Then $live = False
    Next
    Return $live ? 2 : 1
EndFunc

; The displayed counter is remaining daily exchanges / cap (0/cap is exhausted).
; Return -1 for ambiguous OCR, 0 when allowance remains, 1 only at a positive cap.
Func ShopCompletionParseCounter($text)
    Local $lines = StringSplit(StringStripCR($text), @LF, 1), $found = -1
    For $i = 1 To $lines[0]
        Local $parts = StringSplit($lines[$i], "|", 1)
        If $parts[0] <> 5 Then ContinueLoop
        Local $value = StringRegExpReplace($parts[5], "\s", "")
        Local $match = StringRegExp($value, "^(?:本日の購入回数[:：]?)?(\d{1,3})[/／](\d{1,3})$", 1)
        If Not IsArray($match) Then ContinueLoop
        If $found <> -1 Then Return -1
        Local $remaining = Int($match[0]), $cap = Int($match[1])
        If $cap < 1 Or $remaining > $cap Then Return -1
        $found = ($remaining = 0) ? 1 : 0
    Next
    Return $found
EndFunc
