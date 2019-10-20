; Copyright (c) 2019 David Vogel
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

ProcedureDLL AttachProcess(Instance)
	Global Semaphore = CreateSemaphore()
	Global Mutex = CreateMutex()
	Global NewList Queue.QueueElement()

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
		FreeImage(img)
	ForEver
EndProcedure

ProcedureDLL Capture(px.i, py.i)
	; Get dimensions of main screen

	ExamineDesktops()

	x = DesktopX(0)
	y = DesktopY(0)
	w = DesktopWidth(0)
	h = DesktopHeight(0)

	imageID = CreateImage(#PB_Any, w, h)
	If Not imageID
		ProcedureReturn
	EndIf

	; Get DC of whole screen
	screenDC = GetDC_(#Null)

	hDC = StartDrawing(ImageOutput(imageID))
	If Not hDC
		ReleaseDC_(#Null, screenDC)
		FreeImage(imageID)
		ProcedureReturn
	EndIf
	BitBlt_(hDC, 0, 0, w, h, screenDC, x, y, #SRCCOPY)
	StopDrawing()

	ReleaseDC_(#Null, screenDC)

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

EndProcedure

; IDE Options = PureBasic 5.71 LTS (Windows - x64)
; ExecutableFormat = Shared dll
; CursorPosition = 15
; Folding = -
; EnableThread
; EnableXP
; Executable = capture.dll
; DisableDebugger
; Compiler = PureBasic 5.71 LTS (Windows - x86)