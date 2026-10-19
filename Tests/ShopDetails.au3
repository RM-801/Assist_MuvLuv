#include "..\Libs\ShopCompletion.au3"
#include "..\Libs\MazeShopCache.au3"
$g_ShopCacheFile=@ScriptDir & "\shop-details-test-" & @AutoItPID & ".ini"
OnAutoItExitRegister("CleanupTestCache")
If Not ShopCacheInitialize(@ScriptDir & "\..\Data\MazeShop.defaults.ini") Then Exit 23
If IniRead($g_ShopCacheFile,"page.artifact.physical","Slots","0")<>"5" Then Exit 24
IniWrite($g_ShopCacheFile,"Settings","TargetArea","140")
If Not ShopCacheInitialize(@ScriptDir & "\..\Data\MazeShop.defaults.ini") Then Exit 25
If IniRead($g_ShopCacheFile,"Settings","TargetArea","0")<>"140" Then Exit 26
If ShopGameDay("2026/10/18 19:59:59")<>"2026/10/18" Then Exit 1
If ShopGameDay("2026/10/18 20:00:00")<>"2026/10/19" Then Exit 2
If Not _DateIsValid(ShopUTCNow()) Then Exit 3
$g_ShopDetectedArea=130
Local $counter="OK" & @LF & "0|0|200|20|本日の購入回数:0/20"
If Not ShopDailyRecord("0",$counter) Or Not ShopDailyCachedFull("0") Then Exit 4
IniWrite($g_ShopCacheFile,"daily.0","Day","2026/01/01")
If ShopDailyCachedFull("0") Then Exit 5
ShopDailyRecord("0",$counter)
$g_ShopDetectedArea=140
If ShopDailyCachedFull("0") Then Exit 6
$g_ShopDetectedArea=130
$g_ShopDailyForceLive=True
If ShopDailyCachedFull("0") Then Exit 7
$g_ShopDailyForceLive=False
IniWrite($g_ShopCacheFile,"page.equipment.physical","Slots","2")
ShopRecordLevels("equipment.physical","OK" & @LF & "26|30|200|40|Lv 130/130" & @LF & "1016|30|200|40|Lv 120/130")
If IniRead($g_ShopCacheFile,"cap.130.equipment.physical.0","Value","")<>"130" Then Exit 8
If ShopMappedPageMax("equipment.physical") Then Exit 9
ShopRecordLevels("equipment.physical","OK" & @LF & "1016|30|200|40|Lv130/130")
If Not ShopMappedPageMax("equipment.physical") Then Exit 10
$g_ShopDetectedArea=140
If ShopMappedPageMax("equipment.physical") Then Exit 11
$g_ShopDetectedArea=130
ShopCacheMarkAttempt("equipment.physical",0)
If ShopMappedPageMax("equipment.physical") Then Exit 12
Local $names[6]=["アグレッシブ","スマート","シャイ","キュート","コミカル","クレバー"]
For $i=0 To 5
 If ShopReportSlot($names[$i])<>$i Then Exit 13
Next
If ShopReportSlot("unknown")<>-1 Then Exit 14
ShopDailyRecord("0",$counter)
ShopCacheBeginVisit()
If ShopDailyCachedFull("0") Then Exit 15
Local $before="OK" & @LF & "0|0|200|20|20/20",$after="OK" & @LF & "0|0|200|20|19/20"
If Not ShopRecordReportExchange("0","スマート",$before,$after,ShopGameDay()) Then Exit 16
If ShopRecordReportExchange("0","スマート",$before,$before,ShopGameDay()) Then Exit 17
If ShopRecordReportExchange("0","スマート",$before,$after,"2026/01/01") Then Exit 18
If ShopCompletionParseCounter("OK" & @LF & "0|0|100|20|0/2")<>1 Then Exit 19
If ShopCompletionParseCounter("OK" & @LF & "0|0|100|20|2/2")<>0 Then Exit 20
If ShopCompletionParseCounter("OK" & @LF & "0|0|100|20|1/2")<>0 Then Exit 21
If ShopCompletionParseCounter("OK" & @LF & "0|0|100|20|3/2")<>-1 Then Exit 22
ConsoleWrite("PASS JST05 boundary; per-day counters; new area invalidation; shared levels and per-area caps; purchase invalidation; all six priority slots." & @CRLF)
Exit 0
Func CleanupTestCache()
    FileDelete($g_ShopCacheFile)
EndFunc
