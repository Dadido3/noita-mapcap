// Copyright (c) 2022-2023 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	"fmt"
	"image"
	"image/color"
	"sync/atomic"
	"time"
)

// StitchedImageCacheGridSize defines the worker chunk size when the cache image is regenerated.
var StitchedImageCacheGridSize = 256

// StitchedImageBlendMethod defines how tiles are blended together.
type StitchedImageBlendMethod interface {
	Draw(tiles []*ImageTile, destImage *image.RGBA) // Draw is called when a new cache image is generated.
}

// StitchedImageOverlay defines an interface for arbitrary overlays that can be drawn over the stitched image.
type StitchedImageOverlay interface {
	Draw(*image.RGBA)
}

// StitchedImage combines several ImageTile objects into a single RGBA image.
// The way the images are combined/blended is defined by the blendFunc.
type StitchedImage struct {
	tiles       ImageTiles
	bounds      image.Rectangle
	blendMethod StitchedImageBlendMethod
	overlays    []StitchedImageOverlay

	cacheRowHeight  int
	cacheRows       []StitchedImageCache
	cacheRowYOffset int // Defines the pixel offset of the first cache row.

	oldCacheRowIndex int
	queryCounter     atomic.Int64
}

// NewStitchedImage creates a new image from several single image tiles.
func NewStitchedImage(tiles ImageTiles, bounds image.Rectangle, blendMethod StitchedImageBlendMethod, cacheRowHeight int, overlays []StitchedImageOverlay) (*StitchedImage, error) {
	if bounds.Empty() {
		return nil, fmt.Errorf("given boundaries are empty")
	}
	if blendMethod == nil {
		return nil, fmt.Errorf("no blending method given")
	}
	if cacheRowHeight <= 0 {
		return nil, fmt.Errorf("invalid cache row height of %d pixels", cacheRowHeight)
	}

	stitchedImage := &StitchedImage{
		tiles:       tiles,
		bounds:      bounds,
		blendMethod: blendMethod,
		overlays:    overlays,
	}

	// Generate cache image rows.
	rows := bounds.Dy() / cacheRowHeight
	var cacheRows []StitchedImageCache
	for i := 0; i < rows; i++ {
		rect := image.Rect(bounds.Min.X, bounds.Min.Y+i*cacheRowHeight, bounds.Max.X, bounds.Min.Y+(i+1)*cacheRowHeight)
		cacheRows = append(cacheRows, NewStitchedImageCache(stitchedImage, rect.Intersect(bounds)))
	}
	stitchedImage.cacheRowHeight = cacheRowHeight
	stitchedImage.cacheRowYOffset = -bounds.Min.Y
	stitchedImage.cacheRows = cacheRows

	// Start ticker to automatically invalidate caches.
	// Due to this, the stitchedImage object is not composable, as this goroutine will always have a reference.
	go func() {
		ticker := time.NewTicker(1 * time.Second)
		for range ticker.C {
			for rowIndex := range stitchedImage.cacheRows {
				stitchedImage.cacheRows[rowIndex].InvalidateAuto(3) // Invalidate cache row after 3 seconds of being idle.
			}
		}
	}()

	return stitchedImage, nil
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

func (si *StitchedImage) At(x, y int) color.Color {
	return si.RGBAAt(x, y)
}

// At returns the color of the pixel at (x, y).
//
// This is optimized to be read line by line (scanning), it will be much slower with random access.
//
// For the `Progress()` method to work correctly, every pixel should be queried exactly once.
//
//	At(Bounds().Min.X, Bounds().Min.Y) // returns the top-left pixel of the image.
//	At(Bounds().Max.X-1, Bounds().Max.Y-1) // returns the bottom-right pixel.
func (si *StitchedImage) RGBAAt(x, y int) color.RGBA {
	// Assume that every pixel is only queried once.
	si.queryCounter.Add(1)

	// Determine the cache rowIndex index.
	rowIndex := (y + si.cacheRowYOffset) / si.cacheRowHeight
	if rowIndex < 0 || rowIndex >= len(si.cacheRows) {
		return color.RGBA{}
	}

	// Check if we advanced/changed the row index.
	// This doesn't happen a lot, so stuff inside this can be a bit more expensive.
	if si.oldCacheRowIndex != rowIndex {
		// Pre generate the new row asynchronously.
		newRowIndex := rowIndex + 1
		if newRowIndex >= 0 && newRowIndex < len(si.cacheRows) {
			go si.cacheRows[newRowIndex].Regenerate()
		}

		// Invalidate old cache row.
		oldRowIndex := si.oldCacheRowIndex
		if oldRowIndex >= 0 && oldRowIndex < len(si.cacheRows) {
			si.cacheRows[oldRowIndex].Invalidate()
		}

		// Invalidate all tiles that are above the next row.
		si.tiles.InvalidateAboveY((rowIndex+1)*si.cacheRowHeight - si.cacheRowYOffset)

		si.oldCacheRowIndex = rowIndex
	}

	return si.cacheRows[rowIndex].RGBAAt(x, y)
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

	return int(si.queryCounter.Load()), size.X * size.Y
}
