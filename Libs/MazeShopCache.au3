#include-once
#include <Date.au3>

Global $g_ShopCacheFile = @ScriptDir & "\Data\MazeShop.ini"
Global $g_ShopDetectedArea = 0
Global $g_ShopCacheVisitOpen = False
Global $g_ShopCacheFullReview = False
Global $g_ShopCachePage = ""
Global $g_ShopVisitMax = "|", $g_ShopVisitChecked = "|", $g_ShopOreEmpty = False
Global $g_ShopVisitDailyFull[4], $g_ShopVisitDailyUnavailable[4]
#include "ShopDetails.au3"

; Keep the distributable layout separate from local observations/preferences.
Func ShopCacheInitialize($defaults = "")
    If FileExists($g_ShopCacheFile) Then Return True
    If $defaults = "" Then $defaults = @ScriptDir & "\Data\MazeShop.defaults.ini"
    DirCreate(StringRegExpReplace($g_ShopCacheFile, "\\[^\\]+$", ""))
    Return FileCopy($defaults, $g_ShopCacheFile, 0) = 1
EndFunc

Func ShopCacheScopeMatches()
    Return $g_ShopDetectedArea > 0
EndFunc

; Original page/item sections contain layout definitions. Keep observations for
; each verified area separate; never assume the configured target was entered.
Func ShopCachePageSection($page)
    Return "area." & $g_ShopDetectedArea & ".page." & $page
EndFunc

Func ShopCacheItemSection($page, $slot)
    Return "area." & $g_ShopDetectedArea & ".item." & $page & "." & $slot
EndFunc

Func ShopCacheBeginVisit()
    If $g_ShopCacheVisitOpen Then Return
    $g_ShopCacheVisitOpen = True
    Local $highest = Int(IniRead($g_ShopCacheFile,"Settings","HighestVerifiedShopArea","0"))
    If $g_ShopDetectedArea > $highest Then
        ShopDailyInvalidate()
        IniWrite($g_ShopCacheFile,"Settings","HighestVerifiedShopArea",$g_ShopDetectedArea)
    EndIf
    Local $scope = "area." & $g_ShopDetectedArea & ".settings"
    Local $visits = Int(IniRead($g_ShopCacheFile, $scope, "Visits", "0")) + 1
    IniWrite($g_ShopCacheFile, $scope, "Visits", $visits)
    ; No periodic full scan. Area changes and F9 explicitly invalidate evidence.
EndFunc

Func ShopCacheEndVisit()
    $g_ShopCacheVisitOpen = False
    $g_ShopCachePage = ""
    $g_ShopCacheFullReview = False
    $g_ShopVisitMax = "|"
    $g_ShopVisitChecked = "|"
    $g_ShopOreEmpty = False
    For $i=0 To 3
        $g_ShopVisitDailyFull[$i]=""
        $g_ShopVisitDailyUnavailable[$i]=""
    Next
EndFunc

Func ShopVisitPageDone($page)
    Return StringInStr($g_ShopVisitChecked,"|" & $page & "|")>0
EndFunc

Func ShopVisitSkipPage($page)
    Return ShopVisitPageDone($page) Or ShopCacheSkipPage($page)
EndFunc

Func ShopVisitMarkDone($page)
    If Not ShopVisitPageDone($page) Then $g_ShopVisitChecked &= $page & "|"
EndFunc

Func ShopCacheSkipPage($page)
    If $g_ShopCacheFullReview Then Return False
    If IniRead($g_ShopCacheFile, "Settings", "Enabled", "0") <> "1" Then Return False
    If StringInStr($g_ShopVisitMax,"|" & $page & "|")>0 Then Return True
    If Not ShopCacheScopeMatches() Then Return False
    If ShopMappedPageMax($page) Then Return True
    If IniRead($g_ShopCacheFile, ShopCachePageSection($page), "AllMax", "0") <> "1" Then Return False
    Local $verified = IniRead($g_ShopCacheFile, ShopCachePageSection($page), "VerifiedAt", "")
    If Not _DateIsValid($verified) Then Return False
    ; MAX at a known area does not expire overnight. A different area has its own cap.
    Return True
EndFunc

Func ShopCacheMarkPageMax($page)
    If Not StringInStr($g_ShopVisitMax,"|" & $page & "|") Then $g_ShopVisitMax &= $page & "|"
    If Not ShopCacheScopeMatches() Then Return False
    IniWrite($g_ShopCacheFile, ShopCachePageSection($page), "AllMax", "1")
    IniWrite($g_ShopCacheFile, ShopCachePageSection($page), "VerifiedAt", _NowCalc())
EndFunc

Func ShopCacheMarkAttempt($page, $slot)
    $g_ShopVisitMax=StringReplace($g_ShopVisitMax,"|" & $page & "|","|")
    $g_ShopVisitChecked=StringReplace($g_ShopVisitChecked,"|" & $page & "|","|")
    If Not ShopCacheScopeMatches() Then Return False
    ; A click is not proof of an upgrade. Preserve the observed number as history.
    IniWrite($g_ShopCacheFile, ShopCachePageSection($page), "AllMax", "0")
    IniWrite($g_ShopCacheFile, ShopCacheItemSection($page, $slot), "NeedsRefresh", "1")
    IniWrite($g_ShopCacheFile, ShopCacheItemSection($page, $slot), "LastAttemptAt", _NowCalc())
    IniWrite($g_ShopCacheFile, "level." & $page & "." & $slot, "Valid", "0")
EndFunc

Func ShopCacheInvalidate()
    ShopCacheEndVisit()
    Local $sections = IniReadSectionNames($g_ShopCacheFile)
    If IsArray($sections) Then
        For $i = 1 To $sections[0]
            If StringLeft($sections[$i], 6) = "level." Or StringLeft($sections[$i], 6) = "daily." Then IniWrite($g_ShopCacheFile, $sections[$i], "Valid", "0")
            If StringLeft($sections[$i], 5) = "page." Or StringRegExp($sections[$i], "^area\.\d+\.page\.") Then IniWrite($g_ShopCacheFile, $sections[$i], "AllMax", "0")
        Next
    EndIf
    $g_ShopCacheFullReview = True
EndFunc
