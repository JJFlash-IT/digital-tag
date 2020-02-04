include "..\extensions\xcb-ext-joystick\xcb-ext-joystick.bas"

const RASTER_LINE = $d012

const WALL! = 35 ' "#"
const PLAYER_CHAR! = 42 ' "*"
const COMPUTER_CHAR! = 0 ' "@"
const EMPTY_CHAR! = 32 ' " "

dim screenColorArray![1000] @$d800

fun screen_peek!(screen_x!, screen_y!)
        dim screenarray![1000] @$0400
        return screenarray![(cast(screen_y!) * 40) + screen_x!]
endfun

tPlayer_x! = 1 : tPlayer_y! = 1
tComputer_x! = 38 : tComputer_y! = 23

dim tFuturePoint_x! : dim tFuturePoint_y!
bMoveNow! = 0

dim tVecComputerPlayer_Xdiff : dim tVecComputerPlayer_Ydiff : dim tVecComputerPlayer_XdiffABS : dim tVecComputerPlayer_YdiffABS
dim tVecWallToSimulator_Xdiff : dim tVecWallToSimulator_Ydiff
dim tVectorDir_X : dim tVectorDir_Y
dim tWallVectorDir_X : dim tWallVectorDir_Y
tWallPosition_Y! = 0
tWallPosition_X! = 0
dim nBresenhamDiff : dim nCrossProduct : dim nThresholdCrProd
bLineMoreVertical! = 0

const MAXDIR! = 3
dim nDirectionScalar!
'255 equivalent to -1!
data aDirections_Y![] = 255, 0, 1, 0 ' north, east, south, west
data aDirections_X![] = 0, 1, 0, 255 ' north, east, south, west

Const CURRENTPOS_Y! = 0 : Const CURRENTPOS_X! = 1 : Const SIMWALKDIR! = 2 : Const SIMSTARTDIR! = 3 : Const SIMBLOCKDIR! = 4 : Const SIMTURNBLOCK! = 5
dim aSimulators![2, 6]
aSimulators![0, SIMTURNBLOCK!] = 1 ' Clockwise
aSimulators![1, SIMTURNBLOCK!] = 255 'Anticlockwise - Simulates -1 !
dim nSimulatorNumber!

bWllFllwMode! = 0
bPledgeMode! = 0

dim nFastIndex! fast

poke 53280, 0: poke 53281, 0
data mazebin![] = incbin "maze.bin"
memset $d800, 1000, 8
memcpy @mazebin!, $0400, 1000

mainLoop:
    screenColorArray![(cast(tPlayer_y!) * 40) + tPlayer_x!] = 1
    charat tPlayer_x!, tPlayer_y!, PLAYER_CHAR!
    screenColorArray![(cast(tComputer_y!) * 40) + tComputer_x!] = 13
    charat tComputer_x!, tComputer_y!, COMPUTER_CHAR!
    watch RASTER_LINE, 250
    watch RASTER_LINE, 250
    watch RASTER_LINE, 250
    watch RASTER_LINE, 250
    watch RASTER_LINE, 250
    watch RASTER_LINE, 250
    watch RASTER_LINE, 250
    watch RASTER_LINE, 250
    watch RASTER_LINE, 250
    watch RASTER_LINE, 250
    watch RASTER_LINE, 250
    watch RASTER_LINE, 250
    watch RASTER_LINE, 250
    watch RASTER_LINE, 250
    watch RASTER_LINE, 250
    watch RASTER_LINE, 250
    poke 198, 0 : wait 198,1
    charat tPlayer_x!, tPlayer_y!, EMPTY_CHAR!
    charat tComputer_x!, tComputer_y!, EMPTY_CHAR!

    '--------------------------------------------Player movement---------------------------------------------------------
    tFuturePoint_x! = tPlayer_x! : tFuturePoint_y! = tPlayer_y!
    if joy_2_left!()  = 1 then dec tFuturePoint_x!
    if joy_2_right!() = 1 then inc tFuturePoint_x!
    if joy_2_up!()    = 1 then dec tFuturePoint_y!
    if joy_2_down!()  = 1 then inc tFuturePoint_y!

    if screen_peek!(tPlayer_x!, tFuturePoint_y!) <> WALL! Then tPlayer_y! = tFuturePoint_y!
    if screen_peek!(tFuturePoint_x!, tPlayer_y!) <> WALL! Then tPlayer_x! = tFuturePoint_x!

    '--------------------------------------------Computer movement------------------------------------------------------
    on bMoveNow! goto skipMovement, doMovement
        doMovement:
            on bWllFllwMode! goto WallFollowFalse, WallFollowTrue
                WallFollowFalse:
                    tVecComputerPlayer_Xdiff = cast(tPlayer_x!) - tComputer_x!
                    tVecComputerPlayer_XdiffABS = abs(tVecComputerPlayer_Xdiff)
                    tVecComputerPlayer_Ydiff = cast(tPlayer_y!) - tComputer_y!
                    tVecComputerPlayer_YdiffABS = abs(tVecComputerPlayer_Ydiff)
                    if tVecComputerPlayer_YdiffABS >= tVecComputerPlayer_XdiffABS Then bLineMoreVertical! = 1 Else bLineMoreVertical! = 0
                    tVectorDir_X = sgn(tVecComputerPlayer_Xdiff)
                    tVectorDir_Y = sgn(tVecComputerPlayer_Ydiff)
                    on bLineMoreVertical! goto BresenhamVertical, BresenhamHorizontal
                        BresenhamVertical:
                            nBresenhamDiff = 2 * tVecComputerPlayer_XdiffABS - tVecComputerPlayer_YdiffABS
                            goto BresenhamEnd
                        BresenhamHorizontal:
                            nBresenhamDiff = 2 * tVecComputerPlayer_YdiffABS - tVecComputerPlayer_XdiffABS
                    BresenhamEnd:
                    if nBresenhamDiff <= 0 then
                        on bLineMoreVertical! goto LineMoreVerticalFalse, LineMoreVerticalTrue
                            LineMoreVerticalFalse:
                                tVectorDir_Y = 0
                                goto LineMoreVerticalEnd
                            LineMoreVerticalTrue:
                                tVectorDir_X = 0
                        LineMoreVerticalEnd:
                    endif

                    tFuturePoint_y! = tComputer_y! + cast!(tVectorDir_Y)
                    if screen_peek!(tComputer_x!, tFuturePoint_y!) = WALL! then
                        tWallVectorDir_Y = tVectorDir_Y
                    else
                        tWallVectorDir_Y = 0
                    endif
                    
                    tWallVectorDir_X = 0
                    if tWallVectorDir_Y = 0 then
                        tFuturePoint_x! = tComputer_x! + cast!(tVectorDir_X)
                        if screen_peek!(tFuturePoint_x!, tComputer_y!) = WALL! then
                            tWallVectorDir_X = tVectorDir_X
                        endif
                    endif

                    if tWallVectorDir_X <> 0 or tWallVectorDir_Y <> 0 then
                        '-------------------------- WALL HANDLING -------------------------
                        nFastIndex! = 0
                        repeat
                            'short circuiting
                            if cast!(tWallVectorDir_Y) = aDirections_Y![nFastIndex!] then
                                if cast!(tWallVectorDir_X) = aDirections_X![nFastIndex!] then
                                    nDirectionScalar! = nFastIndex!
                                    nFastIndex! = MAXDIR! 'early exit!
                                endif
                            endif
                            inc nFastIndex!
                        until nFastIndex! = 4 'MAXDIR! + 1

                        tWallPosition_Y! = tComputer_y! + cast!(tWallVectorDir_Y)
                        tWallPosition_X! = tComputer_x! + cast!(tWallVectorDir_X)
                        tVecComputerPlayer_Xdiff = cast(tPlayer_x!) - tWallPosition_X!
                        tVecComputerPlayer_XdiffABS = abs(tVecComputerPlayer_Xdiff)
                        tVecComputerPlayer_Ydiff = cast(tPlayer_y!) - tWallPosition_Y!
                        tVecComputerPlayer_YdiffABS = abs(tVecComputerPlayer_Ydiff)
                        if tVecComputerPlayer_YdiffABS >= tVecComputerPlayer_XdiffABS Then bLineMoreVertical! = 1 Else bLineMoreVertical! = 0
                        on bLineMoreVertical! goto MoreVertThresholdFalse, MoreVertThresholdTrue
                            MoreVertThresholdFalse:
                                nThresholdCrProd = rshift(tVecComputerPlayer_XdiffABS)
                                goto MoreVertThresholdEnd
                            MoreVertThresholdTrue:
                                nThresholdCrProd = rshift(tVecComputerPlayer_YdiffABS)
                        MoreVertThresholdEnd:

                        'Simulator INIT
                        aSimulators![0, CURRENTPOS_Y!] = tComputer_y!
                        aSimulators![0, CURRENTPOS_X!] = tComputer_x!
                        aSimulators![0, SIMWALKDIR!] = (nDirectionScalar! + 1) & MAXDIR!
                        aSimulators![0, SIMSTARTDIR!] = aSimulators![0, SIMWALKDIR!]

                        aSimulators![1, CURRENTPOS_Y!] = tComputer_y!
                        aSimulators![1, CURRENTPOS_X!] = tComputer_x!
                        aSimulators![1, SIMWALKDIR!] = (nDirectionScalar! - 1) & MAXDIR!
                        aSimulators![1, SIMSTARTDIR!] = aSimulators![1, SIMWALKDIR!]

                        'Simulator LAUNCH
                        SimulatorLoopStart:
                            nFastIndex! = 0
                            repeat
                                CheckWallStartLoop:
                                    tFuturePoint_y! = aSimulators![nFastIndex!, CURRENTPOS_Y!] + aDirections_Y![aSimulators![nFastIndex!, SIMWALKDIR!]]
                                    tFuturePoint_x! = aSimulators![nFastIndex!, CURRENTPOS_X!] + aDirections_X![aSimulators![nFastIndex!, SIMWALKDIR!]]
                                    if screen_peek!(tFuturePoint_x!, tFuturePoint_y!) <> WALL! Then Goto CheckWallExitLoop
                                    aSimulators![nFastIndex!, SIMWALKDIR!] = (aSimulators![nFastIndex!, SIMWALKDIR!] + aSimulators![nFastIndex!, SIMTURNBLOCK!]) & MAXDIR!
                                goto CheckWallStartLoop
                                CheckWallExitLoop:

                                aSimulators![nFastIndex!, CURRENTPOS_Y!] = tFuturePoint_y!
                                aSimulators![nFastIndex!, CURRENTPOS_X!] = tFuturePoint_x!
                                
                                tVecWallToSimulator_Ydiff = cast(aSimulators![nFastIndex!, CURRENTPOS_Y!]) - tWallPosition_Y!
                                tVecWallToSimulator_Xdiff = cast(aSimulators![nFastIndex!, CURRENTPOS_X!]) - tWallPosition_X!
                                
                                nCrossProduct = abs((tVecWallToSimulator_Xdiff * tVecComputerPlayer_Ydiff) - (tVecWallToSimulator_Ydiff * tVecComputerPlayer_Xdiff))
                                if nCrossProduct <= nThresholdCrProd then
                                    on bLineMoreVertical! goto LineMoreVertCrossProdFalse, LineMoreVertCrossProdTrue
                                        LineMoreVertCrossProdFalse:
                                            if tVecComputerPlayer_Xdiff > 0 then
                                                if tWallPosition_X! <= aSimulators![nFastIndex!, CURRENTPOS_X!] and aSimulators![nFastIndex!, CURRENTPOS_X!] <= tPlayer_x! then goto SimulatorLoopExit
                                            else
                                                if tPlayer_x! <= aSimulators![nFastIndex!, CURRENTPOS_X!] and aSimulators![nFastIndex!, CURRENTPOS_X!] <= tWallPosition_X! then goto SimulatorLoopExit
                                            endif
                                            goto LineMoreVertCrossProdEnd
                                        LineMoreVertCrossProdTrue:
                                            if tVecComputerPlayer_Ydiff > 0 then
                                                if tWallPosition_Y! <= aSimulators![nFastIndex!, CURRENTPOS_Y!] and aSimulators![nFastIndex!, CURRENTPOS_Y!] <= tPlayer_y! then goto SimulatorLoopExit
                                            else
                                                if tPlayer_y! <= aSimulators![nFastIndex!, CURRENTPOS_Y!] and aSimulators![nFastIndex!, CURRENTPOS_Y!] <= tWallPosition_Y! then goto SimulatorLoopExit
                                            endif
                                    LineMoreVertCrossProdEnd:
                                endif
                                
                                aSimulators![nFastIndex!, SIMWALKDIR!] = (aSimulators![nFastIndex!, SIMWALKDIR!] - aSimulators![nFastIndex!, SIMTURNBLOCK!]) & MAXDIR!
                                CheckDirStartLoop:
                                    tFuturePoint_y! = aSimulators![nFastIndex!, CURRENTPOS_Y!] + aDirections_Y![aSimulators![nFastIndex!, SIMWALKDIR!]]
                                    tFuturePoint_x! = aSimulators![nFastIndex!, CURRENTPOS_X!] + aDirections_X![aSimulators![nFastIndex!, SIMWALKDIR!]]
                                    if screen_peek!(tFuturePoint_x!, tFuturePoint_y!) <> WALL! then goto CheckDirExitLoop
                                    aSimulators![nFastIndex!, SIMWALKDIR!] = (aSimulators![nFastIndex!, SIMWALKDIR!] + aSimulators![nFastIndex!, SIMTURNBLOCK!]) & MAXDIR!
                                goto CheckDirStartLoop
                                CheckDirExitLoop:                                

                                inc nFastIndex!
                            until nFastIndex! = 2
                            textat aSimulators![0, CURRENTPOS_X!], aSimulators![0, CURRENTPOS_Y!], "0"
                            textat aSimulators![1, CURRENTPOS_X!], aSimulators![0, CURRENTPOS_Y!], "1"
                            poke 198,0: wait 198,1
                            textat aSimulators![0, CURRENTPOS_X!], aSimulators![0, CURRENTPOS_Y!], " "
                            textat aSimulators![1, CURRENTPOS_X!], aSimulators![0, CURRENTPOS_Y!], " "
                        goto SimulatorLoopStart
                        SimulatorLoopExit:
                        nSimulatorNumber! = nFastIndex!

                        bWllFllwMode! = 1
                        bPledgeMode! = 1
                        aSimulators![nSimulatorNumber!, SIMWALKDIR!] = aSimulators![nSimulatorNumber!, SIMSTARTDIR!]
                        textat 25, 0, "wf" : poke 198,0 : wait 198,1
                    else
                        if screen_peek!(tFuturePoint_x!, tFuturePoint_y!) = WALL! then
                            on bLineMoreVertical! goto DiagonalHorizontal, DiagonalVertical
                                DiagonalHorizontal:
                                    tFuturePoint_y! = tComputer_y!
                                    goto DiagonalEnd
                                DiagonalVertical:
                                    tFuturePoint_x! = tComputer_x!
                            DiagonalEnd:
                        endif
                        tComputer_y! = tFuturePoint_y!
                        tComputer_x! = tFuturePoint_x!
                        goto skipMovement
                    endif
            
                WallFollowTrue:
                    textat 25, 0, "wf!" : poke 198,0 : wait 198,1
                    WllFllwCheckWallStartLoop:
                        tFuturePoint_y! = tComputer_y! + aDirections_Y![aSimulators![nSimulatorNumber!, SIMWALKDIR!]]
                        tFuturePoint_x! = tComputer_x! + aDirections_X![aSimulators![nSimulatorNumber!, SIMWALKDIR!]]
                        if screen_peek!(tFuturePoint_x!, tFuturePoint_y!) <> WALL! Then Goto WllFllwCheckWallExitLoop
                        aSimulators![nSimulatorNumber!, SIMWALKDIR!] = (aSimulators![nSimulatorNumber!, SIMWALKDIR!] + aSimulators![nSimulatorNumber!, SIMTURNBLOCK!]) & MAXDIR!
                    goto WllFllwCheckWallStartLoop
                    WllFllwCheckWallExitLoop:

                    tComputer_y! = tFuturePoint_y!
                    tComputer_x! = tFuturePoint_x!
                    
                    if tWallVectorDir_Y <> 0 and tComputer_y! = tWallPosition_Y! then
                        bPledgeMode! = 0
                    else
                        if tWallVectorDir_X <> 0 and tComputer_x! = tWallPosition_X! then
                            bPledgeMode! = 0
                        endif
                    endif
                    
                    tVecWallToSimulator_Ydiff = abs(cast(tPlayer_y!) - aSimulators![nSimulatorNumber!, CURRENTPOS_Y!])
                    tVecWallToSimulator_Xdiff = abs(cast(tPlayer_x!) - aSimulators![nSimulatorNumber!, CURRENTPOS_X!])
                    tVecComputerPlayer_Ydiff = abs(cast(tPlayer_y!) - tComputer_y!)
                    tVecComputerPlayer_Xdiff = abs(cast(tPlayer_x!) - tComputer_x!)
                    
                    on bPledgeMode! goto PledgeModeOff, PledgeModeOn
                        PledgeModeOff:
                            if tVecComputerPlayer_Ydiff + tVecComputerPlayer_Xdiff <= tVecWallToSimulator_Ydiff + tVecWallToSimulator_Xdiff Then bWllFllwMode! = 0
                            goto PledgeModeEnd
                        PledgeModeOn:
                            'if tVecComputerPlayer_Ydiff <= tVecWallToSimulator_Ydiff And tVecComputerPlayer_Xdiff <= tVecWallToSimulator_Xdiff Then bWllFllwMode! = 0
                            if tVecComputerPlayer_Ydiff <= tVecWallToSimulator_Ydiff then
                                if tVecComputerPlayer_Xdiff <= tVecWallToSimulator_Xdiff then
                                    bWllFllwMode! = 0
                                endif
                            endif
                    PledgeModeEnd:
                    if bWllFllwMode! = 1 then
                        aSimulators![nSimulatorNumber!, SIMWALKDIR!] = (aSimulators![nSimulatorNumber!, SIMWALKDIR!] - aSimulators![nSimulatorNumber!, SIMTURNBLOCK!]) & MAXDIR!
                        WllFllwCheckDirStartLoop:
                            tFuturePoint_y! = tComputer_y! + aDirections_Y![aSimulators![nSimulatorNumber!, SIMWALKDIR!]]
                            tFuturePoint_x! = tComputer_x! + aDirections_X![aSimulators![nSimulatorNumber!, SIMWALKDIR!]]
                            if screen_peek!(tFuturePoint_x!, tFuturePoint_y!) <> WALL! then goto WllFllwCheckDirExitLoop
                            aSimulators![nSimulatorNumber!, SIMWALKDIR!] = (aSimulators![nSimulatorNumber!, SIMWALKDIR!] + aSimulators![nSimulatorNumber!, SIMTURNBLOCK!]) & MAXDIR!
                        goto WllFllwCheckDirStartLoop
                        WllFllwCheckDirExitLoop:
                    else
                        textat 25, 0, "###"
                    endif
        skipMovement:
            bMoveNow! = bMoveNow! ^ 1 ' Exclusive OR...
goto mainLoop
