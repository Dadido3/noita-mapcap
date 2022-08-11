// Copyright (c) 2019-2022 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	"fmt"
	"image"
	"path/filepath"
	"runtime"
	"sync"

	"github.com/cheggaaa/pb/v3"
)

// LoadImageTiles "loads" all images in the directory at the given path.
func LoadImageTiles(path string, scaleDivider int) ([]ImageTile, error) {
	if scaleDivider < 1 {
		return nil, fmt.Errorf("invalid scale of %v", scaleDivider)
	}

	var imageTiles []ImageTile

	files, err := filepath.Glob(filepath.Join(path, "*.png"))
	if err != nil {
		return nil, err
	}

	for _, file := range files {
		imageTile, err := NewImageTile(file, scaleDivider)
		if err != nil {
			return nil, err
		}

		imageTiles = append(imageTiles, imageTile)
	}

	return imageTiles, nil
}

// Compare takes a list of tiles and compares them pixel by pixel.
// The resulting pixel difference sum is stored in each tile.
func Compare(tiles []ImageTile, bounds image.Rectangle) error {
	intersectTiles := []*ImageTile{}
	images := []*image.RGBA{}

	// Get only the tiles that intersect with the bounds.
	// Ignore alignment here, doesn't matter if an image overlaps a few pixels anyways.
	for i, tile := range tiles {
		if tile.Bounds().Overlaps(bounds) {
			tilePtr := &tiles[i]
			img := tilePtr.GetImage()
			if img == nil {
				continue
			}
			intersectTiles = append(intersectTiles, tilePtr)
			imgCopy := *img
			//imgCopy.Rect = imgCopy.Rect
			images = append(images, &imgCopy)
		}
	}

	tempTilesEmpty := make([]*ImageTile, 0, len(intersectTiles))

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
func CompareGrid(tiles []ImageTile, bounds image.Rectangle, gridSize int, bar *pb.ProgressBar) (errResult error) {
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
