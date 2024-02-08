; Copyright (c) 2019-2024 David Vogel
;
; This software is released under the MIT License.
; https://opensource.org/licenses/MIT

EnableExplicit

UsePNGImageEncoder()

Declare Worker(*Dummy)

Structure QueueElement
	img.i
	x.i
	y.i
	sx.i
	sy.i
EndStructure

Structure GLViewportDims
	x.i
	y.i
	width.i
	height.i
EndStructure

Structure WorkerInfo
	workerNumber.i
EndStructure

#Workers = 8

; Returns the size of the main OpenGL rendering output.
ProcedureDLL GetGLViewportSize(*dims.GLViewportDims)
	If Not *dims
		ProcedureReturn #False
	EndIf

	glGetIntegerv_(#GL_VIEWPORT, *dims)

	ProcedureReturn #True
EndProcedure

; Returns the size of the main OpenGL rendering output as a windows RECT.
ProcedureDLL GetRect(*rect.RECT)
	If Not *rect
		ProcedureReturn #False
	EndIf

	Protected dims.GLViewportDims
	glGetIntegerv_(#GL_VIEWPORT, dims)

	*rect\left = dims\x
	*rect\top = dims\y
	*rect\right = dims\x + dims\width
	*rect\bottom = dims\y + dims\height

	ProcedureReturn #True
EndProcedure

ProcedureDLL AttachProcess(Instance)
	Global Semaphore = CreateSemaphore()
	Global Mutex = CreateMutex()
	Global NewList Queue.QueueElement()

	CreateDirectory("mods/noita-mapcap/output/")

	Static Dim WorkerInfos.WorkerInfo(#Workers-1)
	Protected i
	For i = 0 To #Workers-1
		WorkerInfos(i)\workerNumber = i
		CreateThread(@Worker(), @WorkerInfos(i))
	Next
EndProcedure

Procedure Worker(*workerInfo.WorkerInfo)
	Protected img, x, y, sx, sy

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

		; Save image temporary, and only move it once it's fully exported.
		; This prevents images getting corrupted when the main process crashes.
		If SaveImage(img, "mods/noita-mapcap/output/worker_" + *workerInfo\workerNumber + ".tmp", #PB_ImagePlugin_PNG)
			RenameFile("mods/noita-mapcap/output/worker_" + *workerInfo\workerNumber + ".tmp", "mods/noita-mapcap/output/" + x + "," + y + ".png")
			; We can't really do anything when either SaveImage or RenameFile fails, so just silently fail.
		EndIf

		FreeImage(img)
	ForEver
EndProcedure

; Takes a screenshot of the client area of this process' active window.
; The portion of the client area that is captured is described by capRect, which is in viewport coordinates.
; x and y defines the top left position of the captured rectangle in scaled world coordinates. The scale depends on the window to world pixel ratio.
; sx and sy defines the final dimensions that the screenshot will be resized to. No resize will happen if set to 0.
ProcedureDLL Capture(*capRect.RECT, x.l, y.l, sx.l, sy.l)
	Protected viewportRect.RECT
	If Not GetRect(@viewportRect)
		ProcedureReturn #False
	EndIf

	Protected imageID, hDC, *pixelBuffer

	; Limit the desired capture area to the actual client area of the viewport.
	If *capRect\left < 0 : *capRect\left = 0 : EndIf
	If *capRect\top < 0 : *capRect\top = 0 : EndIf
	If *capRect\right < *capRect\left : *capRect\right = *capRect\left : EndIf
	If *capRect\bottom < *capRect\top : *capRect\bottom = *capRect\top : EndIf
	If *capRect\right > viewportRect\right : *capRect\right = viewportRect\right : EndIf
	If *capRect\bottom > viewportRect\bottom : *capRect\bottom = viewportRect\bottom : EndIf

	Protected capWidth = *capRect\right - *capRect\left
	Protected capHeight = *capRect\bottom - *capRect\top

	imageID = CreateImage(#PB_Any, capWidth, capHeight)
	If Not imageID
		ProcedureReturn #False
	EndIf

	;Protected *pixelBuf = AllocateMemory(3 * width * height)

	hDC = StartDrawing(ImageOutput(imageID))
	If Not hDC
		FreeImage(imageID)
		ProcedureReturn #False
	EndIf

	*pixelBuffer = DrawingBuffer()
	glReadPixels_(*capRect\left, *capRect\top, capWidth, capHeight, #GL_BGR_EXT, #GL_UNSIGNED_BYTE, *pixelBuffer)

;	For y = 0 To *capRect\height - 1
;		*Line.Pixel = Buffer + Pitch * y
;
;		For x = 0 To *capRect\width - 1
;
;			*Line\Pixel = ColorTable(pos2) ; Write the pixel directly to the memory !
;			*Line+Offset
;
;			; You can try with regular plot to see the speed difference
;			; Plot(x, y, ColorTable(pos2))
;		Next
;	Next

	StopDrawing()

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

; IDE Options = PureBasic 6.04 LTS (Windows - x64)
; ExecutableFormat = Shared dll
; CursorPosition = 116
; FirstLine = 99
; Folding = -
; Optimizer
; EnableThread
; EnableXP
; Executable = capture.dll
; DisableDebugger
; Compiler = PureBasic 6.04 LTS - C Backend (Windows - x86)