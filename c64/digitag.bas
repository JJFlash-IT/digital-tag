include "..\extensions\xcb-ext-joystick\xcb-ext-joystick.bas"

const RASTER_LINE = $d012

const WALL! = 35 ' "#"
const PLAYER_CHAR! = 42 ' "*"
const COMPUTER_CHAR! = 0 ' "@"
const EMPTY_CHAR! = 32 ' " "

poke 53280, 0: poke 53281, 0
data mazebin![] = incbin "maze.bin"
memset $d800, 1000, 8
memcpy @mazebin!, $0400, 1000

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
dim tVectorDir_X : dim tVectorDir_Y
dim tWallVectorDir_X : dim tWallVectorDir_Y
dim nBresenhamDiff
bLineMoreVertical! = 0

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
    'wait 198,1 : poke 198, 0
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

        tFuturePoint_y! = cast!(cast(tComputer_y!) + tVectorDir_Y)
        if screen_peek!(tComputer_x!, tFuturePoint_y!) = WALL! then
            tWallVectorDir_Y = tVectorDir_Y
        else
            tWallVectorDir_Y = 0
        endif
        
        tWallVectorDir_X = 0
        if tWallVectorDir_Y = 0 then
            tFuturePoint_x! = cast!(cast(tComputer_x!) + tVectorDir_X)
            if screen_peek!(tFuturePoint_x!, tComputer_y!) = WALL! then
                tWallVectorDir_X = tVectorDir_X
            endif
        endif

        if tWallVectorDir_X <> 0 or tWallVectorDir_Y <> 0 then
            'wall bump
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
        endif

skipMovement:
        bMoveNow! = bMoveNow! ^ 1 ' Exclusive OR...
goto mainLoop
