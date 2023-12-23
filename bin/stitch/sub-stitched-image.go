// Copyright (c) 2023 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	"image"
	"image/color"
)

type SubStitchedImage struct {
	*StitchedImage // The original stitched image.

	bounds image.Rectangle // The new bounds of the cropped image.
}

// Bounds returns the domain for which At can return non-zero color.
// The bounds do not necessarily contain the point (0, 0).
func (s SubStitchedImage) Bounds() image.Rectangle {
	return s.bounds
}

func (s SubStitchedImage) At(x, y int) color.Color {
	return s.RGBAAt(x, y)
}

func (s SubStitchedImage) RGBAAt(x, y int) color.RGBA {
	point := image.Point{X: x, Y: y}
	if !point.In(s.bounds) {
		return color.RGBA{}
	}

	return s.StitchedImage.RGBAAt(x, y)
}
