#Region
#AutoIt3Wrapper_UseX64=y
#EndRegion

#include "Libs\autoit-opencv-com\udf\opencv_udf_utils.au3"
#include <GDIPlus.au3>
#include <GUIConstantsEx.au3>
#include <ScreenCapture.au3>
#include <StaticConstants.au3>
#include "Libs\ImageScaleSafe.au3"
#include "Libs\MazeShopCache.au3"
#include "Libs\ShopDetails.au3"
#include "Libs\ShopDailyPurchase.au3"
#include "Libs\ShopMultiplier.au3"
#include "Libs\ShopCompletion.au3"
#include "Libs\ShopOre.au3"
#include "Libs\ShopTabState.au3"
#include "Libs\MazeProgression.au3"

If Not ShopCacheInitialize() Then
    MsgBox(16, "Shop settings", "Cannot initialize Data\MazeShop.ini. Check the default layout file and folder permissions.")
    Exit 1
EndIf


; Assume the game window size is 1264x712, not the client area size.
;   The size is it because my template images are captured on this size.
; This window size is adjusted by SmartSystemMenu. Resize to 1280x720.
;   ShareX can capture the game window in 1264x712.
; The function `ImageSearch` has a parameter relating to this size.

DllCall("user32.dll", "bool", "SetProcessDPIAware")
Opt("MouseClickDownDelay", 100)
Local $arrDPIs = DllCall("user32.dll", "uint", "GetDpiForSystem") ; Windows 10+
Local $iWinScale = $arrDPIs[0] / 96 ; DPI 96 is 100%

_OpenCV_Open("Libs\opencv\build\x64\vc16\bin\opencv_world4120.dll", "Libs\autoit-opencv-com\autoit_opencv_com4120.dll")
_GDIPlus_Startup()
OnAutoItExitRegister("_OnAutoItExit")

Global $sGameWinTitle   = "マブラヴ"
Global $sGameResDir     = @ScriptDir & "\Games\MuvLuv\"
Global $sScriptLog      = @ScriptDir & "\Game_MuvLuv.log"
Global $iLoopTimer      = 500
; A new-stage unlock animation can leave the visible Start button unresponsive.
Global $iQuestStartWaitMs = 4500
Global $hQuestStartVisible = 0
Global $hQuestPageLastSeen = 0
Global $g_RouteSelectAttempts = 0

Global $bMazeFarmingOn  = True
Global $bMazeCraftSkip  = True

Global $bWriteLogOn     = False
Global $bRunning        = False
Global $bPausing        = False
Global $iPausingTimer   = 0
Global $iPausingMax     = $iLoopTimer
Global $bSingleRunning  = False

Global $cv = _OpenCV_get()
If Not IsObj($cv) Then
    MsgBox(16, "Error", "Failed to get OpenCV COM object.")
    Exit
EndIf


#include "Libs\ShopDailyUI.au3"

; The theme
Global $bIsDark = False
Global $c_Dark_BG       = 0x1F1F1F, $c_Dark_Text      = 0xF0F0F0
Global $c_Light_BG      = 0xF3F3F3, $c_Light_Text     = 0x000000
Global $c_Status_BG     = 0x000000, $c_Status_Text    = 0xFFFFFF
Global $aThemeControls[20], $iCtrlCount = 0

Func _RegisterThemeCtrl($iCtrlID)
    $aThemeControls[$iCtrlCount] = $iCtrlID
    $iCtrlCount += 1
EndFunc

; The font and size.
Local $sFont = "Segoe UI"
Local $iFontSize = 10
Local $iGUIWidth = Int(255 * $iWinScale), $iGUIHeight = Int(450 * $iWinScale)

Local $hGUI = GUICreate("MuvLuv Auto", $iGUIWidth, $iGUIHeight)
GUISetFont($iFontSize, $FW_NORMAL, 0, $sFont)

; [ Normal, Hover, Clicked ] Colors
Global $aBtnColor_Dark[3]  = [0x333333, 0x444444, 0x222222]
Global $aBtnColor_Light[3] = [0xE1E1E1, 0xD0D0D0, 0xB8B8B8]
Global $bBtnHovered = False
Local $iBtnW = Int(100 * $iWinScale), $iBtnH = Int(40 * $iWinScale)
;Local $btnStart = GUICtrlCreateButton("Start", Int(($iGUIWidth - $iBtnW) / 2), Int(10 * $iWinScale), $iBtnW, $iBtnH)
Global $btnStart = GUICtrlCreateLabel("Start", Int(($iGUIWidth - $iBtnW) / 2), Int(10 * $iWinScale), $iBtnW, $iBtnH, BitOR($SS_CENTER, $SS_CENTERIMAGE))
GUICtrlSetFont($btnStart, 11, $FW_BOLD, 0, $sFont)

Local $iPadTop = 3
Local $iStatusW = Int(120 * $iWinScale), $iStatusH = Int(25 * $iWinScale) - $iPadTop
Local $iStatusX = Int(($iGUIWidth - $iStatusW) / 2)
Local $iStatusY = Int(10 * $iWinScale) + $iBtnH + Int(10 * $iWinScale) ; Combine button height and vertical spacing

Local $lblStatusPad = GUICtrlCreateLabel("", $iStatusX, $iStatusY, $iStatusW, $iPadTop)
GUICtrlSetBkColor($lblStatusPad, 0x000000)
; Initial string length needs attention.
Global $lblStatus = GUICtrlCreateLabel("  Status: Idle    ", $iStatusX, $iStatusY + $iPadTop, $iStatusW, $iStatusH)
GUICtrlSetBkColor($lblStatus, 0x000000)
GUICtrlSetColor($lblStatus, 0xFFFFFF)

Local $iTipsW = Int(235 * $iWinScale), $iTipsH = Int(20 * $iWinScale)
Local $iTipsX = Int(($iGUIWidth - $iTipsW) / 2)
Local $iTipsY = $iStatusY + $iStatusH + Int(10 * $iWinScale)
Local $iTipsGap = $iTipsH + Int(5 * $iWinScale)

Local $aTipsText[3] = [ _
    "Tip1: Press Esc/End to stop looping.", _
    "Tip2: Keep an eye on the game.", _
    "Tip3: 1280x720 by SmartSystemMenu." _
]
For $i = 0 To 2
    Local $hIdTip = GUICtrlCreateLabel($aTipsText[$i], $iTipsX, $iTipsY + ($i * $iTipsGap), $iTipsW, $iTipsH)
    _RegisterThemeCtrl($hIdTip)
Next

Local $iChkBoxW = Int(18 * $iWinScale)
Local $iChkBoxP = Int(1 * $iWinScale)

Local $iChkDebugW = Int(100 * $iWinScale), $iChkDebugH = Int(20 * $iWinScale)
Local $iChkDebugY = $iGUIHeight - Int(25 * $iWinScale)
Local $iChkDebugX = Int(($iGUIWidth - $iChkDebugW) / 2)
Local $chkDebug = GUICtrlCreateCheckbox("", $iChkDebugX, $iChkDebugY, $iChkBoxW, $iChkDebugH)
Local $chkDebugText = GUICtrlCreateLabel("Enable log", $iChkDebugX + $iChkBoxW, $iChkDebugY + $iChkBoxP, $iChkDebugW - $iChkBoxW, $iChkDebugH)
_RegisterThemeCtrl($chkDebugText)

Local $iChkMazeW = Int(150 * $iWinScale), $iChkMazeH = Int(20 * $iWinScale)
Local $iChkMazeY = $iChkDebugY - Int(25 * $iWinScale)
Local $iChkMazeX = Int(($iGUIWidth - $iChkMazeW) / 2)
Local $chkMazeFarming = GUICtrlCreateCheckbox("", $iChkMazeX, $iChkMazeY, $iChkBoxW, $iChkMazeH)
Local $chkMazeFarmingText = GUICtrlCreateLabel("Enable Maze Farming", $iChkMazeX + $iChkBoxW, $iChkMazeY + $iChkBoxP, $iChkMazeW - $iChkBoxW, $iChkMazeH)
GUICtrlSetState($chkMazeFarming, $GUI_CHECKED)
_RegisterThemeCtrl($chkMazeFarmingText)

Local $iChkCraftW = Int(150 * $iWinScale), $iChkCraftH = Int(20 * $iWinScale)
Local $iChkCraftY = $iChkMazeY - Int(25 * $iWinScale)
Local $iChkCraftX = Int(($iGUIWidth - $iChkCraftW) / 2)
Local $chkCraftSkip = GUICtrlCreateCheckbox("", $iChkCraftX, $iChkCraftY, $iChkBoxW, $iChkCraftH)
Local $chkCraftSkipText = GUICtrlCreateLabel("Skip Crafting in Maze", $iChkCraftX + $iChkBoxW, $iChkCraftY + $iChkBoxP, $iChkCraftW - $iChkBoxW, $iChkCraftH)
GUICtrlSetState($chkCraftSkip, $GUI_CHECKED)
_RegisterThemeCtrl($chkCraftSkipText)

Local $areaLabel = GUICtrlCreateLabel("Start / farm area", Int(20*$iWinScale), Int(168*$iWinScale), Int(125*$iWinScale), Int(24*$iWinScale))
_RegisterThemeCtrl($areaLabel)
Global $inpArea = GUICtrlCreateInput(IniRead($g_ShopCacheFile, "Settings", "TargetArea", "100"), Int(155*$iWinScale), Int(165*$iWinScale), Int(70*$iWinScale), Int(25*$iWinScale))
Local $reportLabel = GUICtrlCreateLabel("スキルレポート優先属性", Int(20*$iWinScale), Int(198*$iWinScale), Int(220*$iWinScale), Int(20*$iWinScale))
_RegisterThemeCtrl($reportLabel)
Global $cmbReportPriority = GUICtrlCreateCombo("", Int(20*$iWinScale), Int(220*$iWinScale), Int(215*$iWinScale), Int(25*$iWinScale), 3)
Local $savedReportPriority = IniRead($g_ShopCacheFile,"Settings","ReportPriority","指定なし")
; Preserve any selected attribute; normalize legacy/default labels for display.
If ShopReportSlot($savedReportPriority) < 0 Then $savedReportPriority = "指定なし"
GUICtrlSetData($cmbReportPriority, "指定なし|アグレッシブ|スマート|シャイ|キュート|コミカル|クレバー", $savedReportPriority)

Global $chkMazeAdvance = GUICtrlCreateCheckbox("Auto advance areas", Int(20*$iWinScale), Int(250*$iWinScale), Int(215*$iWinScale), Int(24*$iWinScale))
If IniRead($g_ShopCacheFile,"Settings","AutoAdvance","0") = "1" Then GUICtrlSetState($chkMazeAdvance,$GUI_CHECKED)
_RegisterThemeCtrl($chkMazeAdvance)
Local $advanceLimitLabel = GUICtrlCreateLabel("Stop at (0 = none)", Int(20*$iWinScale), Int(283*$iWinScale), Int(130*$iWinScale), Int(24*$iWinScale))
_RegisterThemeCtrl($advanceLimitLabel)
Global $inpAdvanceLimit = GUICtrlCreateInput(IniRead($g_ShopCacheFile,"Settings","AdvanceLimit","0"),Int(155*$iWinScale),Int(280*$iWinScale),Int(70*$iWinScale),Int(25*$iWinScale))
GUICtrlSetTip($chkMazeAdvance,"Clear successive areas. Start from the Maze entry page. Stops on defeat or an unavailable next area.")
GUICtrlSetTip($inpAdvanceLimit,"Finish this area, then stop. 0 keeps advancing while the next area is available.")
Global $chkAutoHelper = GUICtrlCreateCheckbox("Auto select helper",Int(20*$iWinScale),Int(310*$iWinScale),Int(215*$iWinScale),Int(24*$iWinScale))
If IniRead($g_ShopCacheFile,"Settings","AutoHelper","0")="1" Then GUICtrlSetState($chkAutoHelper,$GUI_CHECKED)
_RegisterThemeCtrl($chkAutoHelper)
GUICtrlSetTip($chkAutoHelper,"Quest preparation: select the first helper after sorting by combat power descending.")

#include "Libs\MazeArea.au3"
#include "Libs\QuestHelper.au3"
#include "Libs\StoryUI.au3"
; Listen to the theme change
GUIRegisterMsg(0x001A, "WM_SETTINGCHANGE")
_ApplySystemTheme($hGUI)

Func WM_SETTINGCHANGE($hWnd, $iMsg, $wParam, $lParam)
    _ApplySystemTheme($hGUI)
    Return $GUI_RUNDEFMSG
EndFunc

Func _ApplySystemTheme($hWnd)
    Local $iReg = RegRead("HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme")

    If @error Then Return

    Local $bCurrentIsDark = ($iReg == 0)
    $bIsDark = $bCurrentIsDark

    Local $cBkColor = $bIsDark ? $c_Dark_BG : $c_Light_BG
    Local $cTextColor = $bIsDark ? $c_Dark_Text : $c_Light_Text

    GUISetBkColor($cBkColor, $hWnd)

    ; Button theme
    Local $aCurrentBtnSrc = $bIsDark ? $aBtnColor_Dark : $aBtnColor_Light
    GUICtrlSetBkColor($btnStart, $aCurrentBtnSrc[0])
    GUICtrlSetColor($btnStart, $bIsDark ? 0xFFFFFF : 0x000000)

    ; Ctrl theme
    For $i = 0 To $iCtrlCount - 1
        Local $hIdCtrl = $aThemeControls[$i]
        GUICtrlSetColor($hIdCtrl, $cTextColor)
        GUICtrlSetBkColor($hIdCtrl, $cBkColor)
    Next

    Local $pDark = DllStructCreate("int")
    DllStructSetData($pDark, 1, $bIsDark ? 1 : 0)
    DllCall("dwmapi.dll", "long", "DwmSetWindowAttribute", "hwnd", $hWnd, "dword", 20, "ptr", DllStructGetPtr($pDark), "dword", 4)
EndFunc

$iBtnLeft   = -1
$iBtnTop    = -1
$iBtnRight  = -1
$iBtnBottom = -1

; GUI Start
GUISetState(@SW_SHOW)
HotKeySet("{ESC}", "ActionStop")
HotKeySet("{END}", "ActionStop")
HotKeySet("{F9}", "ResetShopRecords")
While True
    Local $aMousePos = GUIGetCursorInfo($hGUI)
    If Not @error Then
        Local $iMX = $aMousePos[0]
        Local $iMY = $aMousePos[1]
        Local $aColors = $bIsDark ? $aBtnColor_Dark : $aBtnColor_Light

        If $iBtnLeft = -1 Then
            Local $aBtnPos = ControlGetPos($hGUI, "", $btnStart)
            $iBtnLeft   = $aBtnPos[0]
            $iBtnTop    = $aBtnPos[1]
            $iBtnRight  = $aBtnPos[0] + $aBtnPos[2]
            $iBtnBottom = $aBtnPos[1] + $aBtnPos[3]
        EndIf

        If ($iMX >= $iBtnLeft And $iMX <= $iBtnRight) And ($iMY >= $iBtnTop And $iMY <= $iBtnBottom) Then
            If Not $bBtnHovered Then
                $bBtnHovered = True
                GUICtrlSetBkColor($btnStart, $aColors[1])
            EndIf
        Else
            If $bBtnHovered Then
                $bBtnHovered = False
                GUICtrlSetBkColor($btnStart, $aColors[0])
            EndIf
        EndIf
    EndIf

    Switch GUIGetMsg()
        ; When click close button
        Case $GUI_EVENT_CLOSE
            Exit
        Case $btnStart
            Local $aColors = $bIsDark ? $aBtnColor_Dark : $aBtnColor_Light
            GUICtrlSetBkColor($btnStart, $aColors[2])
            Sleep(80)
            GUICtrlSetBkColor($btnStart, $aColors[1])
            If $bRunning Then
                ActionStop()
            Else
                ActionStart()
            EndIf

        ; The check boxes
        Case $chkDebug
            $bWriteLogOn = (GUICtrlRead($chkDebug) = $GUI_CHECKED)

        Case $chkMazeFarming
            $bMazeFarmingOn = (GUICtrlRead($chkMazeFarming) = $GUI_CHECKED)

        Case $chkCraftSkip
            $bMazeCraftSkip = (GUICtrlRead($chkCraftSkip) = $GUI_CHECKED)
    EndSwitch
WEnd

; Functions
Func QuestHelperNotifyFailure($reason)
    GUICtrlSetData($lblStatus,"Helper: Check")
    MsgBox(48,"Auto select helper",$reason)
EndFunc

Func ResetPausingState()
    $bPausing = False
    $iPausingTimer = 0
    $iPausingMax = 0
EndFunc

Func ActionStart()
    $g_RouteSelectAttempts = 0
    ; Stop/Start resumes the same visit. Day/area changes and F9 invalidate caches.
    $g_ReportPriority = GUICtrlRead($cmbReportPriority)
    IniWrite($g_ShopCacheFile,"Settings","ReportPriority",$g_ReportPriority)
    Local $requested = StringStripWS(GUICtrlRead($inpArea), 3)
    If Not StringRegExp($requested, "^[1-9][0-9]{0,2}$") Then
        MsgBox(48, "Target area", "Enter a whole-number area ID from 1 to 999.")
        Return
    EndIf
    $g_TargetArea = Int($requested)
    $g_MazeAdvance = (GUICtrlRead($chkMazeAdvance) = $GUI_CHECKED)
    Local $limit = StringStripWS(GUICtrlRead($inpAdvanceLimit),3)
    If Not StringRegExp($limit,"^(0|[1-9][0-9]{0,2})$") Then
        MsgBox(48,"Stop area","Enter 0 for no limit, or an area ID from 1 to 999.")
        Return
    EndIf
    $g_MazeAdvanceLimit = Int($limit)
    If $g_MazeAdvance And $g_MazeAdvanceLimit > 0 And $g_MazeAdvanceLimit < $g_TargetArea Then
        MsgBox(48,"Stop area","The stop area must be at or above the start area.")
        Return
    EndIf
    MazeProgressReset()
    QuestHelperReset()
    $g_AutoHelper=(GUICtrlRead($chkAutoHelper)=$GUI_CHECKED)
    IniWrite($g_ShopCacheFile,"Settings","AutoHelper",Int($g_AutoHelper))
    $g_AreaSelectAttempts = 0
    IniWrite($g_ShopCacheFile,"Settings","AutoAdvance",Int($g_MazeAdvance))
    IniWrite($g_ShopCacheFile,"Settings","AdvanceLimit",$g_MazeAdvanceLimit)
    $g_AreaSteps = 0
    $g_AreaLastRows = ""
    $g_AreaStuck = 0
    IniWrite($g_ShopCacheFile, "Settings", "TargetArea", $g_TargetArea)
    $hQuestStartVisible = 0
    $hQuestPageLastSeen = 0
    WriteLog("Started: main-page v4; multi-scale button; yielding loop")
    GUICtrlSetData($btnStart, "Stop")
    GUICtrlSetData($lblStatus, "  Status: Running ")
    GUICtrlSetColor($lblStatus, 0x00FF00)
    $bRunning = True
    GUICtrlSetState($chkMazeAdvance,$GUI_DISABLE)
    GUICtrlSetState($chkAutoHelper,$GUI_DISABLE)
    GUICtrlSetState($inpAdvanceLimit,$GUI_DISABLE)
    GUICtrlSetState($inpArea,$GUI_DISABLE)
    AdlibRegister("AutoClickTick", $iLoopTimer)
EndFunc

Func ActionStop()
    $hQuestStartVisible = 0
    $hQuestPageLastSeen = 0
    GUICtrlSetData($btnStart, "Start")
    GUICtrlSetData($lblStatus, "  Status: Idle    ")
    GUICtrlSetColor($lblStatus, 0xFFFFFF)
    $bRunning = False
    MazeProgressReset()
    QuestHelperReset()
    GUICtrlSetState($chkAutoHelper,$GUI_ENABLE)
    GUICtrlSetState($chkMazeAdvance,$GUI_ENABLE)
    GUICtrlSetState($inpAdvanceLimit,$GUI_ENABLE)
    GUICtrlSetState($inpArea,$GUI_ENABLE)
    ResetPausingState()
    AdlibUnRegister("AutoClickTick")
EndFunc

Func ActionContinue()
    If Not $bRunning Then Return
    GUICtrlSetData($lblStatus, "  Status: Running ")
    GUICtrlSetColor($lblStatus, 0x00FF00)
    ResetPausingState()
EndFunc

Func ActionPause($iMilliSeconds)
    GUICtrlSetData($lblStatus, "  Status: Waiting ")
    GUICtrlSetColor($lblStatus, 0xFFD966)
    $iPausingTimer = 0
    $iPausingMax = $iMilliSeconds
    $bPausing = True
EndFunc

Func _WinAPI_GetPosWithoutShadow($hWnd)
    If Not IsHWnd($hWnd) Then $hWnd = WinGetHandle($hWnd)
    If Not $hWnd Then Return False

    Local $aPos[4]
    Local $bSuccess = False

    Local $tRect = DllStructCreate("long Left;long Top;long Right;long Bottom;")
    ; DWMWA_EXTENDED_FRAME_BOUNDS = 9
    Local $aRet = DllCall("dwmapi.dll", "long", "DwmGetWindowAttribute", _
            "hwnd", $hWnd, _
            "dword", 9, _
            "ptr", DllStructGetPtr($tRect), _
            "dword", DllStructGetSize($tRect))

    If Not @error And $aRet[0] = 0 Then
        $aPos[0] = DllStructGetData($tRect, "Left")
        $aPos[1] = DllStructGetData($tRect, "Top")
        $aPos[2] = DllStructGetData($tRect, "Right") - $aPos[0]  ; Width
        $aPos[3] = DllStructGetData($tRect, "Bottom") - $aPos[1] ; Height
        $bSuccess = True
    EndIf

    If Not $bSuccess Then
        Local $aNativePos = WinGetPos($hWnd)
        If IsArray($aNativePos) Then
            $aPos = $aNativePos
            $bSuccess = True
        EndIf
    EndIf

    If Not $bSuccess Then Return False

    Return $aPos
EndFunc

; Image Search Functions.
; #FUNCTION# ==========================================================================================================
; Name ..........: ImageSearch
; Description ...: Find image in the game window or subarea relative to the game window.
; Syntax ........: ImageSearch($sImageFile[, $fThreshold = 0.8[, $arrSubArea = Default[, $iBaseHeight = 712]]])
; Parameters ....: $sImageFile      - Image path.
;                  $fThreshold      - [optional] The threshold. Default is 0.8
;                  $arrSubArea      - [optional] The sub area [x, y, w, h] relative to the game window. Default is the
;                                                whole game window.
;                  $iBaseHeight     - [optional] The base game window height where you capture the template images. So
;                                                the  captured images should be capture in the same window size. If the
;                                                running game window size is different, the template image will be
;                                                resized proportionally to  match the window size. Though it's better
;                                                to keep your game window size consistent.
; Return values .: Array of area relative to the game window if find or subarea if provided. Otherwise just silent.
; Remarks .......:
;   Assuming using SmartSystemMenu to resize to 1280x720 that give the game window size 1264x712 reducing the border
;   shadow size I think.
; =====================================================================================================================
Func ImageSearch($sImageFile, $fThreshold = 0.8, $arrSubArea = Default, $iBaseHeight = 712, $templateScale = 1)
    Local $arrArea = _WinAPI_GetPosWithoutShadow($sGameWinTitle)
    If Not IsArray($arrArea) Then Return False
    If UBound($arrArea) < 4 Then Return False
    If $arrArea[2] < 200 Or $arrArea[3] < 200 Or $iBaseHeight <= 0 Then Return False
    Local $iActualHeight = $arrArea[3]
    Local $fProportion = $iActualHeight / $iBaseHeight
    Local $imgTempl = _OpenCV_imread_and_check($sImageFile)
    If Not IsObj($imgTempl) Then Return False
    If $imgTempl.empty() Then Return False

    ; Scale the search region BEFORE capturing its pixels.
    If IsArray($arrSubArea) Then
        $arrArea[0] += Int($arrSubArea[0] * $fProportion)
        $arrArea[1] += Int($arrSubArea[1] * $fProportion)
        $arrArea[2] = Int($arrSubArea[2] * $fProportion)
        $arrArea[3] = Int($arrSubArea[3] * $fProportion)
    EndIf
    If $arrArea[2] < 1 Or $arrArea[3] < 1 Then Return False
    Local $imgScreen = _OpenCV_GetDesktopScreenMat($arrArea)
    If Not IsObj($imgScreen) Then Return False
    If $imgScreen.empty() Then Return False

    If $iActualHeight <> $iBaseHeight Or $templateScale <> 1 Then
        Local $iAdjWidth = Int($imgTempl.width * $fProportion * $templateScale)
        Local $iAdjHeight = Int($imgTempl.height * $fProportion * $templateScale)
        Local $resized = _AssistResize($cv, $imgTempl, $iAdjWidth, $iAdjHeight)
        If Not IsObj($resized) Then
            WriteLog("Resize failed: " & $sImageFile & "; window height=" & $iActualHeight & "; " & $g_AssistResizeError)
            ActionStop()
            Return False
        EndIf
        $imgTempl = $resized
    EndIf
    If $imgTempl.width > $imgScreen.width Or $imgTempl.height > $imgScreen.height Then Return False

    Local $iN = 1

    Local $imgTemplOpt = $cv.cvtColor($imgTempl, $CV_COLOR_BGR2GRAY)
    Local $imgScreenOpt = $cv.cvtColor($imgScreen, $CV_COLOR_BGR2GRAY)
    Local $iTotalCosts = $imgScreen.width * $imgScreen.height * $imgTempl.width * $imgTempl.height
    If $iTotalCosts > 147456000000 Then
        $iN = 2
        $imgTemplOpt = _AssistResize($cv, $imgTemplOpt, Int($imgTempl.width / $iN), Int($imgTempl.height / $iN))
        $imgScreenOpt = _AssistResize($cv, $imgScreenOpt, Int($imgScreen.width / $iN), Int($imgScreen.height / $iN))
        If Not IsObj($imgTemplOpt) Or Not IsObj($imgScreenOpt) Then Return False
    EndIf
    Local $matchResults = _OpenCV_FindTemplate($imgScreenOpt, $imgTemplOpt, $fThreshold)  ; Covariant Matrix Normal
    If IsArray($matchResults) And UBound($matchResults) > 0 Then
        Local $arrRect = [$matchResults[0][0] * $iN, $matchResults[0][1] * $iN, $imgTempl.width, $imgTempl.height]
        Return SetError(0, 0, $arrRect)
    Else
        Return SetError(0, 0, False)
    EndIf
EndFunc

; $arrArea is the window area. $arrRect is the subarea relative to the window area.
; When no shifts, default to click the center of the image($subRect). The shifts are relative to the center.
Func ClickRelateWindow($arrArea, $arrRect, $iShiftX = 0, $iShiftY = 0, $bBgClick = False)
    Local $iCenterX = $arrRect[0] + Int($arrRect[2] / 2) + $iShiftX
    Local $iCenterY = $arrRect[1] + Int($arrRect[3] / 2) + $iShiftY
    If $bBgClick Then
        ; Only when this message is accepted, but mostly can't because it's cheat apparently.
        ControlClick($sGameWinTitle, "", "", "left", 1, $iCenterX, $iCenterY)
    Else
        MouseClick("left", $arrArea[0] + $iCenterX, $arrArea[1] + $iCenterY, 1, 0)
    EndIf
EndFunc

; CD: If the image would still be presented for a while after being clicked,
; then if in the next loop the same image is the
; "next" detected, skip it for 1 as the CD unit.
Func ClickImage($sImageFile, $fThreshold = 0.85, $iShiftX = 0, $iShiftY = 0, $bCDOn = False, $iCDMax = 2, $arrSubArea = Default, $iBaseHeight = 712, $templateScale = 1)
    Static $sCDImageFile = ""
    Static $iCD = 0

    Local $arrRect = ImageSearch($sImageFile, $fThreshold, $arrSubArea, $iBaseHeight, $templateScale)
    If Not IsArray($arrRect) Then
        Return SetError(1, 0, False)
    EndIf

    If $bCDOn And $sCDImageFile = $sImageFile Then
        $iCD += 1
        If $iCD < $iCDMax Then
            Return SetError(0, 0, True)
        Endif
        $iCD = 0
    Else
        $iCD = 0
        $sCDImageFile = $sImageFile
    EndIf

    Local $arrArea = _WinAPI_GetPosWithoutShadow($sGameWinTitle)
    Local $iActualHeight = $arrArea[3]
    If $arrSubArea <> Default Then
        $arrRect[0] += $arrSubArea[0]
        $arrRect[1] += $arrSubArea[1]
    EndIf

    If $iActualHeight <> $iBaseHeight And $arrSubArea <> Default Then
        Local $fProportion = $iActualHeight / $iBaseHeight
        $arrRect[0] += int($arrSubArea[0] * ($fProportion - 1))
        $arrRect[1] += int($arrSubArea[1] * ($fProportion - 1))
    EndIf

    ClickRelateWindow($arrArea, $arrRect, $iShiftX, $iShiftY)
    Return SetError(0, 0, True)
EndFunc

; Maze Shop Functions
Func ResetShopRecords()
    ActionStop()
    ShopCacheInvalidate()
    GUICtrlSetData($lblStatus, " Shop: Recheck  ")
    WriteLog("Shop cache invalidated by F9; full review on next Start.")
EndFunc

Func ShopRecordedCardArea($slot)
    Local $a[4] = [315 + 495 * Mod($slot, 2), 182 + 126 * Int($slot / 2), 380, 116]
    Return $a
EndFunc

Func ShopRecordedPageIsMax()
    Local $count = Int(IniRead($g_ShopCacheFile, "page." & $g_ShopCachePage, "Slots", "0"))
    If $count < 1 Or $count > 5 Then Return False
    Local $allMax = True
    For $i = 0 To $count - 1
        Local $area = ShopRecordedCardArea($i)
        Local $identity = $sGameResDir & "MazeShop\Cache_" & $g_ShopCachePage & "_" & $i & ".png"
        If Not IsArray(ImageSearch($identity, 0.85, $area)) Then
            If ShopCacheScopeMatches() Then IniWrite($g_ShopCacheFile, ShopCachePageSection($g_ShopCachePage), "AllMax", "0")
            WriteLog("Shop layout mismatch: " & $g_ShopCachePage & " slot " & $i)
            ActionStop()
            GUICtrlSetData($lblStatus, " Shop: Check UI ")
            Return False
        EndIf
        Local $maxed = IsArray(ImageSearch($sGameResDir & "MazeShop\Cache_LvMAX.png", 0.88, $area))
        If ShopCacheScopeMatches() Then IniWrite($g_ShopCacheFile, ShopCacheItemSection($g_ShopCachePage, $i), "MaxVisible", $maxed ? "1" : "0")
        If Not $maxed Then $allMax = False
    Next
    If $bRunning And ShopPageNeedsLevels($g_ShopCachePage) Then
        Local $levels[4] = [315, 210, 900, 360]
        ShopRecordLevels($g_ShopCachePage, MazeAreaOCR($levels, "en*", 2))
    EndIf
    If $allMax Then
        ShopCacheMarkPageMax($g_ShopCachePage)
    Else
        If ShopCacheScopeMatches() Then IniWrite($g_ShopCacheFile, ShopCachePageSection($g_ShopCachePage), "AllMax", "0")
    EndIf
    ShopCompletionRecord($g_ShopCachePage, $allMax)
    Return $allMax
EndFunc

Func ShopRecordedScanBuy($image, $threshold, $cd, $factor)
    Local $count = Int(IniRead($g_ShopCacheFile, "page." & $g_ShopCachePage, "Slots", "0"))
    For $i = 0 To $count - 1
        If Not $bRunning Then Return False
        Local $area = ShopRecordedCardArea($i)
        Local $identity = $sGameResDir & "MazeShop\Cache_" & $g_ShopCachePage & "_" & $i & ".png"
        If Not IsArray(ImageSearch($identity, 0.85, $area)) Then ContinueLoop
        If IsArray(ImageSearch($sGameResDir & "MazeShop\Cache_LvMAX.png", 0.88, $area)) Then ContinueLoop
        If ShopMaterialsShort($area) Then ContinueLoop
        If ClickImage($sGameResDir & "MazeShop\" & $image, $threshold, 0, 0, $cd, $factor, $area) Then
            ShopCacheMarkAttempt($g_ShopCachePage, $i)
            Return True
        EndIf
    Next
    Return False
EndFunc

Func ShopReadInteger($text)
    Local $lines=StringSplit(StringStripCR($text),@LF,1),$value=-1
    For $i=1 To $lines[0]
        Local $p=StringSplit($lines[$i],"|",1)
        If $p[0]<>5 Then ContinueLoop
        Local $s=StringRegExpReplace($p[5],"[\s,，]","")
        If Not StringRegExp($s,"^\d{1,9}$") Then ContinueLoop
        If $value>=0 Then Return -1
        $value=Number($s)
    Next
    Return $value
EndFunc

Func ShopOreRead()
    Local $currency[4]=[1115,65,110,45]
    Return ShopReadInteger(MazeAreaOCR($currency,"en*",3))
EndFunc

Func ShopOreWait()
    Sleep(250)
EndFunc

Func ShopPurchaseUncertain($reason)
    WriteLog("Shop kept open: " & $g_ShopCachePage & "; " & $reason)
    ActionStop()
    GUICtrlSetData($lblStatus,"Shop: Check buy")
    Return False
EndFunc


Func ShopMaterialsShort($area)
    Local $button[4]=[$area[0]+175,$area[1]+30,205,85]
    Local $sizes[5]=[1,0.975,1.025,0.95,1.05]
    For $size In $sizes
        If IsArray(ImageSearch($sGameResDir & "MazeShop\UpgradeMaterialsShort.png",0.88,$button,712,$size)) Then Return True
    Next
    Return False
EndFunc

Func ShopCanLeaveUpgradePage()
    If ShopOreDepleted() Then Return True
    Local $count=Int(IniRead($g_ShopCacheFile,"page." & $g_ShopCachePage,"Slots","0"))
    If $count<1 Then Return ShopPurchaseUncertain("no registered items")
    Local $balance=-1, $allMax=True
    For $i=0 To $count-1
        If Not $bRunning Or Not WinActive($sGameWinTitle) Then Return False
        Local $area=ShopRecordedCardArea($i)
        If Not IsArray(ImageSearch($sGameResDir & "MazeShop\Cache_" & $g_ShopCachePage & "_" & $i & ".png",0.85,$area)) Then Return ShopPurchaseUncertain("item identity changed at slot " & $i)
        If IsArray(ImageSearch($sGameResDir & "MazeShop\Cache_LvMAX.png",0.88,$area)) Then ContinueLoop
        $allMax=False
        ; Insufficient materials is temporary, never cache it as a maxed upgrade.
        If ShopMaterialsShort($area) Then ContinueLoop
        If $balance<0 Then
            Local $currency[4]=[1115,65,110,45]
            $balance=ShopReadInteger(MazeAreaOCR($currency,"en*",3))
        EndIf
        If $balance=0 Then
            ; Require a fresh second reading of the whole number, not a zero glyph.
            If ShopReadInteger(MazeAreaOCR($currency,"en*",3))=0 Then
                $g_ShopOreEmpty=True
                Return True
            EndIf
        EndIf
        Return ShopPurchaseUncertain("unfinished item without materials-shortage label; slot=" & $i & "; ore=" & $balance)
    Next
    WriteLog("Shop page checked: " & $g_ShopCachePage & "; every item is MAX or explicitly lacks materials.")
    If $allMax Then ShopCacheMarkPageMax($g_ShopCachePage)
    ShopCompletionRecord($g_ShopCachePage,$allMax)
    ShopVisitMarkDone($g_ShopCachePage)
    Return True
EndFunc

Func MazeShopBuying()
    Local $fDefaultThreshold = 0.80, $fHigherThreshold = 0.90
    Local $bDefaultCDOn = False, $iDefaultCDFactor = 2
    Local $iDelayAnimate = 1500, $iDelayReaction = 150

    Sleep($iDelayReaction)
    If Not $bRunning Then Return True
    If ShopOreDepleted() Then Return True
    If $g_ShopCachePage <> "" And ShopRecordedPageIsMax() Then Return False
    If Not $bRunning Then Return True
    If Not ShopEnsureMaxMultiplier() Then
        If ShopDailyActive() Then ShopPurchaseUncertain("cannot verify MAX upgrade multiplier")
        Return True
    EndIf

    While _ScanAndClickBuy("BuyUpgrade.png", $fDefaultThreshold, $bDefaultCDOn, $iDefaultCDFactor)
        Sleep($iDelayAnimate)
        If Not $bRunning Then Return True
        If ShopOreDepleted() Then Return True
    WEnd

    _MazeShopScroll("down")
    Sleep($iDelayReaction)

    While _ScanAndClickBuy("BuyUpgrade.png", $fDefaultThreshold, $bDefaultCDOn, $iDefaultCDFactor)
        Sleep($iDelayAnimate)
        If Not $bRunning Then Return True
        If ShopOreDepleted() Then Return True
    WEnd

    _MazeShopScroll("up")
    Sleep($iDelayReaction)

    Local $bBoughtB = False
    If _ScanAndClickBuy("BuyInvest.png", $fDefaultThreshold, $bDefaultCDOn, $iDefaultCDFactor) Then
        $bBoughtB = True
        Sleep($iDelayAnimate)
        If ShopOreDepleted() Then Return True
    EndIf

    _MazeShopScroll("down")
    Sleep($iDelayReaction)

    If _ScanAndClickBuy("BuyInvest.png", $fDefaultThreshold, $bDefaultCDOn, $iDefaultCDFactor) Then
        $bBoughtB = True
        Sleep($iDelayAnimate)
        If ShopOreDepleted() Then Return True
    EndIf

    _MazeShopScroll("up")
    Sleep($iDelayReaction)

    If Not $bRunning Then Return True

    If Not $bBoughtB And Not ShopCanLeaveUpgradePage() Then Return True
    Return $bBoughtB
EndFunc

Func _ScanAndClickBuy($sImageName, $fThreshold, $bCDOn, $iCDFactor)
    If $g_ShopCachePage <> "" Then Return ShopRecordedScanBuy($sImageName, $fThreshold, $bCDOn, $iCDFactor)
    Local $arrMegaShopViewport = [450, 145, 750, 450]
    Local $sFullImagePath = $sGameResDir & "MazeShop\" & $sImageName

    If ClickImage($sFullImagePath, $fThreshold, 0, 0, $bCDOn, $iCDFactor, $arrMegaShopViewport) Then
        Return True
    EndIf

    Return False
EndFunc

Func _MazeShopScroll($sDirection = "down")
    If Not $bRunning Then Return
    ; All registered pages fit on one screen; never scroll them out of alignment.
    If $g_ShopCachePage <> "" Then Return

    Local $arrArea = _WinAPI_GetPosWithoutShadow($sGameWinTitle)
    If @error Then Return

    Local $iTargetX = $arrArea[0] + Int($arrArea[2] * 0.577)
    Local $iTargetY = $arrArea[1] + Int($arrArea[3] * 0.477)

    MouseMove($iTargetX, $iTargetY, 0)

    If $sDirection = "down" Then
        MouseWheel("down", 5)
    Else
        MouseWheel("up", 5)
    EndIf
EndFunc

Func ShopIsVisible()
    Local $header[4]=[80,35,250,65],$sizes[5]=[1,1.025,0.975,1.05,0.95]
    For $size In $sizes
        If IsArray(ImageSearch($sGameResDir & "MazeShop\ShopTitle.png",0.85,$header,712,$size)) Then Return True
    Next
    Return False
EndFunc

Func ShopDailyCapture($area)
    Local $bounds=_WinAPI_GetPosWithoutShadow($sGameWinTitle)
    If Not IsArray($bounds) Then Return False
    Local $scale=$bounds[3]/712
    Local $crop[4]=[$bounds[0]+Int($area[0]*$scale),$bounds[1]+Int($area[1]*$scale),Int($area[2]*$scale),Int($area[3]*$scale)]
    Return _OpenCV_GetDesktopScreenMat($crop)
EndFunc

Func ShopTypeSelected($key,$region)
    If Not StringRegExp($key,"^(physical|en|agile)$") Then Return False
    Local $bounds = _WinAPI_GetPosWithoutShadow($sGameWinTitle)
    If Not IsArray($bounds) Then Return False
    Local $scale = $bounds[3]/712
    Local $crop[4] = [$bounds[0]+Int($region[0]*$scale),$bounds[1]+Int($region[1]*$scale),Int($region[2]*$scale),Int($region[3]*$scale)]
    Return ShopTabPixelsSelected(_OpenCV_GetDesktopScreenMat($crop), $cv)
EndFunc

Func ShopWaitForType($key, $region)
    Local $started = TimerInit(), $stable = 0
    While $bRunning And WinActive($sGameWinTitle) And TimerDiff($started)<3000
        If ShopTypeSelected($key,$region) Then
            $stable += 1
            If $stable>=2 Then Return True
        Else
            $stable = 0
        EndIf
        Sleep(200)
    WEnd
    Return False
EndFunc

Func ShopCategorySelected($index,$area)
    Local $sizes[5]=[1,1.025,0.975,1.05,0.95]
    For $size In $sizes
        If IsArray(ImageSearch($sGameResDir & "MazeShop\CategorySelected" & $index & ".png",0.85,$area,712,$size)) Then Return True
    Next
    Return False
EndFunc

Func ShopObserveVisibleDaily()
    For $i=0 To 3
        If ShopDailyCachedFull(String($i)) Then ContinueLoop
        If Not ShopDailySelected($i) Then ContinueLoop
        ShopDailyRecord(String($i),ShopDailyReadCounter())
        Return
    Next
EndFunc

Func MazeShopBuyingTypes($category = "artifact")
    Local $fDefaultThreshold = 0.85, $bCD = False, $iCDFactor = 2
    Local $aTypes[3][5] = [ _
        ["Type_Physical.png", 195, 135, 135, 35], _
        ["Type_EN.png",       340, 135, 135, 35], _
        ["Type_Agile.png",    485, 135, 135, 35]  _
    ]

    ; Categories open on Physical: inspect it first, then move left to right.
    Local $typeKeys[3] = ["physical", "en", "agile"]

    For $i = 0 To 2
        If Not $bRunning Or Not WinActive($sGameWinTitle) Then Return True
        Local $page = $category & "." & $typeKeys[$i]
        If ShopVisitSkipPage($page) Then ContinueLoop
        Local $arrSubArea = [$aTypes[$i][1], $aTypes[$i][2], $aTypes[$i][3], $aTypes[$i][4]]
        Local $sFullImagePath = $sGameResDir & "MazeShop\" & $aTypes[$i][0]
        If Not ShopTypeSelected($typeKeys[$i],$arrSubArea) Then
            If Not ClickImage($sFullImagePath, $fDefaultThreshold, 0, 0, $bCD, $iCDFactor, $arrSubArea) Then
                ShopPurchaseUncertain("upgrade tab not recognized: " & $page)
                Return True
            EndIf
            If Not ShopWaitForType($typeKeys[$i],$arrSubArea) Then
                ; The initial click can land while the preceding purchase animates.
                If Not $bRunning Then Return True
                If Not WinActive($sGameWinTitle) Then Return True
                ClickImage($sFullImagePath, $fDefaultThreshold, 0, 0, $bCD, $iCDFactor, $arrSubArea)
                If ShopWaitForType($typeKeys[$i],$arrSubArea) Then
                    $g_ShopCachePage = $page
                    If MazeShopBuying() Then Return True
                    ContinueLoop
                EndIf
                If Not $bRunning Or Not WinActive($sGameWinTitle) Then Return True
                ShopPurchaseUncertain("upgrade tab did not become selected: " & $page)
                Return True
            EndIf
        EndIf
        $g_ShopCachePage = $page
        If MazeShopBuying() Then Return True
    Next

    Return False
EndFunc


Func MazeShopFarming()
    ShopCacheBeginVisit()
    ShopCompletionReset()
    If ShopExitWhenEmpty() Then Return
    ShopObserveVisibleDaily()
    If ShopBuyDaily() Then
        ShopExitWhenEmpty()
        Return
    EndIf
    If ShopExitWhenEmpty() Then Return
    Local $fDefault = 0.85, $fLow = 0.80, $bCD = False, $iCDFactor = 2, $iDelayReaction = 250

    ; Each purchase page verifies MAX before spending ore.

    Local $aCates[3][5] = [ _
        ["Cate_TypeEquip.png", 10, 295, 135, 75], _
        ["Cate_Excavate.png",  10, 375, 135, 75], _
        ["Cate_Artifact.png",  10, 455, 135, 75]  _
    ]

    For $i = 0 To 2
        If Not $bRunning Then Return
        If $i = 0 And ShopVisitSkipPage("equipment.en") And ShopVisitSkipPage("equipment.agile") And ShopVisitSkipPage("equipment.physical") Then ContinueLoop
        If $i = 1 And ShopVisitSkipPage("excavate") Then ContinueLoop
        If $i = 2 And ShopVisitSkipPage("artifact.en") And ShopVisitSkipPage("artifact.agile") And ShopVisitSkipPage("artifact.physical") Then ContinueLoop
        Local $arrSubArea = [$aCates[$i][1], $aCates[$i][2], $aCates[$i][3], $aCates[$i][4]]
        Local $sFullImagePath = $sGameResDir & "MazeShop\" & $aCates[$i][0]
        If Not ShopCategorySelected($i,$arrSubArea) Then
            If Not ClickImage($sFullImagePath, $fDefault, 0, 0, $bCD, $iCDFactor, $arrSubArea) Then
                ShopPurchaseUncertain("upgrade category not recognized: " & $aCates[$i][0])
                Return
            EndIf
            Sleep(500)
        EndIf
        $g_ShopCachePage = ($i = 1) ? "excavate" : ""
        Local $bStatus = ($i = 1) ? MazeShopBuying() : MazeShopBuyingTypes(($i = 0) ? "equipment" : "artifact")
        If ShopExitWhenEmpty() Then Return
        If $bStatus Then Return
    Next

    If ShopStopIfExhausted() Then Return
    _MazeShopAbort($fLow, $bCD, $iCDFactor)
EndFunc

; Check daily limits only when every upgrade page is a MAX candidate.
; Return -1 on uncertainty, 0 when purchases remain, 1 when all four caps are reached.
Func ShopDailyExhausted()
    If ShopDailyCachedFull("0") And ShopDailyCachedFull("1") And ShopDailyCachedFull("2") And ShopDailyCachedFull("3") Then Return 1
    If Not ShopDailyActive() Or Not ShopDailyOpen() Then Return -1
    For $i=0 To 3
        If ShopDailyCachedFull(String($i)) Then ContinueLoop
        If Not ShopDailyActive() Or Not ShopDailySelect($i) Then Return -1
        Local $reading=ShopDailyReadCounter(), $first=ShopCompletionParseCounter($reading)
        ShopDailyRecord(String($i),$reading)
        If $first<>1 Then Return $first
        Sleep(250)
        If Not ShopDailyActive() Then Return -1
        Local $second=ShopDailyReadCounter()
        If ShopCompletionParseCounter($second)<>1 Then
            IniWrite($g_ShopCacheFile,"daily." & $i,"Valid","0")
            Return -1
        EndIf
        ShopDailyRecord(String($i),$second)
    Next
    Return 1
EndFunc

Func ShopStopIfExhausted()
    If Not $bRunning Then Return True
    ; Exhausted upgrades/daily exchanges end farming, not a progression run.
    If $g_MazeAdvance Then Return False
    Local $upgrades = ShopCompletionUpgradeState()
    If $upgrades = 0 Then Return False
    Local $daily = ShopDailyExhausted()
    If Not $bRunning Then Return True
    If $daily = 0 Then Return False
    If $daily = -1 Then
        WriteLog("Shop completion uncertain: daily counters could not be verified.")
        ActionStop()
        GUICtrlSetData($lblStatus, "Shop: Check limit")
        Return True
    EndIf
    WriteLog("Shop exhausted: all upgrade pages MAX and all daily purchase caps reached.")
    _MazeShopAbort(0.80, False, 2)
    ActionStop()
    GUICtrlSetData($lblStatus, "Shop: All done")
    Return True
EndFunc

Func _MazeShopAbort($fThreshold, $bCD, $iCDFactor)
    Local $areaAbortBtn = [1020, 635, 195, 45]
    If Not $bRunning Then Return False
    If Not ClickImage($sGameResDir & "MazeShop\AbortBtn.png", $fThreshold, 0, 0, $bCD, $iCDFactor, $areaAbortBtn) Then Return False
    Local $areaAbortOK = [660, 525, 160, 45]
    Local $timeout = TimerInit()
    While $bRunning And Not ClickImage($sGameResDir & "MazeShop\AbortOK.png", $fThreshold, 0, 0, $bCD, $iCDFactor, $areaAbortOK)
        If TimerDiff($timeout) > 10000 Then Return False
        Sleep(500)
    WEnd
    If $bRunning Then MazeProgressExited()
    Return $bRunning
EndFunc

Func MazeNetworkErrored()
    Local $fDefault = 0.85, $bCD = False, $iCDFactor = 2
    Local $iSleep = 2000
    Sleep($iSleep)

    Local $sHomeQuestPath = $sGameResDir & "Home_Quest.png"
    Local $areaHomeQuest = [705, 655, 105, 40]
    While $bRunning And Not ClickImage($sHomeQuestPath, $fDefault, 0, 0, $bCD, $iCDFactor, $areaHomeQuest)
        Sleep($iSleep)
    WEnd

    Sleep($iSleep)

    Local $sHomeMazePath = $sGameResDir & "HomeQuest_Maze.png"
    Local $areaHomeMaze = [985, 315, 180, 50]
    While $bRunning And Not ClickImage($sHomeMazePath, $fDefault, 0, 0, $bCD, $iCDFactor, $areaHomeMaze)
        Sleep($iSleep)
    WEnd

    Sleep($iSleep)

    Local $sHomeMazeEntryPath = $sGameResDir & "HomeQuest_MazeEntryA.png"
    Local $areaHomeMazeEntryA = [310, 510, 270, 90]
    ClickImage($sHomeMazeEntryPath, $fDefault, 0, 0, $bCD, $iCDFactor, $areaHomeMazeEntryA)
EndFunc

; Log Function
Func WriteLog($msg)
    Local $hFile = FileOpen($sScriptLog, $FO_APPEND + $FO_CREATEPATH)
    If $hFile = -1 Then Return SetError(1, 0, 0)

    FileWriteLine($hFile, StringFormat("%04d-%02d-%02d %02d:%02d:%02d - %s", @YEAR, @MON, @MDAY, @HOUR, @MIN, @SEC, $msg))
    FileClose($hFile)
EndFunc

; Wait for stage-unlock animations, then retry while the Start button remains.
Func TryMainQuestStart()
    If Not $bRunning Then Return True
    Local $areaQuest = [781, 493, 483, 219]
    Local $areaHeader = [70, 28, 250, 80]
    Local $questButton = $sGameResDir & "Quest_Enter.png"
    Local $isMainPage = IsArray(ImageSearch($sGameResDir & "MainQuest_Header.png", 0.85, $areaHeader))
    If Not $isMainPage Then $isMainPage = IsArray(ImageSearch($questButton, 0.85, $areaQuest))
    If Not $isMainPage Then $isMainPage = IsArray(ImageSearch($sGameResDir & "Quest_Scene.png", 0.85, $areaQuest))
    If Not $bRunning Then Return True
    If Not $isMainPage Then
        ; Brief animation flashes must not restart the full waiting interval.
        If $hQuestStartVisible <> 0 And $hQuestPageLastSeen <> 0 And TimerDiff($hQuestPageLastSeen) > 2000 Then
            $hQuestStartVisible = 0
            $hQuestPageLastSeen = 0
            GUICtrlSetData($lblStatus, "  Status: Running ")
            WriteLog("Main quest: page no longer visible.")
        EndIf
        Return False
    EndIf
    $hQuestPageLastSeen = TimerInit()

    If $hQuestStartVisible = 0 Then
        $hQuestStartVisible = TimerInit()
        GUICtrlSetData($lblStatus, " Quest: Waiting  ")
        WriteLog("Main quest: page found; waiting for unlock animation.")
        Return True
    EndIf
    Local $elapsed = TimerDiff($hQuestStartVisible)
    If $elapsed < $iQuestStartWaitMs Then Return True
    ; Story nodes share the main-page header. Do not block their action behind Start.
    $questButton = MainQuestActionTemplate($areaQuest)
    If Not $bRunning Then Return True
    If $questButton = "" Then
        GUICtrlSetData($lblStatus, "Quest: Find action")
        Return True
    EndIf
    WriteLog("Main quest: wait elapsed=" & Int($elapsed) & "; active=" & (WinActive($sGameWinTitle) <> 0))

    If ClickMainQuestStartTwice($questButton, $areaQuest, $areaHeader) Then
        ShopDailyInvalidate() ; Story progression may change daily exchange allowances.
        If Not $bRunning Then Return True
        WriteLog("Main quest: Start click sequence sent; retry if still visible.")
        $hQuestStartVisible = TimerInit()
        GUICtrlSetData($lblStatus, " Quest: Starting ")
    Else
        If Not $bRunning Then Return True
        WriteLog("Main quest: click not sent; will retry.")
        ; Retry matching later without resetting the animation wait.
        GUICtrlSetData($lblStatus, " Quest: Find Start")
    EndIf
    Return True
EndFunc

Func MainQuestActionTemplate($areaQuest)
    Local $actions[2] = ["Quest_Scene.png", "Quest_Enter.png"]
    Local $scales[3] = [1, 1.025, 1.05]
    For $action In $actions
        For $scale In $scales
            If Not $bRunning Then Return ""
            If IsArray(ImageSearch($sGameResDir & $action, 0.90, $areaQuest, 712, $scale)) Then Return $sGameResDir & $action
        Next
    Next
    Return ""
EndFunc

Func ClickMainQuestButton($questButton, $areaQuest)
    Local $scales[3] = [1, 1.025, 1.05]
    For $scale In $scales
        If Not $bRunning Or Not WinActive($sGameWinTitle) Then Return False
        If ClickImage($questButton, 0.90, 0, 0, False, 2, $areaQuest, 712, $scale) Then
            WriteLog("Main quest: action=" & $questButton & "; template scale=" & $scale)
            Return True
        EndIf
    Next
    Return False
EndFunc

Func ClickMainQuestStartTwice($questButton, $areaQuest, $areaHeader)
    If Not $bRunning Then Return False
    If Not WinActive($sGameWinTitle) Then
        WriteLog("Main quest: game lost focus before click.")
        Return False
    EndIf
    If Not ClickMainQuestButton($questButton, $areaQuest) Then
        WriteLog("Main quest: button not matched during click capture.")
        Return False
    EndIf
    Sleep(250)
    If Not $bRunning Or Not WinActive($sGameWinTitle) Then Return True
    ; Re-identify the main page and the button after the first click.
    If Not IsArray(ImageSearch($sGameResDir & "MainQuest_Header.png", 0.85, $areaHeader)) Then Return True
    Local $loading[4] = [585, 335, 95, 75]
    If IsArray(ImageSearch($sGameResDir & "Game_Loading.png", 0.85, $loading)) Then Return True
    If ClickMainQuestButton($questButton, $areaQuest) Then WriteLog("Main quest: button still visible; second click sent.")
    Return True
EndFunc

; A received-reward popup can overlay the story or quest page. Handle it first.
Func TryReceivedReward()
    If Not $bRunning Or Not WinActive($sGameWinTitle) Then Return False
    Local $messageArea[4] = [450, 145, 370, 70]
    If Not IsArray(ImageSearch($sGameResDir & "Reward_Received.png", 0.90, $messageArea)) Then Return False
    If Not $bRunning Or Not WinActive($sGameWinTitle) Then Return True
    Local $okArea[4] = [500, 600, 260, 90]
    If ClickImage($sGameResDir & "Reward_OK.png", 0.90, 0, 0, False, 2, $okArea) Then
        WriteLog("Reward: acknowledged already-received rewards.")
        ActionPause(700)
    EndIf
    Return True
EndFunc

; Prefer the confirmed ore-income relic before the legacy middle-card fallback.
; Count only the upcoming column's reward icons, never inventory or preview icons.
Func MazeRouteDiamonds($region)
    Local $bounds = _WinAPI_GetPosWithoutShadow($sGameWinTitle)
    If Not IsArray($bounds) Then Return -1
    Local $scale = $bounds[3]/712
    Local $crop[4] = [$bounds[0]+Int($region[0]*$scale), $bounds[1]+Int($region[1]*$scale), Int($region[2]*$scale), Int($region[3]*$scale)]
    Local $scene = _OpenCV_GetDesktopScreenMat($crop)
    Local $templ = _OpenCV_imread_and_check($sGameResDir & "Maze_RouteDiamond.png")
    If Not IsObj($scene) Or Not IsObj($templ) Then Return -1
    Local $sizes[5] = [1, 1.025, 1.05, 0.975, 0.95], $best = 0
    For $size In $sizes
        Local $sized = _AssistResize($cv, $templ, Int($templ.width*$scale*$size), Int($templ.height*$scale*$size))
        If Not IsObj($sized) Then Return -1
        Local $matches = _OpenCV_FindTemplate($scene, $sized, 0.88)
        If IsArray($matches) Then
            If UBound($matches) > $best Then $best = UBound($matches)
        EndIf
    Next
    Return $best
EndFunc

Func TryMazeOreRoute()
    If Not $bRunning Or Not WinActive($sGameWinTitle) Then Return False
    Local $heading[4] = [490, 0, 300, 110], $sizes[5] = [1, 1.025, 1.05, 0.975, 0.95], $found = False
    For $size In $sizes
        If IsArray(ImageSearch($sGameResDir & "Maze_RouteTitle.png", 0.85, $heading, 712, $size)) Then
            $found = True
            ExitLoop
        EndIf
    Next
    If Not $found Then
        $g_RouteSelectAttempts = 0
        Return False
    EndIf
    Local $upper[4] = [435, 165, 165, 100], $lower[4] = [435, 470, 165, 100]
    Local $top = MazeRouteDiamonds($upper), $bottom = MazeRouteDiamonds($lower)
    If $top < 0 Or $bottom < 0 Or $top > 3 Or $bottom > 3 Or $top = $bottom Then Return False
    Local $y = ($bottom > $top) ? 465 : 160
    ; Center SELECT can also appear under the pointer. Use it only after our
    ; branch click and pause; the arrow remains valid for an already-selected node.
    Local $selected[4] = [370, $y-105, 230, 65], $center[4] = [400, $y-30, 155, 90]
    For $size In $sizes
        Local $confirmed = IsArray(ImageSearch($sGameResDir & "Maze_RouteSelected.png", 0.80, $selected, 712, $size))
        If $g_RouteSelectAttempts > 0 Then
            If IsArray(ImageSearch($sGameResDir & "Maze_RouteCenterSelect.png", 0.85, $center, 712, $size)) Then $confirmed = True
        EndIf
        If $confirmed Then
            $g_RouteSelectAttempts = 0
            WriteLog("Maze route: selection verified; continuing to route confirmation.")
            Return False ; The normal route-confirm handler may now proceed.
        EndIf
    Next
    If $g_RouteSelectAttempts >= 3 Then
        WriteLog("Maze route: cannot verify selection after three clicks; stopped.")
        ActionStop()
        $g_RouteSelectAttempts = 0
        Return True
    EndIf
    If MazeAreaPoint(460, $y) Then
        $g_RouteSelectAttempts += 1
        WriteLog("Maze route: diamonds top=" & $top & "; bottom=" & $bottom & "; selected=" & (($bottom > $top) ? "bottom" : "top"))
        ActionPause(700)
    EndIf
    Return True
EndFunc

Func TryMazeOreEvent()
    If Not $bRunning Or Not WinActive($sGameWinTitle) Then Return False
    Local $heading[4] = [560, 60, 240, 110], $options[4] = [580, 400, 650, 240]
    Local $sizes[5] = [1, 1.025, 1.05, 0.975, 0.95], $found = False
    For $size In $sizes
        If IsArray(ImageSearch($sGameResDir & "Maze_EventAcid.png", 0.88, $heading, 712, $size)) Then
            $found = True
            ExitLoop
        EndIf
    Next
    If Not $found Then Return False
    For $size In $sizes
        If ClickImage($sGameResDir & "Maze_EventPickOre.png", 0.88, 0, 0, False, 2, $options, 712, $size) Then
            WriteLog("Maze event: selected pick up Tatsumiya ore in acid swamp.")
            ActionPause(1200)
            Return True
        EndIf
    Next
    ; Never let the generic event click choose escape while this event is visible.
    ActionPause(500)
    Return True
EndFunc

Func TryMazeOreRelic()
    If Not $bRunning Or Not WinActive($sGameWinTitle) Then Return False
    Local $titleArea[4] = [480, 0, 320, 110], $cards[4] = [120, 200, 1020, 180]
    Local $sizes[5] = [1, 0.975, 1.025, 0.95, 1.05], $foundTitle = False
    For $size In $sizes
        If IsArray(ImageSearch($sGameResDir & "Maze_RelicTitle.png", 0.85, $titleArea, 712, $size)) Then
            $foundTitle = True
            ExitLoop
        EndIf
    Next
    If Not $foundTitle Then Return False
    For $size In $sizes
        If ClickImage($sGameResDir & "Maze_OreCore.png", 0.88, 0, 0, False, 2, $cards, 712, $size) Then
            WriteLog("Maze relic: preferred Tatsumiya Core (battle ore income).")
            ActionPause(1200)
            Return True
        EndIf
    Next
    Return False
EndFunc

Func TryStoryTapContinue()
    If Not $bRunning Or Not WinActive($sGameWinTitle) Then Return False
    Local $prompt = StoryContinueRect()
    If IsArray($prompt) Then
        Local $bounds = _WinAPI_GetPosWithoutShadow($sGameWinTitle)
        If Not IsArray($bounds) Or Not $bRunning Or Not WinActive($sGameWinTitle) Then Return False
        ClickRelateWindow($bounds, $prompt)
        WriteLog("Story: tapped the continue prompt.")
        ActionPause(1200)
        Return True
    EndIf
    Return False
EndFunc

; Looped Function
Func AutoClickTick()
    AdlibUnRegister("AutoClickTick")
    AutoClick()
    If $bRunning Then AdlibRegister("AutoClickTick", $iLoopTimer)
EndFunc

Func AutoClick()
    If Not $bRunning Or $bSingleRunning Then Return

    If $bPausing Then
        $iPausingTimer += $iLoopTimer
        If $iPausingTimer >= $iPausingMax Then
            ActionContinue()
        EndIf
        Return
    EndIf

    If Not WinExists($sGameWinTitle) Then
        MsgBox(16, "Error", "Game window not found.")
        ActionStop()
        Return
    EndIf

    Local $aNativePos = WinGetPos($sGameWinTitle)
    If Not IsArray($aNativePos) Then
        Return
    EndIf
    If BitAND(WinGetState($sGameWinTitle), 16) Then
        Return
    EndIf
    if $aNativePos[2] <> 1280 Or $aNativePos[3] <> 720 Then
        GUICtrlSetData($lblStatus, "  Status: Resized ")
        WinMove($sGameWinTitle, "", Default, Default, 1280, 720)
        Return ; Let the window finish resizing before the next capture.
    EndIf

    Local $hTimer = $bWriteLogOn ? TimerInit() : 0
    WinActivate($sGameWinTitle)

    Local $fLow = 0.80, $fDefault = 0.85, $fHigh = 0.90
    Local $bCD = False, $iCDFactor = 2
    Local $iPopupDelay = 500

    Local $arrLoadingArea = [585, 335, 95, 75]
    If IsArray(ImageSearch($sGameResDir & "Game_Loading.png", $fDefault, $arrLoadingArea)) Then
        ActionPause(1500)
        Return
    EndIf

    ; Inspect defeat before generic battle/continue clicks can dismiss it.
    Local $failureArea[4] = [781,493,483,219]
    If $g_MazeAdvance And IsArray(ImageSearch($sGameResDir & "Com_TryAgain.png",$fDefault,$failureArea)) Then
        ActionStop()
        GUICtrlSetData($lblStatus,"Battle: Failed")
        Return
    EndIf

    Local $arrCircleHard = [828, 513, 155, 55]
    If TryReceivedReward() Then Return
    If TryStoryTapContinue() Then Return
    If TryStoryUI() Then Return
    If TryQuestHelper() Then Return
    ; Reserve this screen for the quest handler until its button disappears.
    If TryMainQuestStart() Then Return
    If MazeAreaHandle() Then Return
    If ShopIsVisible() Then
        If Not MazeProgressShop() Then
            MazeAreaFail("Auto advance needs an observed run. Return to the Maze entry page and press Start.")
            Return
        EndIf
        If $bMazeFarmingOn Or $g_MazeAdvance Then
            $bSingleRunning = True
            MazeShopFarming()
            $bSingleRunning = False
        EndIf
        Return
    EndIf
    ClickImage($sGameResDir & "Circle_Hard.png", $fDefault, 0, 0, $bCD, $iCDFactor, $arrCircleHard)

    Local $arrRB = [781, 493, 483, 219]
    If TryMazeOreRoute() Then Return
    If ClickImage($sGameResDir & "Maze_Ready.png", $fDefault, 0, 0, $bCD, $iCDFactor, $arrRB) Or _
       ClickImage($sGameResDir & "Maze_Route.png", $fLow - 0.05, 0, 0, $bCD, $iCDFactor, $arrRB) Then
        MazeProgressExploring()
        ShopCacheEndVisit()
        ActionPause(2500)
        Return
    EndIf

    Local $aSingleClicks[6] = [ "Maze_NoHelper.png", "Maze_DeHelper.png", "Sim_Enter.png", "Com_Battle.png", "Com_Continue.png", "Quest_Scene.png"]
    For $img In $aSingleClicks
        ClickImage($sGameResDir & $img, $fDefault, 0, 0, $bCD, $iCDFactor, $arrRB)
    Next

    Local $arrRU = [740, 36, 524, 93]
    If ClickImage($sGameResDir & "Game_Menu.png", $fDefault, -560, 370, $bCD, $iCDFactor, $arrRU) Then
        If $bMazeFarmingOn Then
            $bSingleRunning = True
            MazeNetworkErrored()
            $bSingleRunning = False
        EndIf
        Return
    EndIf
    ClickImage($sGameResDir & "Com_SkipBattle.png", $fLow, 0, 0, $bCD, $iCDFactor, $arrRU)
    ClickImage($sGameResDir & "Com_SkipLight.png", $fLow, 0, 0, $bCD, $iCDFactor, $arrRU)
    ; A small zero glyph also matches amounts ending in 0. Never use it to exit.

    Local $arrGachaTitleArea = [84, 52, 120, 43]
    ClickImage($sGameResDir & "Gacha_Title.png", $fDefault, -90, 0, $bCD, $iCDFactor, $arrGachaTitleArea)

    Local $arrDw = [310, 385, 645, 205]
    ClickImage($sGameResDir & "Game_ErrorClose.png", $fLow, 0, 0, $bCD, $iCDFactor, $arrDw)
    ClickImage($sGameResDir & "Game_ErrorTitle.png", $fLow, 0, 0, $bCD, $iCDFactor, $arrDw)

    Local $arrFlashSaleArea = [523, 187, 217, 49]
    ClickImage($sGameResDir & "Com_FlashSale.png", $fDefault, 555, -135, $bCD, $iCDFactor, $arrFlashSaleArea)

    Local $arrC2 = [499, 162, 272, 49]
    If ClickImage($sGameResDir & "Com_FlashRelay.png", $fDefault, 230, 110, False, $iCDFactor, $arrC2) Then
        ClickImage($sGameResDir & "Com_FlashRelay.png", $fDefault, 555, -110, False, $iCDFactor, $arrC2)
    EndIf

    Local $arrM1 = [543, 131, 185, 68]
    If TryMazeOreRelic() Then Return
    ClickImage($sGameResDir & "Maze_SelRelic.png", $fDefault, 0, 150, $bCD, $iCDFactor, $arrM1)
    ClickImage($sGameResDir & "Maze_SelRelic200.png", $fDefault, 0, 150, $bCD, $iCDFactor, $arrM1)

    Local $arrM2 = [385, 238, 203, 45]
    ClickImage($sGameResDir & "Maze_SelTypeA.png", $fLow, 270, 145, $bCD, $iCDFactor, $arrM2)
    ClickImage($sGameResDir & "Maze_SelTypeB.png", $fLow, 270, 145, $bCD, $iCDFactor, $arrM2)
    ClickImage($sGameResDir & "Maze_SelTypeC.png", $fLow, 270, 145, $bCD, $iCDFactor, $arrM2)

    Local $arrM3 = [1007, 254, 206, 44]
    ClickImage($sGameResDir & "Maze_SelHelperA.png", $fHigh, 0, 0, $bCD, $iCDFactor, $arrM3)
    ClickImage($sGameResDir & "Maze_SelHelperB.png", $fHigh, 0, 0, $bCD, $iCDFactor, $arrM3)

    Local $arrTransArea = [67, 386, 229, 78]
    Local $arrEvOptsArea = [1128, 307, 100, 370]
    Local $arrNotCraftArea = [864, 626, 149, 39]
    Local $arrNotCraftOKArea = [643, 524, 190, 50]
    ClickImage($sGameResDir & "Maze_Trans.png", $fDefault, 960, 240, $bCD, $iCDFactor, $arrTransArea)
    If TryMazeOreEvent() Then Return
    ClickImage($sGameResDir & "Maze_EvOpts.png", $fDefault, -50, -25, $bCD, $iCDFactor, $arrEvOptsArea)

    If $bMazeCraftSkip Then
        If ClickImage($sGameResDir & "Maze_CraftDone.png", $fDefault, 0, 0, $bCD, $iCDFactor, $arrNotCraftArea) Then
            Sleep($iPopupDelay)
            ClickImage($sGameResDir & "Maze_CraftDoneOK.png", $fDefault, 0, 0, $bCD, $iCDFactor, $arrNotCraftOKArea)
        EndIf
    EndIf

    ; Reuse ok button
    Local $arrC1 = [482, 356, 300, 300]
    ClickImage($sGameResDir & "Maze_CraftDoneOK.png", $fDefault, 0, 0, $bCD, $iCDFactor, $arrC1)

    If IsArray(ImageSearch($sGameResDir & "Com_SkipLocked.png", $fDefault, $arrRU)) Then
        ActionPause(4500)
        Return
    EndIf

    If IsArray(ImageSearch($sGameResDir & "Com_TryAgain.png", $fDefault, $arrRB)) Then
        ActionStop()
        GUICtrlSetData($lblStatus, "  Battle: Failed  ")
        Return
    EndIf
    If IsArray(ImageSearch($sGameResDir & "Com_Limited.png", $fHigh + 0.05, $arrRB)) Then
        ActionStop()
        GUICtrlSetData($lblStatus, " Activity: Limited")
        Return
    EndIf
    If IsArray(ImageSearch($sGameResDir & "Quest_Clear.png", $fDefault, $arrRB)) Then
        ActionStop()
        GUICtrlSetData($lblStatus, "  Quest: Clear    ")
        Return
    EndIf

    Local $arrShopDoneCancelArea = [433, 526, 192, 47]
    If $bMazeFarmingOn Then
        ClickImage($sGameResDir & "MazeShop\AbortCancel.png", $fDefault, 0, 0, $bCD, $iCDFactor, $arrShopDoneCancelArea)
    EndIf
    If $bWriteLogOn Then
        WriteLog("AutoClick: " & TimerDiff($hTimer) & " ms")
    EndIf
EndFunc

; Internal Handling
Func _OnAutoItExit()
    _GDIPlus_Shutdown()
    _OpenCV_Close()
EndFunc
