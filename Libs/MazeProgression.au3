#include-once

; Session-only evidence. Restarting in a shop cannot claim an unobserved run.
Global $g_MazeAdvance = False, $g_MazeAdvanceLimit = 0
Global $g_MazeRunArea = 0, $g_MazeRunState = 0
; 0 idle, 1 verified preparation, 2 exploration, 3 final tune-up, 4 exit confirmed.

Func MazeProgressReset()
    $g_MazeRunArea = 0
    $g_MazeRunState = 0
EndFunc

Func MazeProgressPrepared($area)
    If Not $g_MazeAdvance Or $area < 1 Or $area > 999 Then Return
    $g_MazeRunArea = $area
    $g_MazeRunState = 1
EndFunc

Func MazeProgressExploring()
    If $g_MazeAdvance And $g_MazeRunState = 1 Then $g_MazeRunState = 2
EndFunc

Func MazeProgressShop()
    If Not $g_MazeAdvance Then Return True
    If $g_MazeRunState < 2 Or $g_MazeRunState > 4 Then Return False
    ; Repeated shop frames must not clear the pending exit.
    If $g_MazeRunState = 2 Then $g_MazeRunState = 3
    Return True
EndFunc

Func MazeProgressExited()
    If $g_MazeAdvance And $g_MazeRunState = 3 Then $g_MazeRunState = 4
EndFunc

; Called only on the Maze entry page. A candidate must still be selected and
; read back from START AREA before it may be persisted or entered.
; 0 = no candidate, -1 = unexpected return, -2 = configured limit reached.
Func MazeProgressCandidate()
    If Not $g_MazeAdvance Or $g_MazeRunState < 2 Then Return 0
    If $g_MazeRunState <> 4 Then Return -1
    If $g_MazeRunArea >= 999 Then Return -2
    If $g_MazeAdvanceLimit > 0 And $g_MazeRunArea >= $g_MazeAdvanceLimit Then Return -2
    Return $g_MazeRunArea + 1
EndFunc
