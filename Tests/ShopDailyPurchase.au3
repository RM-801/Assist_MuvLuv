#include "..\Libs\MazeShopCache.au3"
#include "..\Libs\ShopDailyPurchase.au3"
Global $active=True,$page=0,$selected[4]=[0,0,0,0],$remaining[4]=[2,2,2,2]
Global $enabled[4]=[True,True,True,True],$clicks=0,$lastSlot=-1,$fail="",$accept=True,$readable=True
Global $opened=0,$wrongIdentity=False
$g_ShopCacheFile=@ScriptDir & "\daily-test-" & @AutoItPID & ".ini"
$g_ShopDetectedArea=200
OnAutoItExitRegister("Cleanup")
$g_ReportPriority="シャイ"
For $i=0 To 7
    Check(ShopBuyDaily(),"purchase yields")
    If $i<4 Then Check($lastSlot=2,"preferred report attribute")
Next
Check($clicks=8 And Not ShopBuyDaily(),"all four categories purchased to limit")
Check($remaining[2]=0 And $remaining[3]=0,"disk and unit included")
Check(IniRead($g_ShopCacheFile,"exchange." & ShopGameDay() & ".daily2","ConfirmedQuantity","0")="2","disk confirmation recorded")
Local $visits=$opened
Check(Not ShopBuyDaily() And $opened=$visits,"cached full skips navigation")
; A new game day must re-read the page instead of reusing yesterday's zero.
IniWrite($g_ShopCacheFile,"daily.0","Day","2000/01/01")
$remaining[0]=1
$g_ReportPriority="指定なし"
Check(ShopBuyDaily() And $lastSlot=0 And $remaining[0]=0,"unspecified still buys first report after reset")
; No ore must not be recorded as sold out, nor block other affordable pages.
ShopDailyInvalidate()
$remaining[0]=2
$remaining[2]=1
$enabled[0]=False
Check(ShopBuyDaily() And $page=2 And $remaining[2]=0,"skip unaffordable report but buy disk")
Check(Not ShopDailyCachedFull("0"),"unaffordable is not exhausted")
Check(Not ShopBuyDaily(),"allow upgrades when remaining daily items unaffordable")
$enabled[0]=True
$accept=False
$fail=""
Local $before=$clicks
Check(ShopBuyDaily() And $fail<>"" And $clicks=$before+1,"unconfirmed purchase keeps shop open without repeated clicks")
Check(Not ShopDailyCachedFull("0"),"failed purchase does not consume quota")
$accept=True
$readable=False
$fail=""
$before=$clicks
Check(ShopBuyDaily() And $fail<>"" And $clicks=$before,"unreadable counter does not buy or leave")
$readable=True
$wrongIdentity=True
$fail=""
Check(ShopBuyDaily() And $fail<>"" And $clicks=$before,"identity mismatch does not buy")
$active=False
Check(ShopBuyDaily() And $clicks=$before,"interruption prevents purchases")
ConsoleWrite("PASS daily reports/disk/unit; preferred/default attribute; cache/reset; shortage; unconfirmed purchase; unreadable counter; wrong item; interruption." & @CRLF)
Exit 0

Func Check($ok,$label)
    If $ok Then Return
    ConsoleWrite("FAIL " & $label & @CRLF)
    Exit 1
EndFunc
Func Cleanup()
    FileDelete($g_ShopCacheFile)
EndFunc
Func ShopDailyActive()
    Return $active
EndFunc
Func ShopDailyOpen()
    $opened+=1
    Return True
EndFunc
Func ShopDailySelect($i)
    $page=$i
    $selected[$i]+=1
    Return True
EndFunc
Func ShopDailySelected($i)
    Return $page=$i
EndFunc
Func ShopDailyReadCounter()
    If Not $readable Then Return "unknown"
    Return "OK" & @LF & "0|0|200|20|" & $remaining[$page] & "/2"
EndFunc
Func ShopDailyIdentity($i,$slot)
    Return Not $wrongIdentity
EndFunc
Func ShopDailyEnabled($slot)
    Return $enabled[$page]
EndFunc
Func ShopDailyClick($slot)
    $clicks+=1
    $lastSlot=$slot
    If $accept Then $remaining[$page]-=1
    Return True
EndFunc
Func ShopDailyWait()
EndFunc
Func ShopDailyDismissReward()
EndFunc
Func ShopDailyUncertain($reason)
    $fail=$reason
    Return True
EndFunc
Func WriteLog($text)
EndFunc
