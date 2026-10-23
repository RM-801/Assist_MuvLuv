#include-once

; Only a stable reading of the complete balance can end a visit early.
; Unknown OCR and nonzero amounts must never mean "nothing left to buy".
Func ShopOreDepleted()
    If $g_ShopOreEmpty Then Return True
    If Not ShopDailyActive() Then Return False
    If ShopOreRead()<>0 Then Return False
    ShopOreWait()
    If Not ShopDailyActive() Or ShopOreRead()<>0 Then Return False
    $g_ShopOreEmpty=True
    WriteLog("Shop ore exhausted: skip remaining pages and finish this visit.")
    Return True
EndFunc

Func ShopExitWhenEmpty()
    If Not ShopDailyActive() Or Not ShopOreDepleted() Then Return False
    ; No navigation to prove completion after running out of currency.
    If ShopCompletionUpgradeState()>0 And ShopDailyCachedFull("0") And ShopDailyCachedFull("1") And ShopDailyCachedFull("2") And ShopDailyCachedFull("3") Then
        If ShopStopIfExhausted() Then Return True
    EndIf
    _MazeShopAbort(0.80,False,2)
    Return True
EndFunc
