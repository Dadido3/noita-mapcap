// Copyright (c) 2019-2020 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	"image"
	"image/color"
)

// MedianBlendedImageRowHeight defines the height of the cached output image.
const MedianBlendedImageRowHeight = 256

// MedianBlendedImage combines several imageTile to a single RGBA image.
type MedianBlendedImage struct {
	tiles  []imageTile
	bounds image.Rectangle

	cachedRow    *image.RGBA
	queryCounter int
}

// NewMedianBlendedImage creates a new image from several single image tiles.
func NewMedianBlendedImage(tiles []imageTile, bounds image.Rectangle) *MedianBlendedImage {
	return &MedianBlendedImage{
		tiles:     tiles,
		bounds:    bounds,
		cachedRow: &image.RGBA{},
	}
}

// ColorModel returns the Image's color model.
func (mbi *MedianBlendedImage) ColorModel() color.Model {
	return color.RGBAModel
}

// Bounds returns the domain for which At can return non-zero color.
// The bounds do not necessarily contain the point (0, 0).
func (mbi *MedianBlendedImage) Bounds() image.Rectangle {
	return mbi.bounds
}

// At returns the color of the pixel at (x, y).
// At(Bounds().Min.X, Bounds().Min.Y) returns the upper-left pixel of the grid.
// At(Bounds().Max.X-1, Bounds().Max.Y-1) returns the lower-right one.
func (mbi *MedianBlendedImage) At(x, y int) color.Color {
	p := image.Point{x, y}

	// Assume that every pixel is only queried once
	mbi.queryCounter++

	if !p.In(mbi.cachedRow.Bounds()) {
		// Need to create a new row image
		rect := mbi.Bounds()
		rect.Min.Y = divideFloor(y, MedianBlendedImageRowHeight) * MedianBlendedImageRowHeight
		rect.Max.Y = rect.Min.Y + MedianBlendedImageRowHeight

		if !p.In(rect) {
			return color.RGBA{}
		}

		mbi.cachedRow = image.NewRGBA(rect)

		// TODO: Don't use hilbert curve here
		if err := StitchGrid(mbi.tiles, mbi.cachedRow, 512, nil); err != nil {
			return color.RGBA{}
		}
	}

	return mbi.cachedRow.RGBAAt(x, y)
}

// Opaque returns whether the image is fully opaque.
//
// For more speed and smaller filesizes, MedianBlendedImage will be marked as non-transparent.
// This will speed up image saving by 2x, as there is no need to iterate over the whole image to find a single non opaque pixel.
func (mbi *MedianBlendedImage) Opaque() bool {
	return true
}

// Progress returns the approximate progress of any process that scans the image from top to bottom.
func (mbi *MedianBlendedImage) Progress() (value, max int) {
	size := mbi.Bounds().Size()

	return mbi.queryCounter, size.X * size.Y
}
