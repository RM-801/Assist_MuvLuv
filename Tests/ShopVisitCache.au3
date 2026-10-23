#include "..\Libs\MazeShopCache.au3"
#include "..\Libs\ShopCompletion.au3"
#include "..\Libs\ShopOre.au3"
Global $balance=100,$secondBalance=100,$reads=0,$exits=0,$stops=0,$active=True
$g_ShopCacheFile=@ScriptDir & "\visit-test-" & @AutoItPID & ".ini"
OnAutoItExitRegister("Cleanup")
Check(ShopCacheInitialize(@ScriptDir & "\..\Data\MazeShop.defaults.ini"),"initialize")
$g_ShopDetectedArea=200
ShopCacheBeginVisit()
For $page In $g_ShopCompletionPages
    ShopCacheMarkPageMax($page)
    IniWrite($g_ShopCacheFile,ShopCachePageSection($page),"VerifiedAt","2020/01/01 00:00:00")
Next
For $i=0 To 3
    ShopDailyRecord(String($i),"0|0|100|20|0/24")
Next
ShopCacheEndVisit()
For $i=1 To 20
    ShopCacheBeginVisit()
    Check(Not $g_ShopCacheFullReview And ShopCacheSkipPage("artifact.physical"),"old MAX cache survives visits without a full scan")
    Check(ShopDailyCachedFull("0"),"daily cache survives new visit")
    ShopCacheEndVisit()
Next
ShopCacheBeginVisit()
ShopCompletionReset()
Check(ShopCompletionUpgradeState()=1,"cached completion without page visits")
Check(Not ShopExitWhenEmpty() And $exits=0 And $stops=0,"nonzero balance not treated as depleted")
$balance=0
$secondBalance=100
$reads=0
Check(Not ShopExitWhenEmpty(),"transient zero rejected")
$balance=-1
$reads=0
Check(Not ShopExitWhenEmpty(),"unreadable balance rejected")
$balance=0
$secondBalance=0
$reads=0
Check(ShopExitWhenEmpty() And $stops=1 And $reads=2,"known exhausted shop stops without navigation")
ShopCacheEndVisit()
$g_ShopDetectedArea=201
ShopCacheBeginVisit()
Check(Not ShopDailyCachedFull("0") And Not ShopCacheSkipPage("artifact.physical"),"new area cannot reuse old cap")
ShopCompletionReset()
$reads=0
Check(ShopExitWhenEmpty() And $exits=1 And $stops=1,"zero ore exits even with unknown remaining pages")
Local $lastReads=$reads
Check(ShopExitWhenEmpty() And $exits=2 And $reads=$lastReads,"exit retry does not read or visit pages")
ShopCacheEndVisit()
$balance=100
$reads=0
Check(Not ShopOreDepleted(),"new visit clears empty latch")
$g_ShopDetectedArea=0
ShopCacheBeginVisit()
ShopDailyRecord("1","0|0|100|20|0/24")
Check(ShopDailyCachedFull("1"),"unknown-area observation reused within visit")
ShopVisitMarkDone("artifact.en")
Check(ShopVisitSkipPage("artifact.en") And Not ShopCacheSkipPage("artifact.en"),"shortage skips this visit but never becomes permanent MAX")
ShopCacheEndVisit()
Check(Not ShopDailyCachedFull("1") And Not ShopVisitSkipPage("artifact.en"),"unknown-area memory expires after visit")
$g_ShopDetectedArea=200
ShopCacheInvalidate()
Check(Not ShopCacheSkipPage("artifact.physical") And Not ShopDailyCachedFull("0"),"manual refresh invalidates both caches")
ConsoleWrite("PASS cache reuse across 20 visits; permanent MAX per area; daily invalidation; unknown area; temporary shortage; stable zero exits and retry." & @CRLF)
Exit 0
Func Check($ok,$name)
    If $ok Then Return
    ConsoleWrite("FAIL " & $name & @CRLF)
    Exit 1
EndFunc
Func Cleanup()
    FileDelete($g_ShopCacheFile)
EndFunc
Func ShopDailyActive()
    Return $active
EndFunc
Func ShopOreRead()
    $reads+=1
    Return $reads=2 ? $secondBalance : $balance
EndFunc
Func ShopOreWait()
EndFunc
Func WriteLog($text)
EndFunc
Func _MazeShopAbort($threshold,$cd,$factor)
    $exits+=1
EndFunc
Func ShopStopIfExhausted()
    $stops+=1
    Return True
EndFunc
