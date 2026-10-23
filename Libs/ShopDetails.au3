#include-once
Global $g_ReportPriority = "指定なし", $g_ShopDailyForceLive = False

Func ShopDailyInvalidate()
    For $i=0 To 3
        IniWrite($g_ShopCacheFile,"daily." & $i,"Valid","0")
    Next
EndFunc

Func ShopUTCNow()
    Local $s = DllStructCreate("ushort Year;ushort Month;ushort WeekDay;ushort Day;ushort Hour;ushort Minute;ushort Second;ushort Millisecond")
    DllCall("kernel32.dll", "none", "GetSystemTime", "struct*", $s)
    Return StringFormat("%04d/%02d/%02d %02d:%02d:%02d", $s.Year, $s.Month, $s.Day, $s.Hour, $s.Minute, $s.Second)
EndFunc

Func ShopGameDay($utc = "")
    If $utc = "" Then $utc = ShopUTCNow()
    ; JST = UTC+9, game day starts at 05:00 JST: date(UTC+4).
    Return StringLeft(_DateAdd("h", 4, $utc), 10)
EndFunc

Func ShopCounterPair($text)
    Local $lines = StringSplit(StringStripCR($text), @LF, 1), $result = 0
    For $i = 1 To $lines[0]
        Local $p = StringSplit($lines[$i], "|", 1)
        If $p[0] <> 5 Then ContinueLoop
        Local $m = StringRegExp(StringRegExpReplace($p[5], "\s", ""), "^(?:本日の購入回数[:：]?)?(\d{1,3})[/／](\d{1,3})$", 1)
        If Not IsArray($m) Then ContinueLoop
        If IsArray($result) Then Return False
        If Number($m[1]) < 1 Or Number($m[0]) > Number($m[1]) Then Return False
        $result = $m
    Next
    Return $result
EndFunc

Func ShopDailyRecord($key, $text)
    If $g_ShopDetectedArea <= 0 Then Return False
    Local $p = ShopCounterPair($text)
    If Not IsArray($p) Then Return False
    Local $section = "daily." & $key
    IniWrite($g_ShopCacheFile, $section, "Day", ShopGameDay())
    IniWrite($g_ShopCacheFile, $section, "Area", $g_ShopDetectedArea)
    IniWrite($g_ShopCacheFile, $section, "Remaining", $p[0])
    IniWrite($g_ShopCacheFile, $section, "Used", Number($p[1])-Number($p[0]))
    IniWrite($g_ShopCacheFile, $section, "CounterMode", "remaining-v2")
    IniWrite($g_ShopCacheFile, $section, "Cap", $p[1])
    IniWrite($g_ShopCacheFile, $section, "Valid", "1")
    IniWrite($g_ShopCacheFile, $section, "VerifiedUTC", ShopUTCNow())
    Return True
EndFunc

Func ShopDailyCachedFull($key)
    Local $section = "daily." & $key
    If $g_ShopDailyForceLive Or $g_ShopDetectedArea <= 0 Then Return False
    If IniRead($g_ShopCacheFile,$section,"Valid","0") <> "1" Then Return False
    If IniRead($g_ShopCacheFile,$section,"CounterMode","") <> "remaining-v2" Then Return False
    If IniRead($g_ShopCacheFile,$section,"Day","") <> ShopGameDay() Then Return False
    ; Recheck limits after changing area/progression; daily counts themselves are global.
    If Int(IniRead($g_ShopCacheFile,$section,"Area","0")) <> $g_ShopDetectedArea Then Return False
    Local $remaining=Int(IniRead($g_ShopCacheFile,$section,"Remaining","-1")), $cap=Int(IniRead($g_ShopCacheFile,$section,"Cap","0"))
    Return $cap > 0 And $remaining = 0
EndFunc

Func ShopRecordLevels($page, $text)
    If $g_ShopDetectedArea <= 0 Then Return
    Local $lines=StringSplit(StringStripCR($text),@LF,1)
    For $i=1 To $lines[0]
        Local $p=StringSplit($lines[$i],"|",1)
        If $p[0]<>5 Then ContinueLoop
        Local $m=StringRegExp(StringRegExpReplace($p[5],"\s",""),"(?i)^Lv[.:]?(\d{1,4})[/／](\d{1,4})$",1)
        If Not IsArray($m) Then ContinueLoop
        If Number($m[0])>Number($m[1]) Or Number($m[1])<1 Then ContinueLoop
        ; OCR region begins at 315,210, magnified 2x. Match known level-label cells.
        Local $x=Number($p[1])/2, $y=Number($p[2])/2
        Local $column=Round($x/495), $row=Round(($y-10)/126)
        If $column<0 Or $column>1 Or $row<0 Or $row>2 Then ContinueLoop
        If Abs($x-$column*495)>65 Or Abs($y-(10+$row*126))>30 Then ContinueLoop
        Local $slot=$row*2+$column, $id=$page & "." & $slot
        If $slot>=Int(IniRead($g_ShopCacheFile,"page." & $page,"Slots","0")) Then ContinueLoop
        IniWrite($g_ShopCacheFile,"level." & $id,"Value",$m[0])
        IniWrite($g_ShopCacheFile,"level." & $id,"Valid","1")
        IniWrite($g_ShopCacheFile,"level." & $id,"VerifiedUTC",ShopUTCNow())
        IniWrite($g_ShopCacheFile,"cap." & $g_ShopDetectedArea & "." & $id,"Value",$m[1])
        IniWrite($g_ShopCacheFile,"cap." & $g_ShopDetectedArea & "." & $id,"VerifiedUTC",ShopUTCNow())
    Next
EndFunc

Func ShopPageNeedsLevels($page)
    If $g_ShopDetectedArea<=0 Then Return False
    Local $n=Int(IniRead($g_ShopCacheFile,"page." & $page,"Slots","0"))
    For $i=0 To $n-1
        Local $id=$page & "." & $i
        If IniRead($g_ShopCacheFile,"level." & $id,"Valid","0")<>"1" Or Not ShopFreshUTC(IniRead($g_ShopCacheFile,"level." & $id,"VerifiedUTC","")) Or Not ShopFreshUTC(IniRead($g_ShopCacheFile,"cap." & $g_ShopDetectedArea & "." & $id,"VerifiedUTC","")) Then Return True
    Next
    Return False
EndFunc

Func ShopReportSlot($name)
    Local $names[6]=["アグレッシブ","スマート","シャイ","キュート","コミカル","クレバー"]
    For $i=0 To 5
        If $name=$names[$i] Then Return $i
    Next
    Return -1
EndFunc
Func ShopFreshUTC($stamp)
    If Not _DateIsValid($stamp) Then Return False
    Local $hours=_DateDiff("h",$stamp,ShopUTCNow())
    Return Not @error And $hours>=0 And $hours<24
EndFunc

Func ShopMappedPageMax($page)
    Local $n=Int(IniRead($g_ShopCacheFile,"page." & $page,"Slots","0"))
    If $n<1 Then Return False
    For $i=0 To $n-1
        Local $id=$page & "." & $i, $level="level." & $id, $cap="cap." & $g_ShopDetectedArea & "." & $id
        If IniRead($g_ShopCacheFile,$level,"Valid","0")<>"1" Then Return False
        If Not ShopFreshUTC(IniRead($g_ShopCacheFile,$level,"VerifiedUTC","")) Or Not ShopFreshUTC(IniRead($g_ShopCacheFile,$cap,"VerifiedUTC","")) Then Return False
        Local $limit=Int(IniRead($g_ShopCacheFile,$cap,"Value","0"))
        If $limit<1 Or Int(IniRead($g_ShopCacheFile,$level,"Value","-1"))<$limit Then Return False
    Next
    Return True
EndFunc

Func ShopRecordReportExchange($key, $attribute, $before, $after, $startedDay)
    If $startedDay <> ShopGameDay() Then Return False
    Local $a=ShopCounterPair($before), $b=ShopCounterPair($after)
    If Not IsArray($a) Or Not IsArray($b) Then Return False
    If Number($b[1])<>Number($a[1]) Or Number($b[0])>=Number($a[0]) Then Return False
    Local $section="exchange." & ShopGameDay() & ".report" & $key & "." & ShopReportSlot($attribute)
    Local $amount=Int(IniRead($g_ShopCacheFile,$section,"ConfirmedQuantity","0"))+Number($a[0])-Number($b[0])
    IniWrite($g_ShopCacheFile,$section,"Attribute",$attribute)
    IniWrite($g_ShopCacheFile,$section,"ConfirmedQuantity",$amount)
    IniWrite($g_ShopCacheFile,$section,"VerifiedUTC",ShopUTCNow())
    Return True
EndFunc

Func ShopRecordDailyExchange($key,$slot,$before,$after,$startedDay)
    If Number($key)<2 Then
        Local $names[6]=["アグレッシブ","スマート","シャイ","キュート","コミカル","クレバー"]
        Return ShopRecordReportExchange($key,$names[$slot],$before,$after,$startedDay)
    EndIf
    If $startedDay<>ShopGameDay() Then Return False
    Local $a=ShopCounterPair($before), $b=ShopCounterPair($after)
    If Not IsArray($a) Or Not IsArray($b) Then Return False
    If Number($b[1])<>Number($a[1]) Or Number($b[0])>=Number($a[0]) Then Return False
    Local $section="exchange." & ShopGameDay() & ".daily" & $key
    Local $amount=Int(IniRead($g_ShopCacheFile,$section,"ConfirmedQuantity","0"))+Number($a[0])-Number($b[0])
    IniWrite($g_ShopCacheFile,$section,"ConfirmedQuantity",$amount)
    IniWrite($g_ShopCacheFile,$section,"VerifiedUTC",ShopUTCNow())
    Return True
EndFunc
