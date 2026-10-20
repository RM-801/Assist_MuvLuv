#include-once
Global $g_AutoHelper = False, $g_HelperStage = 0, $g_HelperStarted = 0
Global $g_HelperActions = 0, $g_HelperDescendingToggled = False, $g_HelperScrolled = False
; 0 idle, 1 opening helper formation, 2 sorting/selecting,
; 3 verifying selection, 4 returning to preparation, 5 ready to deploy.

Func QuestHelperReset()
    $g_HelperStage = 0
    $g_HelperStarted = 0
    $g_HelperActions = 0
    $g_HelperDescendingToggled = False
    $g_HelperScrolled = False
EndFunc

Func QuestHelperFail($reason)
    WriteLog("Helper stopped: " & $reason)
    ActionStop()
    QuestHelperNotifyFailure($reason)
    Return True
EndFunc

; Return a rectangle in the 1264x712 reference window, not desktop pixels.
Func QuestHelperFind($name,$area)
    Local $bounds = _WinAPI_GetPosWithoutShadow($sGameWinTitle)
    If Not IsArray($bounds) Then Return False
    Local $scale = $bounds[3]/712, $sizes[5] = [1,0.975,1.025,0.95,1.05]
    For $size In $sizes
        Local $r = ImageSearch($sGameResDir & "QuestHelper\" & $name & ".png",0.90,$area,712,$size)
        If Not IsArray($r) Then ContinueLoop
        Local $result[4] = [$area[0]+$r[0]/$scale,$area[1]+$r[1]/$scale,$r[2]/$scale,$r[3]/$scale]
        Return $result
    Next
    Return False
EndFunc

Func QuestHelperClick($rect)
    If Not IsArray($rect) Then Return False
    If Not MazeAreaPoint($rect[0]+$rect[2]/2,$rect[1]+$rect[3]/2) Then Return False
    $g_HelperActions += 1
    ActionPause(800)
    Return True
EndFunc

Func TryQuestHelper()
    If Not $g_AutoHelper Or Not $bRunning Then Return False
    Local $header[4]=[95,35,220,60], $party[4]=[65,420,590,215]
    Local $isPrep=IsArray(QuestHelperFind("Prep",$header))
    Local $isFormation=IsArray(QuestHelperFind("Formation",$header))
    Local $settingsArea[4]=[340,35,540,100]
    Local $settings=QuestHelperFind("Settings",$settingsArea)
    If $g_HelperStage = 5 Then
        If $isPrep Then Return False
        QuestHelperReset()
        Return False
    EndIf
    If $g_HelperStage = 0 Then
        If Not $isPrep Then Return False
        Local $slot = QuestHelperFind("Empty",$party)
        ; Existing helper ribbons also open the helper-only roster.
        If Not IsArray($slot) Then $slot=QuestHelperFind("Candidate",$party)
        If Not IsArray($slot) Then
            ; No helper-capable slot: leave the user's regular formation intact.
            $g_HelperStage=5
            WriteLog("Helper: no available helper slot on this preparation page.")
            Return False
        EndIf
        $g_HelperStarted=TimerInit()
        If QuestHelperClick($slot) Then $g_HelperStage=1
        Return True
    EndIf
    If TimerDiff($g_HelperStarted)>60000 Or $g_HelperActions>14 Then Return QuestHelperFail("Helper selection timed out. Check the formation and available helpers.")
    If IsArray($settings) Then
        Local $powerArea[4]=[700,170,440,210], $power=QuestHelperFind("PowerOption",$powerArea)
        If Not IsArray($power) Then
            ; Sort tab position relative to the observed display-settings title.
            Local $sort[4]=[$settings[0]-414,$settings[1]+168,109,26]
            QuestHelperClick($sort)
            Return True
        EndIf
        Local $radio[4]=[$power[0]-65,$power[1]-15,55,55]
        If Not IsArray(QuestHelperFind("PowerSelected",$radio)) Then
            QuestHelperClick($power)
            Return True
        EndIf
        Local $dialogOK[4]=[430,570,430,140]
        QuestHelperClick(QuestHelperFind("Confirm",$dialogOK))
        Return True
    EndIf
    If $isFormation Then
        If $g_HelperStage=1 Then $g_HelperStage=2
        Local $first[4]=[667,225,135,135], $firstCorner[4]=[665,225,48,48]
        Local $selected=IsArray(QuestHelperFind("Selected",$firstCorner))
        If $g_HelperStage=3 Then
            If Not $selected Then Return QuestHelperFail("The first helper was not selected. The assistant has not confirmed the formation.")
            If IsArray(QuestHelperFind("Empty",$party)) Then Return QuestHelperFail("The helper slot is still empty.")
            Local $partyCorner[4]=[65,420,590,215]
            If Not IsArray(QuestHelperFind("PartySelected",$partyCorner)) Then Return QuestHelperFail("Cannot verify the selected helper in the player formation.")
            Local $formationOK[4]=[1020,635,210,65]
            If QuestHelperClick(QuestHelperFind("Confirm",$formationOK)) Then $g_HelperStage=4
            Return True
        EndIf
        If $g_HelperStage=4 Then Return True
        Local $all1[4]=[650,130,50,45], $all2[4]=[650,173,50,45]
        ; Clear attribute/type restrictions before choosing the strongest helper.
        If Not IsArray(QuestHelperFind("All",$all1)) Then
            QuestHelperClick($all1)
            Return True
        EndIf
        If Not IsArray(QuestHelperFind("All",$all2)) Then
            QuestHelperClick($all2)
            Return True
        EndIf
        Local $sortArea[4]=[985,128,185,47], $direction[4]=[1173,130,45,43]
        If Not IsArray(QuestHelperFind("Power",$sortArea)) Then
            QuestHelperClick(QuestHelperFind("Filter",$sortArea))
            Return True
        EndIf
        If Not IsArray(QuestHelperFind("Descending",$direction)) Then
            If $g_HelperDescendingToggled Then Return QuestHelperFail("Cannot verify descending order. Set combat power and the blue downward arrow.")
            If QuestHelperClick($direction) Then $g_HelperDescendingToggled=True
            Return True
        EndIf
        If Not $g_HelperScrolled Then
            If MazeAreaPoint(1080,380,"up",20) Then
                $g_HelperScrolled=True
                ActionPause(600)
            EndIf
            Return True
        EndIf
        If $selected Then
            $g_HelperStage=3
            Return True
        EndIf
        If Not IsArray(QuestHelperFind("Candidate",$first)) Then Return QuestHelperFail("No helper was recognized at the top of the sorted list.")
        If QuestHelperClick($first) Then $g_HelperStage=3
        Return True
    EndIf
    If $isPrep Then
        If $g_HelperStage=4 Then
            If IsArray(QuestHelperFind("Empty",$party)) Then Return QuestHelperFail("The helper was not retained after confirming.")
            $g_HelperStage=5
            WriteLog("Helper: first helper in combat-power descending order verified and confirmed.")
            Return True
        EndIf
        ; Retry opening only after observing the original slot again.
        Local $slot=QuestHelperFind("Empty",$party)
        If Not IsArray($slot) Then $slot=QuestHelperFind("Candidate",$party)
        QuestHelperClick($slot)
    EndIf
    ; Own the flow during transitions: generic Deploy must not bypass selection.
    Return True
EndFunc
