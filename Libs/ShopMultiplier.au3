#include-once

Func ShopMultiplierParse($text)
    Local $lines=StringSplit(StringStripCR($text),@LF,1),$result=""
    For $i=1 To $lines[0]
        Local $p=StringSplit($lines[$i],"|",1)
        If $p[0]<>5 Then ContinueLoop
        Local $value=StringUpper(StringRegExpReplace($p[5],"\s", ""))
        If $value<>"MAX" And Not StringRegExp($value,"^[X×✕＊*][1-9][0-9]{0,3}$") Then ContinueLoop
        If $result<>"" Then Return ""
        $result=StringRegExpReplace($value,"^[×✕＊*]","X")
    Next
    Return $result
EndFunc

; Observe every transition: a delayed click must never cycle MAX back to x1.
Func ShopEnsureMaxMultiplier()
    Local $value=""
    For $attempt=1 To 3
        If Not ShopDailyActive() Then Return False
        $value=ShopMultiplierRead()
        If $value<>"" Then ExitLoop
        ShopMultiplierWait()
    Next
    If $value="" Then Return False
    For $step=0 To 6
        If Not ShopDailyActive() Then Return False
        If $value="MAX" Then Return True
        If $step=6 Then Return False
        If Not ShopMultiplierClick() Then Return False
        Local $next=""
        For $attempt=1 To 8
            ShopMultiplierWait()
            If Not ShopDailyActive() Then Return False
            $next=ShopMultiplierRead()
            If $next<>"" And $next<>$value Then ExitLoop
        Next
        If $next="" Or $next=$value Then Return False
        $value=$next
    Next
    Return False
EndFunc
