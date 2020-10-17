; Copyright (c) 2019-2020 David Vogel
;
; This software is released under the MIT License.
; https://opensource.org/licenses/MIT

UsePNGImageEncoder()

Declare Worker(*Dummy)

Structure QueueElement
	img.i
	x.i
	y.i
EndStructure

; Source: https://www.purebasic.fr/english/viewtopic.php?f=13&t=29981&start=15
Procedure EnumWindowsProc(hWnd.l, *lParam.Long)
	Protected lpProc.l
	GetWindowThreadProcessId_(hWnd, @lpProc)
	If *lParam\l = lpProc ; Check if current window's processID matches
		*lParam\l = hWnd ; Replace processID in the param With the hwnd As result
		ProcedureReturn #False ; Return false to stop iterating
	EndIf
	ProcedureReturn #True
EndProcedure

; Source: https://www.purebasic.fr/english/viewtopic.php?f=13&t=29981&start=15
; Returns the first window associated with the given process handle
Procedure GetProcHwnd()
	Protected pID.l = GetCurrentProcessId_()
	Protected tempParam.l = pID
	EnumWindows_(@EnumWindowsProc(), @tempParam)
	If tempParam = pID ; Check if anything was found
		ProcedureReturn #Null
	EndIf
	ProcedureReturn tempParam ; This is a valid hWnd at this point
EndProcedure

; Get the client rectangle of the "Main" window of this process in screen coordinates
ProcedureDLL GetRect(*rect.RECT)
	Protected hWnd.l = GetProcHwnd()
	If Not hWnd
		ProcedureReturn #False
	EndIf
	If Not *rect
		ProcedureReturn #False
	EndIf

	GetClientRect_(hWnd, *rect)

	; A RECT consists basically of two POINT structures
	ClientToScreen_(hWnd, @*rect\left)
	ClientToScreen_(hWnd, @*rect\Right)

	ProcedureReturn #True
EndProcedure

ProcedureDLL AttachProcess(Instance)
	Global Semaphore = CreateSemaphore()
	Global Mutex = CreateMutex()
	Global NewList Queue.QueueElement()

	CreateDirectory("mods/noita-mapcap/output/")

	For i = 1 To 4
		CreateThread(@Worker(), #Null)
	Next
EndProcedure

Procedure Worker(*Dummy)
	Protected img, x, y

	Repeat
		WaitSemaphore(Semaphore)

		LockMutex(Mutex)
		FirstElement(Queue())
		img = Queue()\img
		x = Queue()\x
		y = Queue()\y
		DeleteElement(Queue())
		UnlockMutex(Mutex)

		SaveImage(img, "mods/noita-mapcap/output/" + x + "," + y + ".png", #PB_ImagePlugin_PNG)
		;SaveImage(img, "" + x + "," + y + ".png", #PB_ImagePlugin_PNG) ; Test

		FreeImage(img)
	ForEver
EndProcedure

ProcedureDLL Capture(px.i, py.i)
	Protected hWnd.l = GetProcHwnd()
	If Not hWnd
		ProcedureReturn #False
	EndIf

	Protected rect.RECT
	If Not GetRect(@rect)
		ProcedureReturn #False
	EndIf

	imageID = CreateImage(#PB_Any, rect\right-rect\left, rect\bottom-rect\top)
	If Not imageID
		ProcedureReturn #False
	EndIf

	; Get DC of whole screen
	windowDC = GetDC_(hWnd)
	If Not windowDC
		FreeImage(imageID)
		ProcedureReturn #False
	EndIf

	hDC = StartDrawing(ImageOutput(imageID))
	If Not hDC
		ReleaseDC_(hWnd, windowDC)
		FreeImage(imageID)
		ProcedureReturn #False
	EndIf
	If Not BitBlt_(hDC, 0, 0, rect\right-rect\left, rect\bottom-rect\top, windowDC, 0, 0, #SRCCOPY) ; After some time BitBlt will fail, no idea why. Also, that's moments before noita crashes.
		StopDrawing()
		ReleaseDC_(hWnd, windowDC)
		FreeImage(imageID)
		ProcedureReturn #False
	EndIf
	StopDrawing()

	ReleaseDC_(hWnd, windowDC)

	LockMutex(Mutex)
	; Check if the queue has too many elements, if so, wait. (Simulate go's channels)
	While ListSize(Queue()) > 0
		UnlockMutex(Mutex)
		Delay(10)
		LockMutex(Mutex)
	Wend
	LastElement(Queue())
	AddElement(Queue())
	Queue()\img = imageID
	Queue()\x = px
	Queue()\y = py
	UnlockMutex(Mutex)

	SignalSemaphore(Semaphore)

	ProcedureReturn #True
EndProcedure

; #### Test
;AttachProcess(0)
;OpenWindow(0, 100, 200, 195, 260, "PureBasic Window", #PB_Window_SystemMenu | #PB_Window_MinimizeGadget | #PB_Window_MaximizeGadget)
;Delay(1000)
;Capture(123, 123)
;Delay(1000)

; IDE Options = PureBasic 5.72 (Windows - x64)
; ExecutableFormat = Shared dll
; CursorPosition = 90
; FirstLine = 77
; Folding = --
; EnableThread
; EnableXP
; Executable = capture.dll
; Compiler = PureBasic 5.71 LTS (Windows - x86)