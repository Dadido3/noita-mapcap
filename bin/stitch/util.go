// Copyright (c) 2019 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	"fmt"
	"image"
	"math"
	"os"
)

// Source: https://gist.github.com/sergiotapia/7882944
func getImageFileDimension(imagePath string) (int, int, error) {
	file, err := os.Open(imagePath)
	if err != nil {
		return 0, 0, fmt.Errorf("Can't open file %v: %w", imagePath, err)
	}
	defer file.Close()

	image, _, err := image.DecodeConfig(file)
	if err != nil {
		return 0, 0, fmt.Errorf("Error decoding config of image file %v: %w", imagePath, err)
	}

	return image.Width, image.Height, nil
}

// getImageDifferenceValue returns the average quadratic difference of the (sub)pixels
func getImageDifferenceValue(a, b *image.RGBA) float64 {
	intersection := a.Bounds().Intersect(b.Bounds())

	if intersection.Empty() {
		return math.Inf(1)
	}

	aSub := a.SubImage(intersection).(*image.RGBA)
	bSub := b.SubImage(intersection).(*image.RGBA)

	value := 0.0

	for iy := 0; iy < intersection.Dy(); iy++ {
		for ix := 0; ix < intersection.Dx()*4; ix++ {
			aValue := float64(aSub.Pix[ix+iy*aSub.Stride])
			bValue := float64(bSub.Pix[ix+iy*bSub.Stride])
			value += math.Pow(aValue-bValue, 2)
		}
	}

	return value / float64(intersection.Dx()*intersection.Dy())
}
