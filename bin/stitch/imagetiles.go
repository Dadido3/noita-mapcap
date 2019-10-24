// Copyright (c) 2019 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	"fmt"
	"image"
	"image/color"
	"log"
	"math"
	"math/rand"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"strconv"
	"sync"

	"github.com/schollz/progressbar/v2"
)

const tileAlignmentSearchRadius = 5

type tileAlignment struct {
	offset image.Point // Contains the offset of the tile a, so that it aligns pixel perfect with tile b
}

type tileAlignmentKeys struct {
	a, b *imageTile
}

// tilePairs contains image pairs and their alignment.
type tilePairs map[tileAlignmentKeys]tileAlignment

var regexFileParse = regexp.MustCompile(`^(-?\d+),(-?\d+).png$`)

func loadImages(path string) ([]imageTile, error) {
	var imageTiles []imageTile

	files, err := filepath.Glob(filepath.Join(inputPath, "*.png"))
	if err != nil {
		return nil, err
	}

	for _, file := range files {
		baseName := filepath.Base(file)
		result := regexFileParse.FindStringSubmatch(baseName)
		var x, y int
		if parsed, err := strconv.ParseInt(result[1], 10, 0); err == nil {
			x = int(parsed)
		} else {
			return nil, fmt.Errorf("Error parsing %v to integer: %w", result[1], err)
		}
		if parsed, err := strconv.ParseInt(result[2], 10, 0); err == nil {
			y = int(parsed)
		} else {
			return nil, fmt.Errorf("Error parsing %v to integer: %w", result[2], err)
		}

		width, height, err := getImageFileDimension(file)
		if err != nil {
			return nil, err
		}

		imageTiles = append(imageTiles, imageTile{
			fileName:   file,
			image:      image.Rect(x, y, x+width, y+height),
			imageMutex: &sync.RWMutex{},
		})
	}

	return imageTiles, nil
}

// AlignTilePair returns the pixel delta for the first tile, so that it aligns perfectly with the second.
// This function will load images if needed.
func AlignTilePair(tileA, tileB *imageTile, searchRadius int) (image.Point, error) {
	imgA, err := tileA.GetImage()
	if err != nil {
		return image.Point{}, err
	}
	imgB, err := tileB.GetImage()
	if err != nil {
		return image.Point{}, err
	}

	bestPoint := image.Point{}
	bestValue := math.Inf(1)

	for y := -searchRadius; y <= searchRadius; y++ {
		for x := -searchRadius; x <= searchRadius; x++ {
			point := image.Point{x, y} // Offset of the first image.

			value := getImageDifferenceValue(imgA, imgB, point)
			if bestValue > value {
				bestValue, bestPoint = value, point
			}
		}
	}

	return bestPoint, nil
}

func (tp tilePairs) AlignTiles(tiles []*imageTile) error {

	n := len(tiles)
	maxOperations, operations := (n-1)*(n)/2, 0

	// Compare all n tiles with each other. (`(n-1)*(n)/2` comparisons)
	for i, tileA := range tiles {
		for j := i + 1; j < len(tiles); j++ {
			tileB := tiles[j]

			_, ok := tp[tileAlignmentKeys{tileA, tileB}]
			if !ok {
				// Entry doesn't exist yet. Determine tile pair alignment.
				offset, err := AlignTilePair(tileA, tileB, tileAlignmentSearchRadius)
				if err != nil {
					return fmt.Errorf("Failed to align tile pair %v %v: %w", tileA, tileB, err)
				}

				operations++
				log.Printf("(%v/%v)Got alignment for pair %v %v. Offset = %v", operations, maxOperations, tileA, tileB, offset)

				// Store tile alignment pair, also reversed.
				tp[tileAlignmentKeys{tileA, tileB}] = tileAlignment{offset: offset}
				tp[tileAlignmentKeys{tileB, tileA}] = tileAlignment{offset: offset.Mul(-1)}

			}
		}
	}

	// Silly and hacky method to determine the minimal error.
	// TODO: Use some mixed integer method or something similar to optimize the tile alignment

	// The error function returns the x and y error. The axes are optimized independent of each other later on.
	errorFunction := func(tiles []*imageTile) (image.Point, error) {
		errorValue := image.Point{}

		for i, tileA := range tiles {
			for j := i + 1; j < len(tiles); j++ {
				tileB := tiles[j]

				tileAlignment, ok := tp[tileAlignmentKeys{tileA, tileB}]
				if !ok {
					return image.Point{}, fmt.Errorf("Offset of the tile pair %v %v is missing", tileA, tileB)
				}

				// The error is the difference between the needed offset, and the actual offsets
				tempErrorValue := pointAbs(tileAlignment.offset.Sub(tileA.offset).Add(tileB.offset))

				errorValue = errorValue.Add(tempErrorValue)
			}
		}
		return errorValue, nil
	}

	errorValue, err := errorFunction(tiles)
	if err != nil {
		return fmt.Errorf("Failed to calculate error value: %w", err)
	}
	// Randomly select tiles, and move them in the direction where the error value is lower.
	// The "gradient" is basically caluclated by try and error.
	for i := 0; i < len(tiles)*tileAlignmentSearchRadius*5; i++ {
		tile := tiles[rand.Intn(len(tiles))]

		// Calculate error value for positive shifting.
		tile.offset = tile.offset.Add(image.Point{1, 1})
		plusErrorValue, err := errorFunction(tiles)
		if err != nil {
			return fmt.Errorf("Failed to calculate error value: %w", err)
		}

		// Calculate error value for negative shifting.
		tile.offset = tile.offset.Add(image.Point{-2, -2})
		minusErrorValue, err := errorFunction(tiles)
		if err != nil {
			return fmt.Errorf("Failed to calculate error value: %w", err)
		}

		// Reset tile movement.
		tile.offset = tile.offset.Add(image.Point{1, 1})

		// Move this tile towards the smaller error value.
		if plusErrorValue.X < errorValue.X {
			tile.offset = tile.offset.Add(image.Point{1, 0})
		}
		if minusErrorValue.X < errorValue.X {
			tile.offset = tile.offset.Add(image.Point{-1, 0})
		}
		if plusErrorValue.Y < errorValue.Y {
			tile.offset = tile.offset.Add(image.Point{0, 1})
		}
		if minusErrorValue.Y < errorValue.Y {
			tile.offset = tile.offset.Add(image.Point{0, -1})
		}
	}

	// TODO: Move images in a way that the majority of images is positioned equal to their original position

	return nil
}

func (tp tilePairs) Stitch(tiles []imageTile, destImage *image.RGBA) error {
	intersectTiles := []*imageTile{}
	images := []*image.RGBA{}

	// Get only the tiles that intersect with the destination image bounds.
	// Ignore alignment here, doesn't matter if an image overlaps a few pixels anyways.
	for i, tile := range tiles {
		if tile.OffsetBounds().Overlaps(destImage.Bounds()) {
			tilePtr := &tiles[i]
			intersectTiles = append(intersectTiles, tilePtr)
			img, err := tilePtr.GetImage()
			if err != nil {
				return fmt.Errorf("Couldn't get image: %w", err)
			}
			imgCopy := *img
			imgCopy.Rect = imgCopy.Rect.Add(tile.offset).Inset(4) // Reduce image bounds by 4 pixels on each side, because otherwise there will be artifacts.
			images = append(images, &imgCopy)
		}
	}

	//log.Printf("intersectTiles: %v", intersectTiles)

	// Align those tiles
	/*if err := tp.alignTiles(intersectTiles); err != nil {
		return fmt.Errorf("Failed to align tiles: %w", err)
	}*/

	// TODO: Add working aligning algorithm

	/*for _, intersectTile := range intersectTiles {
		intersectTile.loadImage()
		draw.Draw(destImage, destImage.Bounds(), intersectTile.image, destImage.Bounds().Min, draw.Over)
	}*/

	/*for _, intersectTile := range intersectTiles {
		drawLabel(destImage, intersectTile.image.Bounds().Min.X, intersectTile.image.Bounds().Min.Y, fmt.Sprintf("%v", intersectTile.fileName))
	}*/

	drawMedianBlended(images, destImage)

	return nil
}

// StitchGrid calls stitch, but divides the workload into a grid of chunks.
// Additionally it runs the workload multithreaded.
func (tp tilePairs) StitchGrid(tiles []imageTile, destImage *image.RGBA, gridSize int) (errResult error) {
	workloads := gridifyRectangle(destImage.Bounds(), gridSize)

	bar := progressbar.New(len(workloads))
	bar.RenderBlank()

	// Start worker threads
	wc := make(chan image.Rectangle)
	wg := sync.WaitGroup{}
	for i := 0; i < runtime.NumCPU(); i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for workload := range wc {
				if err := tp.Stitch(tiles, destImage.SubImage(workload).(*image.RGBA)); err != nil {
					errResult = err // This will not stop execution, but at least one of any errors is returned.
				}
				bar.Add(1)
			}
		}()
	}

	// Push workload to worker threads
	for _, workload := range workloads {
		wc <- workload
	}

	// Wait until all worker threads are done
	close(wc)
	wg.Wait()

	// Newline because of the progress bar
	fmt.Println("")

	return
}

func drawMedianBlended(images []*image.RGBA, destImage *image.RGBA) {
	bounds := destImage.Bounds()

	// Create arrays to be reused every pixel
	rListEmpty, gListEmpty, bListEmpty := make([]int, 0, len(images)), make([]int, 0, len(images)), make([]int, 0, len(images))

	for iy := bounds.Min.Y; iy < bounds.Max.Y; iy++ {
		for ix := bounds.Min.X; ix < bounds.Max.X; ix++ {
			rList, gList, bList := rListEmpty, gListEmpty, bListEmpty
			point := image.Point{ix, iy}
			found := false

			// Iterate through all images and create a list of colors.
			for _, img := range images {
				if point.In(img.Bounds()) {
					col := img.RGBAAt(point.X, point.Y)
					rList, gList, bList = append(rList, int(col.R)), append(gList, int(col.G)), append(bList, int(col.B))
					found = true
				}
			}

			// If there were no images to get data from, ignore the pixel.
			if !found {
				continue
			}

			// Sort colors.
			sort.Ints(rList)
			sort.Ints(gList)
			sort.Ints(bList)

			// Take the middle element of each color.
			var r, g, b uint8
			if len(rList)%2 == 0 {
				// Even
				r = uint8((rList[len(rList)/2-1] + rList[len(rList)/2]) / 2)
			} else {
				// Odd
				r = uint8(rList[(len(rList)-1)/2])
			}
			if len(gList)%2 == 0 {
				// Even
				g = uint8((gList[len(gList)/2-1] + gList[len(gList)/2]) / 2)
			} else {
				// Odd
				g = uint8(gList[(len(gList)-1)/2])
			}
			if len(bList)%2 == 0 {
				// Even
				b = uint8((bList[len(bList)/2-1] + bList[len(bList)/2]) / 2)
			} else {
				// Odd
				b = uint8(bList[(len(bList)-1)/2])
			}

			destImage.SetRGBA(ix, iy, color.RGBA{r, g, b, 255})
		}
	}
}
