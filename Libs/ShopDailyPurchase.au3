#include-once

; Return True after an action, interruption or uncertainty: keep the shop open.
; Return False only after all daily pages are exhausted or currently unaffordable.
Func ShopBuyDaily()
    If Not ShopDailyActive() Then Return True
    Local $allFull=True
    For $i=0 To 3
        If Not ShopDailyCachedFull(String($i)) And $g_ShopVisitDailyUnavailable[$i]<>ShopGameDay() Then $allFull=False
    Next
    If $allFull Then Return False
    If Not ShopDailyOpen() Then Return ShopDailyUncertain("daily category not recognized")
    For $i=0 To 3
        If Not ShopDailyActive() Then Return True
        If ShopOreDepleted() Then Return True
        If ShopDailyCachedFull(String($i)) Then ContinueLoop
        If $g_ShopVisitDailyUnavailable[$i]=ShopGameDay() Then ContinueLoop
        If Not ShopDailySelect($i) Then Return ShopDailyUncertain("daily tab not selected: " & $i)
        Local $before=ShopDailyReadCounter(), $pair=ShopCounterPair($before)
        If Not IsArray($pair) Then Return ShopDailyUncertain("daily counter unreadable: " & $i)
        ShopDailyRecord(String($i),$before)
        If Number($pair[0])=0 Then ContinueLoop
        If Not ShopEnsureMaxMultiplier() Then Return ShopDailyUncertain("cannot verify MAX purchase multiplier")
        Local $slot=0
        If $i<2 Then $slot=ShopReportSlot($g_ReportPriority)
        ; No preference means the first report, not disabled daily purchasing.
        If $slot<0 Then $slot=0
        If Not ShopDailyIdentity($i,$slot) Then Return ShopDailyUncertain("daily item not recognized: " & $i & "/" & $slot)
        If Not ShopDailyEnabled($slot) Then
            $g_ShopVisitDailyUnavailable[$i]=ShopGameDay()
            WriteLog("Shop daily: not affordable now; page=" & $i & "; remaining=" & $pair[0])
            ContinueLoop
        EndIf
        Local $day=ShopGameDay()
        If Not ShopDailyActive() Then Return True
        If Not ShopDailyClick($slot) Then Return True
        IniWrite($g_ShopCacheFile,"daily." & $i,"Valid","0")
        WriteLog("Shop daily: purchase requested; page=" & $i & "; slot=" & $slot)
        ; Read the result, never count a mouse click as an exchange.
        For $attempt=1 To 8
            ShopDailyWait()
            If Not ShopDailyActive() Then Return True
            If ShopGameDay()<>$day Then Return ShopDailyUncertain("daily reset during purchase")
            ShopDailyDismissReward()
            If Not ShopDailySelected($i) Then ContinueLoop
            Local $after=ShopDailyReadCounter()
            If ShopRecordDailyExchange(String($i),$slot,$before,$after,$day) Then
                ShopDailyRecord(String($i),$after)
                WriteLog("Shop daily: exchange confirmed; page=" & $i & "; slot=" & $slot)
                Return True
            EndIf
        Next
        Return ShopDailyUncertain("daily purchase result not confirmed: " & $i)
    Next
    Return False
EndFunc
