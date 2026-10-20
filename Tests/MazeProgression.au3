#include "..\Libs\MazeProgression.au3"

; Event sequences only; no game window, clicks or local player data.
$g_MazeAdvance = True
Check(Not MazeProgressShop(),"cannot adopt a shop at startup")
Check(MazeProgressCandidate()=0,"startup cannot advance")
MazeProgressPrepared(201)
Check(MazeProgressCandidate()=0,"preparation is not completion")
Check(Not MazeProgressShop(),"shop without exploration rejected")
MazeProgressExploring()
Check(MazeProgressCandidate()=-1,"unexpected return does not advance")
Check(MazeProgressShop(),"observed run may enter tune-up")
Check(MazeProgressCandidate()=-1,"shop alone does not advance")
MazeProgressExited()
Check(MazeProgressCandidate()=202,"completed exit proposes next area")
MazeProgressShop()
MazeProgressExited()
Check(MazeProgressCandidate()=202,"repeated frames do not increment twice")
; Selecting a locked/unknown candidate never calls Prepared or changes run area.
Check($g_MazeRunArea=201,"candidate is not committed progress")
MazeProgressPrepared(202)
Check(MazeProgressCandidate()=0,"verified next preparation consumes candidate")
MazeProgressExploring()
MazeProgressShop()
MazeProgressExited()
Check(MazeProgressCandidate()=203,"successive run advances once")
$g_MazeAdvanceLimit=202
Check(MazeProgressCandidate()=-2,"stop after finishing configured area")
MazeProgressReset()
Check(MazeProgressCandidate()=0,"Stop/defeat/reset discards pending evidence")
Check(Not MazeProgressShop(),"restart in shop cannot reuse stale evidence")
$g_MazeAdvanceLimit=0
MazeProgressPrepared(999)
MazeProgressExploring()
MazeProgressShop()
MazeProgressExited()
Check(MazeProgressCandidate()=-2,"recognizer range cannot overflow")
$g_MazeAdvance=False
Check(MazeProgressCandidate()=0,"fixed farming never advances")
Check(MazeProgressShop(),"fixed farming can start in shop")
MazeProgressReset()
MazeProgressPrepared(201)
Check($g_MazeRunArea=0,"fixed farming does not arm progression")
ConsoleWrite("PASS progression lifecycle, repeated frames, locked-candidate preservation, stop/defeat, limits, fixed farming." & @CRLF)
Exit 0

Func Check($ok,$label)
    If $ok Then Return
    ConsoleWrite("FAIL " & $label & @CRLF)
    Exit 1
EndFunc
