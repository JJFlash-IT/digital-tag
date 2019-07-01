'#Define DEBUG ' <-- Uncomment this to activate Debug Mode!
#Define MAPFILENAME "DigitalTagMaps.txt" ' The name of the file that contains all the maps
#Ifdef DEBUG
	#Define INFOLINES 5
#Else
	#Define INFOLINES 2
#Endif
#Define SC_LEFT         &h4B
#Define SC_RIGHT        &h4D
#Define SC_UP           &h48
#Define SC_DOWN         &h50
#Define SC_ESCAPE       &h01
#Define WALL            35 ' "#"

#Define EmptyKeyboardBuffer While Inkey <> "": Wend 'Empty keyboard buffer

#Define INSTRUCTIONS_CHOOSE "<Space> Next Map - <Return> Play - <Esc> Exit"
#Define INSTRUCTIONS_PLAY "<Cursor keys> Move Asterisk - <Esc> Stop Playing"
#Define INSTRUCTIONS_PLAYAGAIN "<Space> Next Map - <Return> Play Again - <Esc> Exit"

#Macro PrintInstructions(WhichMessage)
	#Ifndef DEBUG
	View Print nSize_H + 2 To nSize_H + 2: Cls: View Print
	Color 10: Locate nSize_H + 2, (nSize_W Shr 1) - (Len(WhichMessage) Shr 1): Print WhichMessage; 'Print the message centered
	#EndIf
#Endmacro

Dim Shared As Integer nSize_H, nSize_W 'Height and Width of the map window
Declare Sub LoadMap()
Declare Sub Chase_Main()

'The Map Select loop
Dim nKeyAscii As Integer
Do	
	Windowtitle "CHOOSE!"	
	LoadMap() 'Loads a single map and creates a window to display it
	PrintInstructions(INSTRUCTIONS_CHOOSE)
	EmptyKeyboardBuffer
	Do
		nKeyAscii = GetKey()
		Select Case nKeyAscii
			Case 27 'ESC
				Exit Do, Do 'End Program!
			Case 13 'Return/Enter
				Windowtitle "PLAY!"
				PrintInstructions(INSTRUCTIONS_PLAY)
				Chase_Main() 'Calls the main loop
				Windowtitle "PLAY AGAIN?"
				PrintInstructions(INSTRUCTIONS_PLAYAGAIN)
			Case 32 'Space bar
				Exit Do 'And choose another map
		End Select
	Loop
Loop

'Load a single map and display it
Sub LoadMap()
	Dim As Integer nStringLength
	Dim As String sInputLine, sMapString, sMapName
	Static nSeekPosition As Integer
	nSize_H = 0: nSize_W = 0
	
	If Open (ExePath + "\" + MAPFILENAME For Input As #1) Then
		Screen 11: Print "?FILE  ERROR : " ; MAPFILENAME : GetKey: Stop
	Else
		If nSeekPosition Then Seek #1, nSeekPosition
		Line Input #1, sMapName
		Do
			Line Input #1, sInputLine
			nStringLength = Len(sInputLine)
			If nStringLength = 0 Then Exit Do
			nSize_H += 1 : nSize_W = IIf(nStringLength > nSize_W, nStringLength, nSize_W) 'The care I put here is actually useless: every line of the map *has* to be the same width as the first one...
			sMapString += sInputLine
		Loop Until Eof(1)
		If Eof(1) Then nSeekPosition = 0 Else nSeekPosition = Seek(1)
		Close #1
		
		ScreenRes 8 * nSize_W, (8 * nSize_H) + (INFOLINES * 8), 4, 2 'The font I'm using is 8x8; Bit-depth: 16 bit (4); I'm also using double buffering (2 = two screen buffers)
		Width nSize_W, (nSize_H + INFOLINES)
		Cls
		
		'Printing the map here...
		Palette 6, 128, 128, 0 ' I want the walls to be printed in dark yellow
		Color 6: Print sMapString;
		#Ifndef DEBUG
		Color 14: Locate nSize_H + 1, (nSize_W Shr 1) - (Len(sMapName) Shr 1): Print sMapName; 'Print the map title centered
		#Endif
	End If
End Sub

'The MAIN loop!
Sub Chase_Main() '-------------------------------------------------------------------------------------------------------------

Dim As Boolean bMoveNow 'This is for the Computer character: it moves half the speed of the Player; this alternates between False and True

Type strVectorDir 'This is for Unit Vectors, the Integers represent single increments/decrements
	IncrRow As Integer
	IncrCol As Integer	
End Type
Dim tVectorDir As strVectorDir

Dim aDirections(0 To 3) As strVectorDir => {(-1,0),(0,1),(1,0),(0,-1)} 'North, East, South, West : this is for "converting" vector directions into "scalar" directions
Dim As Integer nDirectionNumber 'This is for storing the "scalar" direction of a Wall char encountered
#Define NUMDIRS 3 'This is actually not how many directions there are, rather the upper limit of possible values: 0, 1, 2, 3
#Define CLOCKWISE 1
#Define ANTICLOCKWISE -1

Type strPoint 'This is for Points on the map: it's used for the Player coordinates, Computer coordinates and other Points
	Row As Integer
	Col As Integer
End Type
'Player and Computer start on opposite sides of the map; the map HAS to be surrounded by a wall "frame"
Dim tPlayerPoint As strPoint => (2,2)
Dim tComputerPoint As strPoint => (nSize_H - 1, nSize_W - 1)

Type strCoordDiff 'This is for measuring Manhattan distances: I store both signed and absolute values
	RowDiff As Integer
	ColDiff As Integer
	RowDiffAbs As Integer
	ColDiffAbs As Integer
End Type

'A whole bunch of variables which will be explained once they're actually being used in the program
Dim As strPoint tOnTheWallPosition, tFuturePoint
Dim tWallVectorDir As strVectorDir
Dim As Boolean bLineMoreVertical, bWllFllwMode, bPledgeMode
Dim As Integer nBresenhamDiff, nCrossProduct, nThresholdCrProd
Dim As strCoordDiff tDistanceLine, tDistancePoint, tWllFllwSimulDistance, tWllFllwPlayerDistance

'This is for *simulators*, the main trick of the Chain Algorithm by Walter D. Pullen (will explain later)
Type strSimulatorStruct
	CurrentPosition As strPoint
	SimulWalkingDirection As Integer
	SimulStartingDirection As Integer
	SimulTurnDirBlocked As Integer
End Type
Dim tSimulators(1 To 2) As strSimulatorStruct
Dim nSimulatorNumber As Integer 'This is for choosing which simulator to follow for real

'Make sure that both Player and Computer start in an empty cell of the map
With tPlayerPoint
	While Screen(.Row, .Col) = WALL
		.Row += 1
		.Col += 1
	Wend
End With
With tComputerPoint
	While Screen(.Row, .Col) = WALL
		.Row -= 1
		.Col -= 1
	Wend
End With

ScreenSet 0, 1 'Double buffering: I resorted to that because I'm lazy :D
Do
	' "Paint" the characters
	With tPlayerPoint
		Locate .Row, .Col
		Color 15: Print "*"; 'the Player, in WHITE
	End With
	With tComputerPoint
		Locate .Row, .Col
		Color 12: Print Chr(1); 'the Computer, in RED
	End With
	If PCopy(0, 1) Then Screen 11: Print "PCopy error!" : Getkey : Stop 'This makes sure that copying from the work buffer to the window buffer actually works
	Sleep 40,1
'	If bMoveNow And bWllFllwMode Then EmptyKeyboardBuffer : GetKey ' This is useful in Debug Mode 
	' Erase the characters
	With tPlayerPoint
		Locate .Row, .Col
		Print " "; 'Erase Player 
	End With
	With tComputerPoint
		Locate .Row, .Col
		Print " "; 'Erase Computer
	End With

	'--------------------------------------------Player movement---------------------------------------------------------
	With tPlayerPoint
    	tVectorDir.IncrRow = 0 : tVectorDir.IncrCol = 0
		' Check arrow keys and update the (x, y) position accordingly
		If MultiKey(SC_LEFT ) Then tVectorDir.IncrCol = -1  
		If MultiKey(SC_RIGHT) Then tVectorDir.IncrCol = +1 
		If MultiKey(SC_UP   ) Then tVectorDir.IncrRow = -1
		If MultiKey(SC_DOWN ) Then tVectorDir.IncrRow = +1
		EmptyKeyboardBuffer
		
		'Yes, I'm checking separately...
		tFuturePoint.Row = .Row + tVectorDir.IncrRow
		If Screen(tFuturePoint.Row, .Col) <> WALL Then .Row = tFuturePoint.Row
		tFuturePoint.Col = .Col + tVectorDir.IncrCol
		If Screen(.Row, tFuturePoint.Col) <> WALL Then .Col = tFuturePoint.Col
	End With
	
	'--------------------------------------------Computer movement------------------------------------------------------
If bMoveNow Then 'Half the time, the Computer doesn't move, so it moves half the Player speed
	With tComputerPoint
		If Not bWllFllwMode Then 'If the Computer isn't in Wall Following mode, it simply moves on the line from itself to the Player
			With tDistanceLine
				.RowDiff = tPlayerPoint.Row - tComputerPoint.Row
				.RowDiffAbs = Abs(.RowDiff)
				.ColDiff = tPlayerPoint.Col - tComputerPoint.Col
				.ColDiffAbs = Abs(.ColDiff)
				bLineMoreVertical = ( .RowDiffAbs >= .ColDiffAbs )
				tVectorDir.IncrRow = Sgn(.RowDiff)
				tVectorDir.IncrCol = Sgn(.ColDiff)
				'This is an "abridged" version of the Bresenham's Line Algorithm: I calculate the starting difference, but
				'I'm not adding the subsequent errors because the Player can move and so there's no fixed line to draw
				'The result is that the Computer will tend to move diagonally only when it is close enough to the Player
				nBresenhamDiff = IIf(bLineMoreVertical, 2 * .ColDiffAbs - .RowDiffAbs, 2 * .RowDiffAbs - .ColDiffAbs)
				If nBresenhamDiff <= 0 Then
					Select Case bLineMoreVertical
						Case True
							tVectorDir.IncrCol = 0
						Case False
							tVectorDir.IncrRow = 0
					End Select
				EndIf
			End With

			tFuturePoint.Row = .Row + tVectorDir.IncrRow
		  	If Screen(tFuturePoint.Row, .Col) = WALL Then
				tWallVectorDir.IncrRow = tVectorDir.IncrRow
			Else
				tWallVectorDir.IncrRow = 0
				.Row = tFuturePoint.Row
			EndIf						

			tWallVectorDir.IncrCol = 0			
			If tWallVectorDir.IncrRow = 0 Then 'If I bumped on a wall vertically, I don't care what's horizontally adjacent
				tFuturePoint.Col = .Col + tVectorDir.IncrCol				
				If Screen(.Row, tFuturePoint.Col) = WALL Then
					tWallVectorDir.IncrCol = tVectorDir.IncrCol
				Else
					.Col = tFuturePoint.Col
				Endif
			EndIf

			If tWallVectorDir.IncrRow Or tWallVectorDir.IncrCol Then 'I bumped into a Wall! :-o		
				'Which "Scalar" direction is the Wall I bumped into?
				For nDirectionIter As Integer = 0 to NUMDIRS
					If tWallVectorDir.IncrRow = aDirections(nDirectionIter).IncrRow And tWallVectorDir.IncrCol = aDirections(nDirectionIter).IncrCol Then 
						nDirectionNumber = nDirectionIter
						Exit For 'EUREKA
					End If
				Next nDirectionIter

				'This is for calculating the Vector components, starting from *the Wall* position (rather than the Computer position) to the Player position
				'This is done to make sure that the next point on the Vector is found on the *other* side of the Wall
				With tOnTheWallPosition
					.Row = tComputerPoint.Row + tWallVectorDir.IncrRow
					.Col = tComputerPoint.Col + tWallVectorDir.IncrCol
				End With
				With tDistanceLine
					.RowDiff = tPlayerPoint.Row - tOnTheWallPosition.Row
					.RowDiffAbs = Abs(.RowDiff)
					.ColDiff = tPlayerPoint.Col - tOnTheWallPosition.Col
					.ColDiffAbs = Abs(.ColDiff)
					bLineMoreVertical = ( .RowDiffAbs >= .ColDiffAbs )
					'What's this for? I'll explain later :-)
					nThresholdCrProd = IIf(bLineMoreVertical, .RowDiffAbs, .ColDiffAbs) Shr 1 'I "discovered" this Threshold formula by experimentation through a small program I wrote aside: I *don't* know why this particular formula works :-D
				End With
				#Ifdef DEBUG
					ScreenSet
					Locate nSize_H + 1, 1: Print "Threshold:" ; nThresholdCrProd ; "   ";
					If nSimulatorNumber > 0 Then 					
						With tSimulators(nSimulatorNumber).CurrentPosition
							Locate .Row, .Col: Print " ";
						End With
					EndIf
				#Endif

				'Simulator INIT
				With tSimulators(1) 'This will go to the right and will follow Walls in a Clockwise fashion
					.CurrentPosition = tComputerPoint
					.SimulWalkingDirection = (nDirectionNumber + 1) And NUMDIRS 
					.SimulStartingDirection = .SimulWalkingDirection
					.SimulTurnDirBlocked = CLOCKWISE
				End With
				With tSimulators(2) 'This will go to the left and will follow Walls in a Anticlockwise fashion
					.CurrentPosition = tComputerPoint
					.SimulWalkingDirection = (nDirectionNumber - 1) And NUMDIRS
					.SimulStartingDirection = .SimulWalkingDirection
					.SimulTurnDirBlocked = ANTICLOCKWISE
				End With			
				
				'LAUNCH of the Simulators! These are what Pullen calls "robots": they explore the wall, each in its direction around it
				'until one of them arrives at a point which is on the Wall->Player line *segment*. When this happens, the Computer will go the same
				'direction as the "winning" Simulator!
				Do
					For nSimulatorNumber = 1 To 2
						With tSimulators(nSimulatorNumber)
							Do							
								'First, I try to move...
								tFuturePoint.Row = .CurrentPosition.Row + aDirections(.SimulWalkingDirection).IncrRow
								tFuturePoint.Col = .CurrentPosition.Col + aDirections(.SimulWalkingDirection).IncrCol
								'If there's a Wall ahead, I turn to avoid it, and try again in the new direction...
								If Screen(tFuturePoint.Row, tFuturePoint.Col) <> WALL Then Exit Do '... until there is no Wall ahead
								.SimulWalkingDirection = (.SimulWalkingDirection + .SimulTurnDirBlocked) And NUMDIRS
							Loop
							
							.CurrentPosition = tFuturePoint 'Simulator has now moved
							
							'This is *another* Vector that goes from the Wall position to the CurrentPosition
							tDistancePoint.RowDiff = .CurrentPosition.Row - tOnTheWallPosition.Row
							tDistancePoint.ColDiff = .CurrentPosition.Col - tOnTheWallPosition.Col
							'Here I do the Cross Product of the "real" Vector by the "simulator" Vector
							nCrossProduct = (tDistancePoint.ColDiff * tDistanceLine.RowDiff) - (tDistancePoint.RowDiff * tDistanceLine.ColDiff)
							#Ifdef DEBUG
								Locate nSize_H + 1 + nSimulatorNumber, 1: Print "Cross Product[" ; Str(nSimulatorNumber) ; "]:" ; nCrossProduct ; "   ";
							#Endif
							'How can we tell if both Vectors point at the same OR opposite direction? When the Cross Product = 0. BUT...
							'In the Integer space where we are, this is rarely true, so a Threshold value has to be used. If the Cross Product is equal
							'or LESS than this Threshold, then CurrentPosition is on the line...
							If Abs(nCrossProduct) <= nThresholdCrProd Then
								'It's not over! I also need to check if CurrentPosition is *between* the Wall and the Player position!
								If bLineMoreVertical Then ' If the Wall->Player line is more vertical than horizontal, I check the Row coordinates
									If IIf(tDistanceLine.RowDiff > 0, _
									tOnTheWallPosition.Row <= .CurrentPosition.Row And .CurrentPosition.Row <= tPlayerPoint.Row, _
									tPlayerPoint.Row <= .CurrentPosition.Row And .CurrentPosition.Row <= tOnTheWallPosition.Row) Then Exit Do 'That's it, this Simulator wins the race!
								Else ' Otherwise, I check the Column coordinates
									If IIf(tDistanceLine.ColDiff > 0, _
									tOnTheWallPosition.Col <= .CurrentPosition.Col And .CurrentPosition.Col <= tPlayerPoint.Col, _
									tPlayerPoint.Col <= .CurrentPosition.Col And .CurrentPosition.Col <= tOnTheWallPosition.Col) Then Exit Do 'That's it, this Simulator wins the race!
								EndIf
							EndIf

							'After moving, I try to turn to the OPPOSITE direction of the one followed to turn around Walls...
							.SimulWalkingDirection = (.SimulWalkingDirection - .SimulTurnDirBlocked) And NUMDIRS
							While Screen(.CurrentPosition.Row + aDirections(.SimulWalkingDirection).IncrRow, .CurrentPosition.Col + aDirections(.SimulWalkingDirection).IncrCol) = WALL
								'If there's a Wall ahead, I turn to avoid it and try again, until the passage ahead is free
								.SimulWalkingDirection = (.SimulWalkingDirection + .SimulTurnDirBlocked) And NUMDIRS
							Wend

						End With
					Next nSimulatorNumber
					#Ifdef DEBUG
						Color 13
						With tSimulators(1).CurrentPosition
							Locate .Row, .Col: Print "1";
						End With
						With tSimulators(2).CurrentPosition
							Locate .Row, .Col: Print "2";
						End With
						Sleep 20,1					
						With tSimulators(1).CurrentPosition
							Locate .Row, .Col: Print " ";
						End With
						With tSimulators(2).CurrentPosition
							Locate .Row, .Col: Print " ";
						End With
					#Endif
				Loop
				
				#Ifdef DEBUG
					Color 14
					With tSimulators(nSimulatorNumber).CurrentPosition
						Locate .Row, .Col: Print Str(nSimulatorNumber);
						Sleep 500
						Locate .Row, .Col: Print " ";
					End With
					View Print nSize_H + 1 To nSize_H + INFOLINES
					Cls
					View Print
				#Endif
				
				'Now the Computer enters the Wall Following mode
				bWllFllwMode = True
				bPledgeMode = True 'This is a misnomer, it's something *remotely similar* to the Pledge algorithm, but I couldn't find a better name for it :-D
				With tSimulators(nSimulatorNumber)
					.SimulWalkingDirection = .SimulStartingDirection
					'This is a hack for Walls bumped diagonally...
					If tWallVectorDir.IncrCol And tVectorDir.IncrRow Then
						Select Case aDirections(.SimulWalkingDirection).IncrRow = tVectorDir.IncrRow
							Case True
								'If Computer is about to move in the same direction as when it bumped, I compensate for it
								tComputerPoint.Row -= tVectorDir.IncrRow
							Case False
								'Otherwise, Computer is basically going back to where it came from, so it will appear motionless for a couple of frames
								'I compensate for this by setting bMoveNow to False, so Computer will only lose one frame
								'I couldn't come up with something better without messing up, I'm sure there's a better way...
								bMoveNow = False
						End Select
					EndIf
				End With

			End If
		End If
		
		If bWllFllwMode Then 'If Computer is in Wall Following mode, then it follows walls :-D
			'This is almost the same of the Simulator routine, it mainly differs in the exit condition...
			With tSimulators(nSimulatorNumber)
				'I check to see if there is a Wall ahead: if so, I keep on turning until there's no Wall ahead
				Do							
					tFuturePoint.Row = tComputerPoint.Row + aDirections(.SimulWalkingDirection).IncrRow
					tFuturePoint.Col = tComputerPoint.Col + aDirections(.SimulWalkingDirection).IncrCol
					If Screen(tFuturePoint.Row, tFuturePoint.Col) <> WALL Then Exit Do
					.SimulWalkingDirection = (.SimulWalkingDirection + .SimulTurnDirBlocked) And NUMDIRS
				Loop
				
				tComputerPoint = tFuturePoint
				'If Computer has managed to walk to the Wall row/column by going around it, I turn off the "Pledge" mode
				If (tWallVectorDir.IncrRow And tComputerPoint.Row = tOnTheWallPosition.Row) Or _
					(tWallVectorDir.IncrCol And tComputerPoint.Col = tOnTheWallPosition.Col) Then bPledgeMode = False
				
				'Here I'm measuring the distance between the Simulator and the Player, and also the one between the Computer and the Player
				tWllFllwSimulDistance.RowDiff = Abs(tPlayerPoint.Row - .CurrentPosition.Row)
				tWllFllwSimulDistance.ColDiff = Abs(tPlayerPoint.Col - .CurrentPosition.Col)
				tWllFllwPlayerDistance.RowDiff = Abs(tPlayerPoint.Row - tComputerPoint.Row)
				tWllFllwPlayerDistance.ColDiff = Abs(tPlayerPoint.Col - tComputerPoint.Col)

				'The goal here is to see if the Computer is somehow closer to the Player than the Simulator OR at the same position of the Simulator
				'If "Pledge" Mode is on, this check is strict: BOTH the Row distance AND the Column distance of the Computer have to be less than
				'(or equal to) the Row and Column distance of the Simulator, so it's hard to get out of the Wall Following mode
				'If "Pledge" Mode is off, this check is relaxed: the Manhattan Distance from the Computer to the Player has to be less than or equal to the
				'Manhattan Distance of the Simulator; this makes it easier to get out of the Wall Following mode
				If IIf(bPledgeMode, _
				tWllFllwPlayerDistance.RowDiff <= tWllFllwSimulDistance.RowDiff And tWllFllwPlayerDistance.ColDiff <= tWllFllwSimulDistance.ColDiff, _
				(tWllFllwPlayerDistance.RowDiff + tWllFllwPlayerDistance.ColDiff) <= (tWllFllwSimulDistance.RowDiff + tWllFllwSimulDistance.ColDiff)) Then
					bWllFllwMode = False 'Out of the Wall Following mode!
				Else
					'Like before, I try to turn to the OPPOSITE direction of the one followed to turn around Walls...
					.SimulWalkingDirection = (.SimulWalkingDirection - .SimulTurnDirBlocked) And NUMDIRS
					While Screen(tComputerPoint.Row + aDirections(.SimulWalkingDirection).IncrRow, tComputerPoint.Col + aDirections(.SimulWalkingDirection).IncrCol) = WALL
						'If there's a Wall ahead, I turn to avoid it and try again, until the passage ahead is free
						.SimulWalkingDirection = (.SimulWalkingDirection + .SimulTurnDirBlocked) And NUMDIRS
					Wend
				EndIf

				#Ifdef DEBUG
					If bWllFllwMode Then
						Locate .CurrentPosition.Row, .CurrentPosition.Col: Print Str(nSimulatorNumber);
						Locate nSize_H + 1, 1: Print "PledgeMode: " ; bPledgeMode ; "    ";
						Locate nSize_H + 2, 1: Print "WllFllwSimulDistance.RowDiff:" ; tWllFllwSimulDistance.RowDiff ; "    ";
						Locate nSize_H + 3, 1: Print "WllFllwSimulDistance.ColDiff:" ; tWllFllwSimulDistance.ColDiff ; " (Total:" ; tWllFllwSimulDistance.RowDiff + tWllFllwSimulDistance.ColDiff ;")   ";
						Locate nSize_H + 4, 1: Print "WllFllwPlayerDistance.RowDiff:" ; tWllFllwPlayerDistance.RowDiff ; "    ";
						Locate nSize_H + 5, 1: Print "WllFllwPlayerDistance.ColDiff:" ; tWllFllwPlayerDistance.ColDiff ; " (Total:" ; tWllFllwPlayerDistance.RowDiff + tWllFllwPlayerDistance.ColDiff ; ")    ";
					Else
						View Print nSize_H + 1 To nSize_H + INFOLINES : Cls: View Print
					Endif
					ScreenSet 0, 1
				#Endif
				
			End With
		EndIf	
	End With
End If
	bMoveNow = Not bMoveNow
Loop Until Multikey(SC_ESCAPE) 'press ESC key to exit the main loop
EmptyKeyboardBuffer

#Ifdef DEBUG
	View Print nSize_H + 1 To nSize_H + INFOLINES : Cls: View Print
	If nSimulatorNumber > 0 Then 					
		With tSimulators(nSimulatorNumber).CurrentPosition
			Locate .Row, .Col: Print " ";
		End With
	EndIf
#Endif

Screenset 'Turn off double buffering
End Sub ' Sub Chase_Main() -------------------------------------------------------------------------------------------------------------
