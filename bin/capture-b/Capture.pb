; Copyright (c) 2019-2022 David Vogel
;
; This software is released under the MIT License.
; https://opensource.org/licenses/MIT

UsePNGImageEncoder()

Declare Worker(*Dummy)

Structure QueueElement
	img.i
	x.i
	y.i
	sx.i
	sy.i
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

	For i = 1 To 6
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
		sx = Queue()\sx
		sy = Queue()\sy
		DeleteElement(Queue())
		UnlockMutex(Mutex)
		
		If sx > 0 And sy > 0
		  ResizeImage(img, sx, sy)
		EndIf

		SaveImage(img, "mods/noita-mapcap/output/" + x + "," + y + ".png", #PB_ImagePlugin_PNG)
		;SaveImage(img, "" + x + "," + y + ".png", #PB_ImagePlugin_PNG) ; Test

		FreeImage(img)
	ForEver
EndProcedure

; Takes a screenshot of the client area of this process' active window.
; The portion of the client area that is captured is described by capRect, which is in window coordinates and relative to the client area.
; x and y defines the top left position of the captured rectangle in scaled world coordinates. The scale depends on the window to world pixel ratio.
; sx and sy defines the final dimensions that the screenshot will be resized to. No resize will happen if set to 0.
ProcedureDLL Capture(*capRect.RECT, x.l, y.l, sx.l, sy.l)
	Protected hWnd.l = GetProcHwnd()
	If Not hWnd
		ProcedureReturn #False
	EndIf

	Protected rect.RECT
	If Not GetRect(@rect)
		ProcedureReturn #False
	EndIf
	
	; Limit the desired capture area to the actual client area of the window.
	If *capRect\left < 0 : *capRect\left = 0 : EndIf
	If *capRect\right > rect\right-rect\left : *capRect\right = rect\right-rect\left : EndIf
	If *capRect\top < 0 : *capRect\top = 0 : EndIf
	If *capRect\bottom > rect\bottom-rect\top : *capRect\bottom = rect\bottom-rect\top : EndIf

	imageID = CreateImage(#PB_Any, *capRect\right-*capRect\left, *capRect\bottom-*capRect\top)
	If Not imageID
		ProcedureReturn #False
	EndIf

	; Get DC of window.
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
	If Not BitBlt_(hDC, 0, 0, *capRect\right-*capRect\left, *capRect\bottom-*capRect\top, windowDC, *capRect\left, *capRect\top, #SRCCOPY) ; After some time BitBlt will fail, no idea why. Also, that's moments before noita crashes.
		StopDrawing()
		ReleaseDC_(hWnd, windowDC)
		FreeImage(imageID)
		ProcedureReturn #False
	EndIf
	StopDrawing()

	ReleaseDC_(hWnd, windowDC)

	LockMutex(Mutex)
	; Check if the queue has too many elements, if so, wait. (Emulate go's channels)
	While ListSize(Queue()) > 1
		UnlockMutex(Mutex)
		Delay(1)
		LockMutex(Mutex)
	Wend
	LastElement(Queue())
	AddElement(Queue())
	Queue()\img = imageID
	Queue()\x = x
	Queue()\y = y
	Queue()\sx = sx
	Queue()\sy = sy
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

; IDE Options = PureBasic 6.00 LTS (Windows - x64)
; ExecutableFormat = Shared dll
; CursorPosition = 94
; FirstLine = 39
; Folding = --
; Optimizer
; EnableThread
; EnableXP
; Executable = capture.dll
; Compiler = PureBasic 6.00 LTS (Windows - x86)