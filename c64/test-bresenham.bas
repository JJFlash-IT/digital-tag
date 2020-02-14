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
        charat x, y, 42 'plot(x, y) - 42 = "*"
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
        charat x, y, 42 'plot(x, y) - 42 = "*"
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

print "{CLR}"
call plotLine (0, 24, 39, 0)
poke 198, 0: wait 198, 1
