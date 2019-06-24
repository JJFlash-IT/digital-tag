'#Define DEBUG
#Define MAPFILENAME "DigitalTagMaps.txt"
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
#Define WALL			35 ' "#"

#Define EmptyKeyboardBuffer While Inkey <> "": Wend 'Empty keyboard buffer!

#Define INSTRUCTIONS_CHOOSE "<Space> Next Map - <Return> Play - <Esc> Exit"
#Define INSTRUCTIONS_PLAY "<Cursor keys> Move Asterisk - <Esc> Stop Playing"
#Define INSTRUCTIONS_PLAYAGAIN "<Space> Next Map - <Return> Play Again - <Esc> Exit"

#Macro PrintInstructions(WhichMessage)
	#Ifndef DEBUG
	View Print nSize_H + 2 To nSize_H + 2: Cls: View Print
	Color 10: Locate nSize_H + 2, (nSize_W Shr 1) - (Len(WhichMessage) Shr 1): Print WhichMessage;
	#EndIf
#Endmacro

Dim Shared As Integer nSize_H, nSize_W 
Declare Sub LoadMap()
Declare Sub Chase_Main()

'Main loop!
Dim nKeyAscii As Integer
Do	
	Windowtitle "CHOOSE!"	
	LoadMap()
	PrintInstructions(INSTRUCTIONS_CHOOSE)
	EmptyKeyboardBuffer
	Do
		nKeyAscii = GetKey()
		Select Case nKeyAscii
			Case 27 'ESC
				Exit Do, Do 'End Program
			Case 13 'Return/Enter
				Windowtitle "PLAY!"
				PrintInstructions(INSTRUCTIONS_PLAY)
				Chase_Main()
				Windowtitle "PLAY AGAIN?"
				PrintInstructions(INSTRUCTIONS_PLAYAGAIN)
			Case 32 'Space bar
				Exit Do 'And choose another map
		End Select
	Loop
Loop

'Carico mappa
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
			nSize_H += 1 : nSize_W = IIf(nStringLength > nSize_W, nStringLength, nSize_W)
			sMapString += sInputLine
		Loop Until Eof(1)
		If Eof(1) Then nSeekPosition = 0 Else nSeekPosition = Seek(1)
		Close #1
		
		ScreenRes 8 * nSize_W, (8 * nSize_H) + (INFOLINES * 8), 4, 2
		Width nSize_W, (nSize_H + INFOLINES)
		Cls
		
		'Print... in giallo spento
		Palette 6, 128, 128, 0 ' Ottengo il giallo spento
		Color 6: Print sMapString;
		#Ifndef DEBUG
		Color 14: Locate nSize_H + 1, (nSize_W Shr 1) - (Len(sMapName) Shr 1): Print sMapName;
		#Endif
	End If
End Sub

Sub Chase_Main() '-------------------------------------------------------------------------------------------------------------

Dim As Boolean bMoveNow

Type strVectorDir
	IncrRow As Integer
	IncrCol As Integer	
End Type
Dim tVectorDir As strVectorDir

Dim aDirections(0 To 3) As strVectorDir => {(-1,0),(0,1),(1,0),(0,-1)} 'nord, est, sud, ovest
Dim As Integer nDirectionNumber
#Define NUMDIRS 3
#Define CLOCKWISE 1
#Define ANTICLOCKWISE -1

Type strPoint
	Row As Integer
	Col As Integer
End Type
Dim tPlayerPoint As strPoint => (2,2)
Dim tComputerPoint As strPoint => (nSize_H - 1, nSize_W - 1)

Type strCoordDiff
	RowDiff As Integer
	ColDiff As Integer
	RowDiffAbs As Integer
	ColDiffAbs As Integer
End Type

Dim As strPoint tOnTheWallPosition, tFuturePoint
Dim tWallVectorDir As strVectorDir
Dim As Boolean bLineMoreVertical, bWllFllwMode, bPledgeMode', bTurnCounterIsZero
Dim As Integer nBresenhamDiff, nCrossProduct, nThresholdCrProd', nTurnCount
Dim As strCoordDiff tDistanceLine, tDistancePoint, tWllFllwSimulDistance, tWllFllwPlayerDistance

Type strSimulatorStruct
	CurrentPosition As strPoint
	SimulWalkingDirection As Integer
	SimulStartingDirection As Integer
	SimulTurnDirBlocked As Integer
End Type
Dim tSimulators(1 To 2) As strSimulatorStruct
Dim nSimulatorNumber As Integer 'Avvierò due simulatori *contemporaneamente*

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

ScreenSet 0, 1
Do
	'Pitta
	With tPlayerPoint
		Locate .Row, .Col
		Color 15: Print "*"; 'Giocatore, in BIANCO 
	End With
	With tComputerPoint
		Locate .Row, .Col
		Color 12: Print Chr(1); 'Computer, in ROSSO 
	End With
	If PCopy(0, 1) Then Screen 11: Print "PCopy error!" : Getkey : Stop
	Sleep 40,1
'	If bMoveNow And bWllFllwMode Then EmptyKeyboardBuffer : GetKey
	'Cancella
	With tPlayerPoint
		Locate .Row, .Col
		Print " "; 'Cancella giocatore 
	End With
	With tComputerPoint
		Locate .Row, .Col
		Print " "; 'Cancella Computer 
	End With

	'--------------------------------------------Movimento giocatore---------------------------------------------------------
	With tPlayerPoint
    	tVectorDir.IncrRow = 0 : tVectorDir.IncrCol = 0
		' Check arrow keys and update the (x, y) position accordingly
		If MultiKey(SC_LEFT ) Then tVectorDir.IncrCol = -1  
		If MultiKey(SC_RIGHT) Then tVectorDir.IncrCol = +1 
		If MultiKey(SC_UP   ) Then tVectorDir.IncrRow = -1
		If MultiKey(SC_DOWN ) Then tVectorDir.IncrRow = +1
		EmptyKeyboardBuffer
		
		tFuturePoint.Row = .Row + tVectorDir.IncrRow
		If Screen(tFuturePoint.Row, .Col) <> WALL Then .Row = tFuturePoint.Row
		tFuturePoint.Col = .Col + tVectorDir.IncrCol
		If Screen(.Row, tFuturePoint.Col) <> WALL Then .Col = tFuturePoint.Col
	End With
	
	'--------------------------------------------Movimento Computer----------------------------------------------------------
If bMoveNow Then
	With tComputerPoint
		If Not bWllFllwMode Then
			With tDistanceLine
				.RowDiff = tPlayerPoint.Row - tComputerPoint.Row
				.RowDiffAbs = Abs(.RowDiff)
				.ColDiff = tPlayerPoint.Col - tComputerPoint.Col
				.ColDiffAbs = Abs(.ColDiff)
				bLineMoreVertical = ( .RowDiffAbs >= .ColDiffAbs )
				tVectorDir.IncrRow = Sgn(.RowDiff)
				tVectorDir.IncrCol = Sgn(.ColDiff)
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
			If tWallVectorDir.IncrRow = 0 Then 'Do priorità alle direzioni verticali!
				tFuturePoint.Col = .Col + tVectorDir.IncrCol				
				If Screen(.Row, tFuturePoint.Col) = WALL Then
					tWallVectorDir.IncrCol = tVectorDir.IncrCol
				Else
					.Col = tFuturePoint.Col
				Endif
			EndIf

			If tWallVectorDir.IncrRow Or tWallVectorDir.IncrCol Then 'C'E' UN MURO!			
				'Ok. In che *direzione* ho il muro?
				For nDirectionIter As Integer = 0 to NUMDIRS
					If tWallVectorDir.IncrRow = aDirections(nDirectionIter).IncrRow And tWallVectorDir.IncrCol = aDirections(nDirectionIter).IncrCol Then 
						nDirectionNumber = nDirectionIter
						Exit For 'EUREKA
					End If
				Next nDirectionIter
				
				'Calcolo distanza fra punto iniziale SUL muro (Computer) e punto finale (Player)
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
					nThresholdCrProd = IIf(bLineMoreVertical, .RowDiffAbs, .ColDiffAbs) Shr 1 'Diviso per due, con Int() incorporato :)
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

				'INIT simulatori
				With tSimulators(1) 'Questo va in senso orario
					.CurrentPosition = tComputerPoint
					.SimulWalkingDirection = (nDirectionNumber + 1) And NUMDIRS 
					.SimulStartingDirection = .SimulWalkingDirection
					.SimulTurnDirBlocked = CLOCKWISE
				End With
				With tSimulators(2) 'Questo va in senso antiorario
					.CurrentPosition = tComputerPoint
					.SimulWalkingDirection = (nDirectionNumber - 1) And NUMDIRS
					.SimulStartingDirection = .SimulWalkingDirection
					.SimulTurnDirBlocked = ANTICLOCKWISE
				End With			
				
				'LANCIO dei simulatori!
				Do
					For nSimulatorNumber = 1 To 2
						With tSimulators(nSimulatorNumber)
							'Controllo se ho muri davanti: se sì, continuo a girare fin quando ho davanti uno spazio libero
							Do							
								tFuturePoint.Row = .CurrentPosition.Row + aDirections(.SimulWalkingDirection).IncrRow
								tFuturePoint.Col = .CurrentPosition.Col + aDirections(.SimulWalkingDirection).IncrCol
								If Screen(tFuturePoint.Row, tFuturePoint.Col) <> WALL Then Exit Do
								.SimulWalkingDirection = (.SimulWalkingDirection + .SimulTurnDirBlocked) And NUMDIRS
							Loop
							
							.CurrentPosition = tFuturePoint
							
							'Sono finito su un punto lungo la linea fra Computer (sul muro) e Player? :D
							tDistancePoint.RowDiff = .CurrentPosition.Row - tOnTheWallPosition.Row
							tDistancePoint.ColDiff = .CurrentPosition.Col - tOnTheWallPosition.Col
							nCrossProduct = (tDistancePoint.ColDiff * tDistanceLine.RowDiff) - (tDistancePoint.RowDiff * tDistanceLine.ColDiff)
							#Ifdef DEBUG
								Locate nSize_H + 1 + nSimulatorNumber, 1: Print "Cross Product[" ; Str(nSimulatorNumber) ; "]:" ; nCrossProduct ; "   ";
							#Endif
							If Abs(nCrossProduct) <= nThresholdCrProd Then 'EUREKA! We're on the line!
								If bLineMoreVertical Then ' La linea fra Computer e Player è più verticale che orizzontale
									If IIf(tDistanceLine.RowDiff > 0, _
									tOnTheWallPosition.Row <= .CurrentPosition.Row And .CurrentPosition.Row <= tPlayerPoint.Row, _
									tPlayerPoint.Row <= .CurrentPosition.Row And .CurrentPosition.Row <= tOnTheWallPosition.Row) Then Exit Do 'Sto pure sul segmento, vince questo simulatore!
								Else 'La linea fra Computer e Player è più orizzontale che verticale
									If IIf(tDistanceLine.ColDiff > 0, _
									tOnTheWallPosition.Col <= .CurrentPosition.Col And .CurrentPosition.Col <= tPlayerPoint.Col, _
									tPlayerPoint.Col <= .CurrentPosition.Col And .CurrentPosition.Col <= tOnTheWallPosition.Col) Then Exit Do 'Sto pure sul segmento, vince questo simulatore!										
								EndIf
							EndIf

							'Mi sono mosso; cerco uno spazio libero girandomi in direzione *opposta* a quella per scansare muri
							.SimulWalkingDirection = (.SimulWalkingDirection - .SimulTurnDirBlocked) And NUMDIRS 'MENO, non PIU', quindi inizio girando in direzione *opposta*					
							While Screen(.CurrentPosition.Row + aDirections(.SimulWalkingDirection).IncrRow, .CurrentPosition.Col + aDirections(.SimulWalkingDirection).IncrCol) = WALL
								'Ho trovato un muro? E allora continuo a girare *normalmente* finché non mi trovo davanti uno spazio libero
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
				
				'Accendo la modalità WallFollow e resetto alla direzione iniziale la WalkingDirection
				bWllFllwMode = True
				bPledgeMode = True ': bTurnCounterIsZero = False
				With tSimulators(nSimulatorNumber)
					.SimulWalkingDirection = .SimulStartingDirection
'					nTurnCount = .SimulTurnDirBlocked 'Il primo giro coincide con la direzione con cui scanso i muri
					'Compensazione per un eventuale muro trovato in diagonale!
					If tWallVectorDir.IncrCol And tVectorDir.IncrRow Then
						Select Case aDirections(.SimulWalkingDirection).IncrRow = tVectorDir.IncrRow
							Case True
								tComputerPoint.Row -= tVectorDir.IncrRow
							Case False
								bMoveNow = False
						End Select
					EndIf
				End With

			End If
		End If
		
		If bWllFllwMode Then
			With tSimulators(nSimulatorNumber)
				'Controllo se ho muri davanti: se sì, continuo a girare fin quando ho davanti uno spazio libero
				Do							
					tFuturePoint.Row = tComputerPoint.Row + aDirections(.SimulWalkingDirection).IncrRow
					tFuturePoint.Col = tComputerPoint.Col + aDirections(.SimulWalkingDirection).IncrCol
					If Screen(tFuturePoint.Row, tFuturePoint.Col) <> WALL Then Exit Do
					.SimulWalkingDirection = (.SimulWalkingDirection + .SimulTurnDirBlocked) And NUMDIRS
'					nTurnCount += .SimulTurnDirBlocked
				Loop
				
				tComputerPoint = tFuturePoint
				If (tWallVectorDir.IncrRow And tComputerPoint.Row = tOnTheWallPosition.Row) Or _
					(tWallVectorDir.IncrCol And tComputerPoint.Col = tOnTheWallPosition.Col) Then bPledgeMode = False
				
				tWllFllwSimulDistance.RowDiff = Abs(tPlayerPoint.Row - .CurrentPosition.Row)
				tWllFllwSimulDistance.ColDiff = Abs(tPlayerPoint.Col - .CurrentPosition.Col)
				tWllFllwPlayerDistance.RowDiff = Abs(tPlayerPoint.Row - tComputerPoint.Row)
				tWllFllwPlayerDistance.ColDiff = Abs(tPlayerPoint.Col - tComputerPoint.Col)
				If IIf(bPledgeMode, _
				tWllFllwPlayerDistance.RowDiff <= tWllFllwSimulDistance.RowDiff And tWllFllwPlayerDistance.ColDiff <= tWllFllwSimulDistance.ColDiff, _
				(tWllFllwPlayerDistance.RowDiff + tWllFllwPlayerDistance.ColDiff) <= (tWllFllwSimulDistance.RowDiff + tWllFllwSimulDistance.ColDiff)) Then
'				If (tWllFllwPlayerDistance.RowDiff + tWllFllwPlayerDistance.ColDiff) <= (tWllFllwSimulDistance.RowDiff + tWllFllwSimulDistance.ColDiff) Then
'				If tWllFllwPlayerDistance.RowDiff <= tWllFllwSimulDistance.RowDiff And tWllFllwPlayerDistance.ColDiff <= tWllFllwSimulDistance.ColDiff Then
					bWllFllwMode = False 'Anticipo i tempi di uscita!
				Else
					'Provo a girare in direzione *opposta* a dove giro normalmente per scansare gli eventuali muri davanti
					.SimulWalkingDirection = (.SimulWalkingDirection - .SimulTurnDirBlocked) And NUMDIRS 'MENO, non PIU', quindi inizio girando in direzione *opposta*
'					nTurnCount -= .SimulTurnDirBlocked
					While Screen(tComputerPoint.Row + aDirections(.SimulWalkingDirection).IncrRow, tComputerPoint.Col + aDirections(.SimulWalkingDirection).IncrCol) = WALL
						'Ho trovato un muro? E allora continuo a girare *normalmente* finché non mi trovo davanti uno spazio libero
						.SimulWalkingDirection = (.SimulWalkingDirection + .SimulTurnDirBlocked) And NUMDIRS
'						nTurnCount += .SimulTurnDirBlocked
					Wend
'					If nTurnCount = 0 Then
'						bTurnCounterIsZero = True
'					ElseIf bTurnCounterIsZero Then
'						bPledgeMode = False
'					EndIf
				EndIf

				#Ifdef DEBUG
					If bWllFllwMode Then
						Locate .CurrentPosition.Row, .CurrentPosition.Col: Print Str(nSimulatorNumber);
'						Locate nSize_H + 1, 1: Print "TurnCount:" ; nTurnCount; " (" ; bPledgeMode ; ") - bTurnCounterIsZero (" ; bTurnCounterIsZero; ")    ";
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
Loop Until Multikey(SC_ESCAPE)
EmptyKeyboardBuffer

#Ifdef DEBUG
	View Print nSize_H + 1 To nSize_H + INFOLINES : Cls: View Print
	If nSimulatorNumber > 0 Then 					
		With tSimulators(nSimulatorNumber).CurrentPosition
			Locate .Row, .Col: Print " ";
		End With
	EndIf
#Endif

ScreenSet
End Sub ' Sub Chase_Main() -------------------------------------------------------------------------------------------------------------
