// Copyright (c) 2019-2022 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	"fmt"
	"image"
	"image/color"
	"log"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"strconv"
	"sync"

	"github.com/cheggaaa/pb/v3"
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
	//intersectTiles := []*imageTile{}
	images := []*image.RGBA{}

	// Get only the tiles that intersect with the destination image bounds.
	// Ignore alignment here, doesn't matter if an image overlaps a few pixels anyways.
	for i, tile := range tiles {
		if tile.OffsetBounds().Overlaps(destImage.Bounds()) {
			tilePtr := &tiles[i]
			img, err := tilePtr.GetImage()
			if err != nil {
				log.Printf("Couldn't load image tile %s: %v", tile.String(), err)
				continue
			}
			//intersectTiles = append(intersectTiles, tilePtr)
			imgCopy := *img
			imgCopy.Rect = imgCopy.Rect.Add(tile.offset)
			images = append(images, &imgCopy)
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

// StitchGrid calls Stitch, but divides the workload into a grid of chunks.
// Additionally it runs the workload multithreaded.
func StitchGrid(tiles []imageTile, destImage *image.RGBA, gridSize int, bar *pb.ProgressBar) (errResult error) {
	//workloads := gridifyRectangle(destImage.Bounds(), gridSize)
	workloads, err := hilbertifyRectangle(destImage.Bounds(), gridSize)
	if err != nil {
		return err
	}

	if bar != nil {
		bar.SetTotal(int64(len(workloads))).Start()
	}

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
				if bar != nil {
					bar.Increment()
				}
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

// Compare takes a list of tiles and compares them pixel by pixel.
// The resulting pixel difference sum is stored in each tile.
func Compare(tiles []imageTile, bounds image.Rectangle) error {
	intersectTiles := []*imageTile{}
	images := []*image.RGBA{}

	// Get only the tiles that intersect with the bounds.
	// Ignore alignment here, doesn't matter if an image overlaps a few pixels anyways.
	for i, tile := range tiles {
		if tile.OffsetBounds().Overlaps(bounds) {
			tilePtr := &tiles[i]
			img, err := tilePtr.GetImage()
			if err != nil {
				log.Printf("Couldn't load image tile %s: %v", tile.String(), err)
				continue
			}
			intersectTiles = append(intersectTiles, tilePtr)
			imgCopy := *img
			imgCopy.Rect = imgCopy.Rect.Add(tile.offset)
			images = append(images, &imgCopy)
		}
	}

	tempTilesEmpty := make([]*imageTile, 0, len(intersectTiles))

	for iy := bounds.Min.Y; iy < bounds.Max.Y; iy++ {
		for ix := bounds.Min.X; ix < bounds.Max.X; ix++ {
			var rMin, rMax, gMin, gMax, bMin, bMax uint8
			point := image.Point{ix, iy}
			found := false
			tempTiles := tempTilesEmpty

			// Iterate through all images and find min and max subpixel values.
			for i, img := range images {
				if point.In(img.Bounds()) {
					tempTiles = append(tempTiles, intersectTiles[i])
					col := img.RGBAAt(point.X, point.Y)
					if !found {
						found = true
						rMin, rMax, gMin, gMax, bMin, bMax = col.R, col.R, col.G, col.G, col.B, col.B
					} else {
						if rMin > col.R {
							rMin = col.R
						}
						if rMax < col.R {
							rMax = col.R
						}
						if gMin > col.G {
							gMin = col.G
						}
						if gMax < col.G {
							gMax = col.G
						}
						if bMin > col.B {
							bMin = col.B
						}
						if bMax < col.B {
							bMax = col.B
						}
					}
				}
			}

			// If there were no images to get data from, ignore the pixel.
			if !found {
				continue
			}

			// Write the error value back into the tiles (Only those that contain the point point)
			for _, tile := range tempTiles {
				tile.pixelErrorSum += uint64(rMax-rMin) + uint64(gMax-gMin) + uint64(bMax-bMin)
			}

		}
	}

	return nil
}

// CompareGrid calls Compare, but divides the workload into a grid of chunks.
// Additionally it runs the workload multithreaded.
func CompareGrid(tiles []imageTile, bounds image.Rectangle, gridSize int, bar *pb.ProgressBar) (errResult error) {
	//workloads := gridifyRectangle(destImage.Bounds(), gridSize)
	workloads, err := hilbertifyRectangle(bounds, gridSize)
	if err != nil {
		return err
	}

	if bar != nil {
		bar.SetTotal(int64(len(workloads))).Start()
	}

	// Start worker threads
	wc := make(chan image.Rectangle)
	wg := sync.WaitGroup{}
	for i := 0; i < runtime.NumCPU()*2; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for workload := range wc {
				if err := Compare(tiles, workload); err != nil {
					errResult = err // This will not stop execution, but at least one of any errors is returned.
				}
				if bar != nil {
					bar.Increment()
				}
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

	return
}
