#include-once
Global $g_DailyTabs[4]=["Stop_DailyReport1","Stop_DailyReport2","Stop_DailyDisk","Stop_DailyUnit"]

Func ShopDailyActive()
    Return $bRunning And WinActive($sGameWinTitle)
EndFunc

Func ShopDailyMatch($name,$area)
    Local $sizes[5]=[1,1.025,0.975,1.05,0.95]
    For $size In $sizes
        If IsArray(ImageSearch($sGameResDir & "MazeShop\" & $name & ".png",0.85,$area,712,$size)) Then Return True
    Next
    Return False
EndFunc

Func ShopDailySelected($page)
    If $page<0 Or $page>3 Then Return False
    ; Type-equipment and artifact tabs occupy the same top-row coordinates.
    ; A blue tab alone must never identify the Daily category.
    Local $category[4]=[20,220,115,55]
    If Not ShopTabPixelsSelected(ShopDailyCapture($category),$cv) Then Return False
    Local $tab[4]=[195+145*$page,130,130,35]
    ; Selected text templates contained a captured click effect. Use the fill.
    Return ShopTabPixelsSelected(ShopDailyCapture($tab),$cv)
EndFunc


Func ShopDailyOpen()
    ; The shop normally opens on the selected first Daily tab.
    For $i=0 To 3
        If ShopDailySelected($i) Then Return True
    Next
    Local $category[4]=[10,215,140,75]
    If Not ShopDailyMatch("Stop_DailyCategory",$category) Then Return False
    If Not MazeAreaPoint(80,250) Then Return False
    For $attempt=1 To 6
        Sleep(250)
        If Not ShopDailyActive() Then Return False
        For $i=0 To 3
            If ShopDailySelected($i) Then Return True
        Next
    Next
    Return False
EndFunc

Func ShopDailySelect($page)
    If ShopDailySelected($page) Then Return True
    ; Only use these fixed tab positions on a verified Daily page.
    Local $daily=False
    For $i=0 To 3
        If ShopDailySelected($i) Then $daily=True
    Next
    If Not $daily Then Return False
    If Not MazeAreaPoint(260+145*$page,147) Then Return False
    For $attempt=1 To 8
        Sleep(250)
        If Not ShopDailyActive() Then Return False
        If ShopDailySelected($page) Then
            Sleep(250)
            Return ShopDailySelected($page)
        EndIf
    Next
    Return False
EndFunc

Func ShopDailyReadCounter()
    Local $counter[4]=[190,581,230,33]
    Return MazeAreaOCR($counter,"ja*",4)
EndFunc

Func ShopDailyIdentity($page,$slot)
    Local $identity[4]=[315+495*Mod($slot,2),182+126*Int($slot/2),300,42]
    If $page<2 Then Return ShopDailyMatch("ReportIdentity" & $slot,$identity)
    Return ShopDailyMatch("DailyIdentity" & $page,$identity)
EndFunc

Func ShopDailyEnabled($slot)
    Local $bounds=_WinAPI_GetPosWithoutShadow($sGameWinTitle)
    If Not IsArray($bounds) Then Return False
    Local $scale=$bounds[3]/712, $x=490+495*Mod($slot,2), $y=221+126*Int($slot/2)
    Local $crop[4]=[$bounds[0]+Int($x*$scale),$bounds[1]+Int($y*$scale),Int(193*$scale),Int(70*$scale)]
    Local $mat=_OpenCV_GetDesktopScreenMat($crop)
    If Not IsObj($mat) Then Return False
    Local $hsv=$cv.cvtColor($mat,$CV_COLOR_BGR2HSV)
    Return $cv.countNonZero($cv.inRange($hsv,_OpenCV_Scalar(140,80,180),_OpenCV_Scalar(179,255,255)))>=1000*$scale*$scale
EndFunc

Func ShopDailyClick($slot)
    Return MazeAreaPoint(586+495*Mod($slot,2),256+126*Int($slot/2))
EndFunc

Func ShopDailyWait()
    Sleep(500)
EndFunc

Func ShopDailyDismissReward()
    Local $area[4]=[482,356,300,300]
    ClickImage($sGameResDir & "Maze_CraftDoneOK.png",0.85,0,0,False,2,$area)
EndFunc

Func ShopDailyUncertain($reason)
    If Not ShopDailyActive() Then Return True
    ShopPurchaseUncertain($reason)
    Return True
EndFunc

Func ShopMultiplierRead()
    ; Only read the top-right multiplier, never an item's LvMAX label.
    Local $value[4]=[1110,132,72,35]
    Local $states[3]=["MAX","X10","X1"],$sizes[5]=[1,1.025,0.975,1.05,0.95]
    For $state In $states
        For $size In $sizes
            If IsArray(ImageSearch($sGameResDir & "MazeShop\Multiplier" & $state & ".png",0.90,$value,712,$size)) Then Return $state
        Next
    Next
    Local $reading=MazeAreaOCR($value,"en*",4),$result=ShopMultiplierParse($reading)
    If $result="" Then WriteLog("Shop multiplier unreadable: " & StringReplace(StringStripCR($reading),@LF,"; "))
    Return $result
EndFunc

Func ShopMultiplierClick()
    ; A cursor/click effect can cover the tiny cycle icon. The multiplier itself
    ; identifies the control; do not require cursor-shaped template pixels.
    If Not ShopDailyActive() Then Return False
    Local $value=ShopMultiplierRead()
    If $value="" Or $value="MAX" Then Return False
    WriteLog("Shop multiplier: changing " & $value & " toward MAX")
    Return MazeAreaPoint(1199,150)
EndFunc

Func ShopMultiplierWait()
    Sleep(250)
EndFunc
