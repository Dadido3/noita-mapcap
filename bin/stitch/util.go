// Copyright (c) 2019-2022 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	"fmt"
	"image"
	"math"
	"os"
	"sort"

	"github.com/google/hilbert"
)

// Source: https://gist.github.com/sergiotapia/7882944
func getImageFileDimension(imagePath string) (int, int, error) {
	file, err := os.Open(imagePath)
	if err != nil {
		return 0, 0, fmt.Errorf("can't open file %v: %w", imagePath, err)
	}
	defer file.Close()

	image, _, err := image.DecodeConfig(file)
	if err != nil {
		return 0, 0, fmt.Errorf("error decoding config of image file %v: %w", imagePath, err)
	}

	return image.Width, image.Height, nil
}

func gridifyRectangle(rect image.Rectangle, gridSize int) (result []image.Rectangle) {
	for y := divideFloor(rect.Min.Y, gridSize); y < divideCeil(rect.Max.Y, gridSize); y++ {
		for x := divideFloor(rect.Min.X, gridSize); x < divideCeil(rect.Max.X, gridSize); x++ {
			tempRect := image.Rect(x*gridSize, y*gridSize, (x+1)*gridSize, (y+1)*gridSize)
			intersection := tempRect.Intersect(rect)
			if !intersection.Empty() {
				result = append(result, intersection)
			}
		}
	}

	return
}

func hilbertifyRectangle(rect image.Rectangle, gridSize int) ([]image.Rectangle, error) {
	grid := gridifyRectangle(rect, gridSize)

	gridX := divideFloor(rect.Min.X, gridSize)
	gridY := divideFloor(rect.Min.Y, gridSize)

	// Size of the grid in chunks
	gridWidth := divideCeil(rect.Max.X, gridSize) - divideFloor(rect.Min.X, gridSize)
	gridHeight := divideCeil(rect.Max.Y, gridSize) - divideFloor(rect.Min.Y, gridSize)

	s, err := hilbert.NewHilbert(int(math.Pow(2, math.Ceil(math.Log2(math.Max(float64(gridWidth), float64(gridHeight)))))))
	if err != nil {
		return nil, err
	}

	sort.Slice(grid, func(i, j int) bool {
		// Ignore out of range errors, as they shouldn't happen.
		hilbertIndexA, _ := s.MapInverse(grid[i].Min.X/gridSize-gridX, grid[i].Min.Y/gridSize-gridY)
		hilbertIndexB, _ := s.MapInverse(grid[j].Min.X/gridSize-gridX, grid[j].Min.Y/gridSize-gridY)
		return hilbertIndexA < hilbertIndexB
	})

	return grid, nil
}

// Integer division that rounds to the next integer towards negative infinity.
func divideFloor(a, b int) int {
	temp := a / b

	if ((a ^ b) < 0) && (a%b != 0) {
		return temp - 1
	}

	return temp
}

// Integer division that rounds to the next integer towards positive infinity.
func divideCeil(a, b int) int {
	temp := a / b

	if ((a ^ b) >= 0) && (a%b != 0) {
		return temp + 1
	}

	return temp
}
