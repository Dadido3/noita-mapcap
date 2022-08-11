// Copyright (c) 2022 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	"fmt"
	"image"
	"image/color"
	"runtime"
	"sync"
)

// StitchedImageCacheGridSize defines the worker chunk size when the cache image is regenerated.
// TODO: Find optimal grid size that works good for tiles with lots and few overlap
var StitchedImageCacheGridSize = 512

// StitchedImageBlendMethod defines how tiles are blended together.
type StitchedImageBlendMethod interface {
	Draw(tiles []*ImageTile, destImage *image.RGBA) // Draw is called when a new cache image is generated.
}

type StitchedImageOverlay interface {
	Draw(*image.RGBA)
}

// StitchedImage combines several ImageTile objects into a single RGBA image.
// The way the images are combined/blended is defined by the blendFunc.
type StitchedImage struct {
	tiles       []ImageTile
	bounds      image.Rectangle
	blendMethod StitchedImageBlendMethod
	overlays    []StitchedImageOverlay

	cacheHeight int
	cacheImage  *image.RGBA

	queryCounter int
}

// NewStitchedImage creates a new image from several single image tiles.
func NewStitchedImage(tiles []ImageTile, bounds image.Rectangle, blendMethod StitchedImageBlendMethod, cacheHeight int, overlays []StitchedImageOverlay) (*StitchedImage, error) {
	if bounds.Empty() {
		return nil, fmt.Errorf("given boundaries are empty")
	}
	if blendMethod == nil {
		return nil, fmt.Errorf("no blending method given")
	}
	if cacheHeight <= 0 {
		return nil, fmt.Errorf("invalid cache height of %d pixels", cacheHeight)
	}

	return &StitchedImage{
		tiles:       tiles,
		bounds:      bounds,
		blendMethod: blendMethod,
		overlays:    overlays,
		cacheHeight: cacheHeight,
		cacheImage:  &image.RGBA{},
	}, nil
}

// ColorModel returns the Image's color model.
func (si *StitchedImage) ColorModel() color.Model {
	return color.RGBAModel
}

// Bounds returns the domain for which At can return non-zero color.
// The bounds do not necessarily contain the point (0, 0).
func (si *StitchedImage) Bounds() image.Rectangle {
	return si.bounds
}

// At returns the color of the pixel at (x, y).
//
// This is optimized to be read line by line (scanning), it will be much slower with random access.
//
// For the `Progress()` method to work correctly, every pixel should be queried exactly once.
//
//	At(Bounds().Min.X, Bounds().Min.Y) // returns the top-left pixel of the image.
//	At(Bounds().Max.X-1, Bounds().Max.Y-1) // returns the bottom-right pixel.
//
// This is not thread safe, don't call from several goroutines!
func (si *StitchedImage) At(x, y int) color.Color {
	p := image.Point{x, y}

	// Assume that every pixel is only queried once.
	si.queryCounter++

	// Check if cached image needs to be regenerated.
	if !p.In(si.cacheImage.Bounds()) {
		rect := si.Bounds()
		// TODO: Redo how the cache image rect is generated
		rect.Min.Y = divideFloor(y, si.cacheHeight) * si.cacheHeight
		rect.Max.Y = rect.Min.Y + si.cacheHeight

		si.regenerateCache(rect)
	}

	return si.cacheImage.RGBAAt(x, y)
}

// Opaque returns whether the image is fully opaque.
//
// For more speed and smaller file size, StitchedImage will be marked as non-transparent.
// This will speed up image saving by 2x, as there is no need to iterate over the whole image to find a single non opaque pixel.
func (si *StitchedImage) Opaque() bool {
	return true
}

// Progress returns the approximate progress of any process that scans the image from top to bottom.
func (si *StitchedImage) Progress() (value, max int) {
	size := si.Bounds().Size()

	return si.queryCounter, size.X * size.Y
}

// regenerateCache will regenerate the cache image at the given rectangle.
func (si *StitchedImage) regenerateCache(rect image.Rectangle) {
	cacheImage := image.NewRGBA(rect)

	// List of tiles that intersect with the to be generated cache image.
	intersectingTiles := []*ImageTile{}
	for i, tile := range si.tiles {
		if tile.Bounds().Overlaps(rect) {
			tilePtr := &si.tiles[i]
			intersectingTiles = append(intersectingTiles, tilePtr)
		}
	}

	// Start worker threads.
	workerQueue := make(chan image.Rectangle)
	waitGroup := sync.WaitGroup{}
	for i := 0; i < runtime.NumCPU(); i++ {
		waitGroup.Add(1)
		go func() {
			defer waitGroup.Done()
			for workload := range workerQueue {
				// List of tiles that intersect with the workload chunk.
				workloadTiles := []*ImageTile{}

				// Get only the tiles that intersect with the destination image bounds.
				for _, tile := range intersectingTiles {
					if tile.Bounds().Overlaps(workload) {
						workloadTiles = append(workloadTiles, tile)
					}
				}

				// Blend tiles into image at the workload rectangle.
				si.blendMethod.Draw(workloadTiles, cacheImage.SubImage(workload).(*image.RGBA))
			}
		}()
	}

	// Divide rect into chunks and push to workers.
	for _, chunk := range gridifyRectangle(rect, StitchedImageCacheGridSize) {
		workerQueue <- chunk
	}
	close(workerQueue)

	// Wait until all worker threads are done.
	waitGroup.Wait()

	// Draw overlays.
	for _, overlay := range si.overlays {
		if overlay != nil {
			overlay.Draw(cacheImage)
		}
	}

	// Update cached image.
	si.cacheImage = cacheImage
}
