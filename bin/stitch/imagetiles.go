// Copyright (c) 2019 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	"fmt"
	"image"
	"image/color"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"strconv"
	"sync"

	"github.com/schollz/progressbar/v2"
)

var regexFileParse = regexp.MustCompile(`^(-?\d+),(-?\d+).png$`)

func loadImages(path string, scaleDivider int) ([]imageTile, error) {
	var imageTiles []imageTile

	if scaleDivider < 1 {
		return nil, fmt.Errorf("Invalid scale of %v", scaleDivider)
	}

	files, err := filepath.Glob(filepath.Join(path, "*.png"))
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
			fileName:     file,
			scaleDivider: scaleDivider,
			image:        image.Rect(x/scaleDivider, y/scaleDivider, (x+width)/scaleDivider, (y+height)/scaleDivider),
			imageMutex:   &sync.RWMutex{},
		})
	}

	return imageTiles, nil
}

// Stitch takes a list of tiles and stitches them together.
// The destImage shouldn't be too large, or it gets too slow.
func Stitch(tiles []imageTile, destImage *image.RGBA) error {
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
			images = append(images, &imgCopy)                     // TODO: Fix transparent pixels at the output image border because of Inset
		}
	}

	//log.Printf("intersectTiles: %v", intersectTiles)

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
func StitchGrid(tiles []imageTile, destImage *image.RGBA, gridSize int) (errResult error) {
	//workloads := gridifyRectangle(destImage.Bounds(), gridSize)
	workloads, err := hilbertifyRectangle(destImage.Bounds(), gridSize)
	if err != nil {
		return err
	}

	bar := progressbar.New(len(workloads))
	bar.RenderBlank()

	// Start worker threads
	wc := make(chan image.Rectangle)
	wg := sync.WaitGroup{}
	for i := 0; i < runtime.NumCPU()*2; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for workload := range wc {
				if err := Stitch(tiles, destImage.SubImage(workload).(*image.RGBA)); err != nil {
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
				//destImage.SetRGBA(ix, iy, color.RGBA{})
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
