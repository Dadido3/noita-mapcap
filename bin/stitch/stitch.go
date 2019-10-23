// Copyright (c) 2019 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	"image"
	"image/png"
	"log"
	"os"
	"path/filepath"
)

var inputPath = filepath.Join(".", "..", "..", "output")

func main() {
	tiles, err := loadImages(inputPath)
	if err != nil {
		log.Panic(err)
	}

	/*f, err := os.Create("cpu.prof")
	if err != nil {
		log.Panicf("could not create CPU profile: %v", err)
	}
	defer f.Close()
	if err := pprof.StartCPUProfile(f); err != nil {
		log.Panicf("could not start CPU profile: %v", err)
	}
	defer pprof.StopCPUProfile()*/

	outputImage := image.NewRGBA(image.Rect(-4000, -4000, 8000, 8000))

	tp := make(tilePairs)
	if err := tp.stitch(tiles, outputImage); err != nil {
		log.Panic(err)
	}

	f, err := os.Create("output.png")
	if err != nil {
		log.Panic(err)
	}

	if err := png.Encode(f, outputImage); err != nil {
		f.Close()
		log.Panic(err)
	}

	if err := f.Close(); err != nil {
		log.Panic(err)
	}
}
