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

tFuturePoint_x! = 0: tFuturePoint_y! = 0
bMoveNow! = 0

tVecComputerPlayer_Xdiff = 0 : tVecComputerPlayer_Ydiff = 0 : tVecComputerPlayer_XdiffABS = 0 : tVecComputerPlayer_YdiffABS = 0
tVecWallToSimulator_Xdiff = 0 : tVecWallToSimulator_Ydiff = 0
tVectorDir_X = 0 : tVectorDir_Y = 0
tWallVectorDir_X = 0 : tWallVectorDir_Y = 0
tWallPosition_Y! = 0
tWallPosition_X! = 0
nBresenhamDiff = 0 : nCrossProduct = 0 : nThresholdCrProd = 0
bLineMoreVertical! = 0

const MAXDIR! = 3
nDirectionScalar! = 0
'255 equivalent to -1!
data aDirections_Y![] = 255, 0, 1, 0 ' north, east, south, west
data aDirections_X![] = 0, 1, 0, 255 ' north, east, south, west

bWllFllwMode! = 0
bPledgeMode! = 0
nSimulatorNumber! = 0

Const CURRENTPOS_Y! = 0 : Const CURRENTPOS_X! = 1 : Const SIMWALKDIR! = 2 : Const SIMSTARTDIR! = 3 : Const SIMBLOCKDIR! = 4 : Const SIMTURNBLOCK! = 5
dim aSimulators![2, 6]
aSimulators![0, SIMTURNBLOCK!] = 1 ' Clockwise
aSimulators![1, SIMTURNBLOCK!] = 255 'Anticlockwise - Simulates -1 !

dim bresenhamMap![1000]
proc plotLineLow(x0,y0, x1,y1)
    dx = x1 - x0
    dy = y1 - y0
    yi = 1
    if dy < 0 then
        yi = -1
        dy = 0 - dy
    endif
    D = lshift(dy) - dx
    y = y0

    x = x0
    repeat
        \bresenhamMap![(y * 40) + x] = 1 'plot(x, y)
        if D > 0 then
               y = y + yi
               D = D - lshift(dx)
        endif
        D = D + lshift(dy)

        inc x
    until x > x1
endproc

proc plotLineHigh(x0,y0, x1,y1)
    dx = x1 - x0
    dy = y1 - y0
    xi = 1
    if dx < 0 then
        xi = -1
        dx = 0 - dx
    endif
    D = lshift(dx) - dy
    x = x0

    y = y0
    repeat
        \bresenhamMap![(y * 40) + x] = 1 'plot(x, y)
        if D > 0 then
               x = x + xi
               D = D - lshift(dy)
        endif
        D = D + lshift(dx)

        inc y
    until y > y1
endproc

proc plotLine(x0,y0, x1,y1)
    if abs(y1 - y0) < abs(x1 - x0) then
        if x0 > x1 then
            call plotLineLow(x1, y1, x0, y0)
        else
            call plotLineLow(x0, y0, x1, y1)
        endif
    else
        if y0 > y1 then
            call plotLineHigh(x1, y1, x0, y0)
        else
            call plotLineHigh(x0, y0, x1, y1)
        endif
    endif
endproc

poke 53280, 0: poke 53281, 0
data mazebin![] = incbin "testmap.bin"
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

    watch RASTER_LINE, 250
    'if bMoveNow! = 1 then poke 198, 0 : wait 198,1
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
                            nBresenhamDiff = lshift(tVecComputerPlayer_XdiffABS) - tVecComputerPlayer_YdiffABS
                            goto BresenhamEnd
                        BresenhamHorizontal:
                            nBresenhamDiff = lshift(tVecComputerPlayer_YdiffABS) - tVecComputerPlayer_XdiffABS
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
                        on tWallVectorDir_Y + 1 goto wallNorth, noYwall, wallSouth ' -1, 0, 1
                            wallNorth:
                                nDirectionScalar! = 0 'north
                                goto DirectionScalarFound
                            wallSouth:
                                nDirectionScalar! = 2 'south
                                goto DirectionScalarFound
                            noYwall:
                                on tWallVectorDir_X + 1 goto wallWest, DirectionScalarFound, wallEast ' -1, 0, 1
                                wallWest:
                                    nDirectionScalar! = 3 'west
                                    goto DirectionScalarFound
                                wallEast:
                                    nDirectionScalar! = 1 'east
                        DirectionScalarFound:

                        tWallPosition_Y! = tComputer_y! + cast!(tWallVectorDir_Y)
                        tWallPosition_X! = tComputer_x! + cast!(tWallVectorDir_X)

                        memset @bresenhamMap!, 1000, 0
                        call plotLine(tWallPosition_X!,tWallPosition_Y!, tPlayer_x!, tPlayer_y!)

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
                        nSimulatorNumber! = 0
                        SimulatorLoopStart:
                            CheckWallStartLoop:
                                tFuturePoint_y! = aSimulators![nSimulatorNumber!, CURRENTPOS_Y!] + aDirections_Y![aSimulators![nSimulatorNumber!, SIMWALKDIR!]]
                                tFuturePoint_x! = aSimulators![nSimulatorNumber!, CURRENTPOS_X!] + aDirections_X![aSimulators![nSimulatorNumber!, SIMWALKDIR!]]
                                if screen_peek!(tFuturePoint_x!, tFuturePoint_y!) <> WALL! Then Goto CheckWallExitLoop
                                aSimulators![nSimulatorNumber!, SIMWALKDIR!] = (aSimulators![nSimulatorNumber!, SIMWALKDIR!] + aSimulators![nSimulatorNumber!, SIMTURNBLOCK!]) & MAXDIR!
                                goto CheckWallStartLoop
                            CheckWallExitLoop:

                            aSimulators![nSimulatorNumber!, CURRENTPOS_Y!] = tFuturePoint_y!
                            aSimulators![nSimulatorNumber!, CURRENTPOS_X!] = tFuturePoint_x!
                                
                            if bresenhamMap![(cast(tFuturePoint_y!) * 40) + tFuturePoint_x!] = 1 then goto SimulatorLoopExit

                            aSimulators![nSimulatorNumber!, SIMWALKDIR!] = (aSimulators![nSimulatorNumber!, SIMWALKDIR!] - aSimulators![nSimulatorNumber!, SIMTURNBLOCK!]) & MAXDIR!

                            nSimulatorNumber! = nSimulatorNumber! ^ 1 'Alternates 1, 0, 1, 0, ...
                            'textat aSimulators![0, CURRENTPOS_X!], aSimulators![0, CURRENTPOS_Y!], "0"
                            'textat aSimulators![1, CURRENTPOS_X!], aSimulators![1, CURRENTPOS_Y!], "1"
                            'poke 198,0: wait 198,1
                            'textat aSimulators![0, CURRENTPOS_X!], aSimulators![0, CURRENTPOS_Y!], " "
                            'textat aSimulators![1, CURRENTPOS_X!], aSimulators![1, CURRENTPOS_Y!], " "
                            goto SimulatorLoopStart
                        SimulatorLoopExit:

                        bWllFllwMode! = 1
                        bPledgeMode! = 1
                        aSimulators![nSimulatorNumber!, SIMWALKDIR!] = aSimulators![nSimulatorNumber!, SIMSTARTDIR!]
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
                    WllFllwCheckWallStartLoop:
                        tFuturePoint_y! = tComputer_y! + aDirections_Y![aSimulators![nSimulatorNumber!, SIMWALKDIR!]]
                        tFuturePoint_x! = tComputer_x! + aDirections_X![aSimulators![nSimulatorNumber!, SIMWALKDIR!]]
                        if screen_peek!(tFuturePoint_x!, tFuturePoint_y!) <> WALL! Then Goto WllFllwCheckWallExitLoop
                        aSimulators![nSimulatorNumber!, SIMWALKDIR!] = (aSimulators![nSimulatorNumber!, SIMWALKDIR!] + aSimulators![nSimulatorNumber!, SIMTURNBLOCK!]) & MAXDIR!
                    goto WllFllwCheckWallStartLoop
                    WllFllwCheckWallExitLoop:

                    tComputer_y! = tFuturePoint_y!
                    tComputer_x! = tFuturePoint_x!

                    on bPledgeMode! goto skipPledge, checkPledge
                    checkPledge:
                        if tWallVectorDir_Y <> 0 and tComputer_y! = tWallPosition_Y! then
                            bPledgeMode! = 0
                        else
                            if tWallVectorDir_X <> 0 and tComputer_x! = tWallPosition_X! then
                                bPledgeMode! = 0
                            endif
                        endif
                    skipPledge:
                    
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
                    endif
        skipMovement:
            bMoveNow! = bMoveNow! ^ 1 ' Exclusive OR...
goto mainLoop
