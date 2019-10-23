// Copyright (c) 2019 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	"fmt"
	"image"
	"image/color"
	"math"
	"os"

	"golang.org/x/image/font"
	"golang.org/x/image/font/basicfont"
	"golang.org/x/image/math/fixed"
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

// getImageDifferenceValue returns the average quadratic difference of the (sub)pixels.
// 0 means the images are identical, +inf means that the images don't intersect.
func getImageDifferenceValue(a, b *image.RGBA, offsetA image.Point) float64 {
	intersection := a.Bounds().Add(offsetA).Intersect(b.Bounds())

	if intersection.Empty() {
		return math.Inf(1)
	}

	aSub := a.SubImage(intersection.Sub(offsetA)).(*image.RGBA)
	bSub := b.SubImage(intersection).(*image.RGBA)

	intersectionWidth := intersection.Dx() * 4
	intersectionHeight := intersection.Dy()

	var value int64

	for iy := 0; iy < intersectionHeight; iy++ {
		aSlice := aSub.Pix[iy*aSub.Stride : iy*aSub.Stride+intersectionWidth]
		bSlice := bSub.Pix[iy*bSub.Stride : iy*bSub.Stride+intersectionWidth]
		for ix := 0; ix < intersectionWidth; ix += 3 {
			diff := int64(aSlice[ix]) - int64(bSlice[ix])
			value += diff * diff
		}
	}

	return float64(value) / float64(intersectionWidth*intersectionHeight)
}

func gridifyRectangle(rect image.Rectangle, gridSize int) (result []image.Rectangle) {
	for y := divideFloor(rect.Min.Y, gridSize); y < divideCeil(rect.Max.Y, gridSize); y++ {
		for x := divideFloor(rect.Min.X, gridSize); x < divideCeil(rect.Max.X, gridSize); x++ {
			tempRect := image.Rect(x*gridSize, y*gridSize, (x+1)*gridSize, (y+1)*gridSize)
			if tempRect.Overlaps(rect) {
				result = append(result, tempRect)
			}
		}
	}

	return
}

func drawLabel(img *image.RGBA, x, y int, label string) {
	col := color.RGBA{200, 100, 0, 255}
	point := fixed.Point26_6{X: fixed.Int26_6(x * 64), Y: fixed.Int26_6(y * 64)}

	d := &font.Drawer{
		Dst:  img,
		Src:  image.NewUniform(col),
		Face: basicfont.Face7x13,
		Dot:  point,
	}
	d.DrawString(label)
}

func intAbs(x int) int {
	if x < 0 {
		return -x
	}
	return x
}

func pointAbs(p image.Point) image.Point {
	if p.X < 0 {
		p.X = -p.X
	}
	if p.Y < 0 {
		p.Y = -p.Y
	}
	return p
}

// Integer division that rounds to the next integer towards negative infinity
func divideFloor(a, b int) int {
	temp := a / b

	if ((a ^ b) < 0) && (a%b != 0) {
		return temp - 1
	}

	return temp
}

// Integer division that rounds to the next integer towards positive infinity
func divideCeil(a, b int) int {
	temp := a / b

	if ((a ^ b) >= 0) && (a%b != 0) {
		return temp + 1
	}

	return temp
}
