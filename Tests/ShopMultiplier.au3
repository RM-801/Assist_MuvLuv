#include "..\Libs\ShopMultiplier.au3"
Global $active=True,$clicks=0,$mode="normal",$state=0,$polls=0
Check(ShopMultiplierParse("OK" & @LF & "0|0|20|20| M A X ")="MAX","MAX whitespace")
Check(ShopMultiplierParse("0|0|20|20|×10")="X10","times sign")
Check(ShopMultiplierParse("0|0|20|20|x1")="X1","lowercase x")
Check(ShopMultiplierParse("0|0|20|20|LvMAX")="","item level is not multiplier")
Check(ShopMultiplierParse("0|0|20|20|MAX" & @LF & "0|20|20|20|x1")="","conflicting readings")
Check(ShopEnsureMaxMultiplier() And $clicks=2,"x1 to x10 to MAX")
Check(ShopEnsureMaxMultiplier() And $clicks=2,"MAX is never toggled")
$mode="delayed"
$state=0
$clicks=0
$polls=0
Check(ShopEnsureMaxMultiplier() And $clicks=2,"wait for delayed transitions before another click")
$mode="stuck"
$state=0
$clicks=0
Check(Not ShopEnsureMaxMultiplier() And $clicks=1,"unresponsive control is not repeatedly clicked")
$mode="unknown"
$clicks=0
Check(Not ShopEnsureMaxMultiplier() And $clicks=0,"unreadable multiplier blocks clicking")
$mode="normal"
$active=False
Check(Not ShopEnsureMaxMultiplier() And $clicks=0,"interruption blocks clicking")
ConsoleWrite("PASS multiplier parsing; MAX no-op; cycle verification; delayed/stuck controls; unknown state; interruption." & @CRLF)
Exit 0
Func Check($ok,$label)
    If $ok Then Return
    ConsoleWrite("FAIL " & $label & @CRLF)
    Exit 1
EndFunc
Func ShopDailyActive()
    Return $active
EndFunc
Func ShopMultiplierRead()
    If $mode="unknown" Then Return ""
    If $mode="stuck" Then Return "X1"
    If $mode="delayed" And $polls>0 Then
        $polls-=1
        If $polls=0 Then $state+=1
    EndIf
    Local $values[3]=["X1","X10","MAX"]
    Return $values[$state]
EndFunc
Func ShopMultiplierClick()
    $clicks+=1
    If $mode="delayed" Then
        $polls=3
    ElseIf $mode="normal" Then
        $state+=1
    EndIf
    Return True
EndFunc
Func ShopMultiplierWait()
EndFunc
