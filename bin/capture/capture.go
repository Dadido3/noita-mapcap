// Copyright (c) 2019-2020 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import "C"

import (
	"fmt"
	"image"
	"image/png"
	"os"

	"github.com/kbinani/screenshot"
)

type encodeElement struct {
	x, y int
	img  *image.RGBA
}

var encodeQueue = make(chan encodeElement)

var bounds = screenshot.GetDisplayBounds(0) // Only care about the main screen

func init() {
	// Start encode workers
	startWorkers()
}

func main() {
	/*flagX := flag.Int("x", 0, "x coordinate")
	flagY := flag.Int("y", 0, "y coordinate")

	flag.Parse()

	Capture(*flagX, *flagY)

	//startServer()*/

	/*for i := 0; i < 5000; i++ {
		Capture(i, 0)
	}*/
}

func startWorkers() {
	for i := 0; i < 8; i++ {
		go func() {
			encoder := png.Encoder{CompressionLevel: png.BestSpeed}

			for elem := range encodeQueue {
				fileName := fmt.Sprintf("mods/noita-mapcap/output/%d,%d.png", elem.x, elem.y)
				//fileName := fmt.Sprintf("%d,%d.png", x, y)
				file, err := os.Create(fileName)
				if err != nil {
					continue
				}

				encoder.Encode(file, elem.img)

				file.Close()
			}
		}()
	}
}

//Capture creates a snapshot of the whole main screen, and stores it inside the mod's output folder.
//export Capture
func Capture(x, y int) {

	img, err := screenshot.CaptureRect(bounds)
	if err != nil {
		panic(err)
		//return
	}

	//img := image.NewRGBA(image.Rect(0, 0, 1920, 1080))

	encodeQueue <- encodeElement{
		img: img,
		x:   x,
		y:   y,
	}
}
