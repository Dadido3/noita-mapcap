// Copyright (c) 2022-2024 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	"image"
	"image/color"
	"image/draw"
	"runtime"
	"sync"
)

// StitchedImageCache contains part of the actual image data of a stitched image.
// This can be regenerated or invalidated at will.
type StitchedImageCache struct {
	sync.Mutex

	stitchedImage *StitchedImage // The parent object.

	rect  image.Rectangle // Position and size of the cached area.
	image *image.RGBA     // Cached RGBA image. The bounds of this image are determined by the filename.

	idleCounter byte // Is incremented when this cache object idles, and reset every time the cache is used.
}

func NewStitchedImageCache(stitchedImage *StitchedImage, rect image.Rectangle) StitchedImageCache {
	return StitchedImageCache{
		stitchedImage: stitchedImage,
		rect:          rect,
	}
}

// InvalidateAuto invalidates this cache object when it had idled for too long.
// The cache will be invalidated after `threshold + 1` calls to InvalidateAuto.
func (sic *StitchedImageCache) InvalidateAuto(threshold byte) {
	sic.Lock()
	defer sic.Unlock()

	if sic.image != nil {
		if sic.idleCounter >= threshold {
			sic.image = nil
			return
		}
		sic.idleCounter++
	}
}

// Invalidate clears the cached image.
func (sic *StitchedImageCache) Invalidate() {
	sic.Lock()
	defer sic.Unlock()
	sic.image = nil
}

// Regenerate refills the cache image with valid image data.
// This will block until there is a valid image, and it will *always* return a valid image.
func (sic *StitchedImageCache) Regenerate() *image.RGBA {
	sic.Lock()
	defer sic.Unlock()

	sic.idleCounter = 0

	// Check if there is already a cache image.
	if sic.image != nil {
		return sic.image
	}

	si := sic.stitchedImage

	// Create new image with default background color.
	cacheImage := image.NewRGBA(sic.rect)
	draw.Draw(cacheImage, cacheImage.Bounds(), &image.Uniform{colorBackground}, cacheImage.Bounds().Min, draw.Src)

	// List of tiles that intersect with the to be generated cache image.
	intersectingTiles := []*ImageTile{}
	for i := range si.tiles {
		tile := &si.tiles[i]
		if tile.Bounds().Overlaps(sic.rect) {
			intersectingTiles = append(intersectingTiles, tile)
		}
	}

	// Start worker threads.
	workerQueue := make(chan image.Rectangle)
	waitGroup := sync.WaitGroup{}
	workers := (runtime.NumCPU() + 1) / 2
	for i := 0; i < workers; i++ {
		waitGroup.Add(1)
		go func() {
			defer waitGroup.Done()
			for workload := range workerQueue {
				// List of tiles that intersect with the workload chunk.
				workloadTiles := []*ImageTile{}

				// Get only the tiles that intersect with the workload bounds.
				for _, tile := range intersectingTiles {
					if tile.Bounds().Overlaps(workload) {
						workloadTiles = append(workloadTiles, tile)
					}
				}

				// Draw blended tiles into cache image.
				// Restricted by the workload rectangle.
				si.blendMethod.Draw(workloadTiles, cacheImage.SubImage(workload).(*image.RGBA))
			}
		}()
	}

	// Divide rect into chunks and push to workers.
	for _, chunk := range GridifyRectangle(sic.rect, StitchedImageCacheGridSize) {
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
	sic.image = cacheImage
	return cacheImage
}

// Returns the pixel color at x and y.
func (sic *StitchedImageCache) RGBAAt(x, y int) color.RGBA {
	// Fast path: The image is loaded.
	sic.Lock()
	if sic.image != nil {
		defer sic.Unlock()
		sic.idleCounter = 0
		return sic.image.RGBAAt(x, y)
	}
	sic.Unlock()

	// Slow path: The image data needs to be generated first.
	// This will block until the cache is regenerated.
	return sic.Regenerate().RGBAAt(x, y)
}

// Returns the pixel color at x and y.
func (sic *StitchedImageCache) At(x, y int) color.Color {
	return sic.RGBAAt(x, y)
}

func (sic *StitchedImageCache) Bounds() image.Rectangle {
	return sic.rect
}
