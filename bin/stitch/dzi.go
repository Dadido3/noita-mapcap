// Copyright (c) 2023-2024 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	"encoding/json"
	"fmt"
	"image"
	"log"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"sync"
	"sync/atomic"
	"time"

	"github.com/cheggaaa/pb/v3"
)

type DZI struct {
	stitchedImage *StitchedImage

	fileExtension string

	tileSize int // The (maximum) width and height of a tile in pixels, not including the overlap.
	overlap  int // The amount of additional pixels on every side of every tile. The real (max) width/height of an image is `2*overlap + tileSize`.

	maxZoomLevel int // The maximum zoom level that is needed.
}

// NewDZI creates a new DZI from the given StitchedImages.
//
// dziTileSize and dziOverlap define the size and overlap of the resulting DZI tiles.
func NewDZI(stitchedImage *StitchedImage, dziTileSize, dziOverlap int) DZI {
	dzi := DZI{
		stitchedImage: stitchedImage,

		fileExtension: ".webp",

		overlap:  dziOverlap,
		tileSize: dziTileSize,
	}

	width, height := stitchedImage.bounds.Dx(), stitchedImage.bounds.Dy()

	// Calculate max zoom level and stuff.
	neededLength := max(width, height)
	var sideLength int = 1
	var level int
	for sideLength < neededLength {
		level += 1
		sideLength *= 2
	}
	dzi.maxZoomLevel = level
	//dzi.maxZoomLevelLength = sideLength

	return dzi
}

// ExportDZIDescriptor exports the descriptive JSON file at the given path.
func (d DZI) ExportDZIDescriptor(outputPath string) error {
	log.Printf("Creating DZI descriptor %q.", outputPath)

	f, err := os.Create(outputPath)
	if err != nil {
		return fmt.Errorf("failed to create file: %w", err)
	}
	defer f.Close()

	// Prepare data that describes the layout of the image files.
	var dziDescriptor struct {
		Image struct {
			XMLNS    string `json:"xmlns"`
			Format   string
			Overlap  string
			TileSize string
			Size     struct {
				Width  string
				Height string
			}
			TopLeft struct {
				X string
				Y string
			}
		}
	}

	dziDescriptor.Image.XMLNS = "http://schemas.microsoft.com/deepzoom/2008"
	dziDescriptor.Image.Format = "webp"
	dziDescriptor.Image.Overlap = strconv.Itoa(d.overlap)
	dziDescriptor.Image.TileSize = strconv.Itoa(d.tileSize)
	dziDescriptor.Image.Size.Width = strconv.Itoa(d.stitchedImage.bounds.Dx())
	dziDescriptor.Image.Size.Height = strconv.Itoa(d.stitchedImage.bounds.Dy())
	dziDescriptor.Image.TopLeft.X = strconv.Itoa(d.stitchedImage.bounds.Min.X)
	dziDescriptor.Image.TopLeft.Y = strconv.Itoa(d.stitchedImage.bounds.Min.Y)

	jsonEnc := json.NewEncoder(f)
	return jsonEnc.Encode(dziDescriptor)
}

// ExportDZITiles exports the single image tiles for every zoom level.
func (d DZI) ExportDZITiles(outputDir string, bar *pb.ProgressBar, webPLevel int) error {
	log.Printf("Creating DZI tiles in %q.", outputDir)

	const scaleDivider = 2

	var exportedTiles atomic.Int64

	// If there is a progress bar, start a goroutine that regularly updates it.
	// We will base that on the number of exported tiles.
	if bar != nil {

		// Count final number of tiles.
		bounds := d.stitchedImage.bounds
		var finalTiles int64
		for zoomLevel := d.maxZoomLevel; zoomLevel >= 0; zoomLevel-- {
			for iY := 0; iY <= (bounds.Dy()-1)/d.tileSize; iY++ {
				for iX := 0; iX <= (bounds.Dx()-1)/d.tileSize; iX++ {
					finalTiles++
				}
			}
			bounds = image.Rect(DivideFloor(bounds.Min.X, scaleDivider), DivideFloor(bounds.Min.Y, scaleDivider), DivideCeil(bounds.Max.X, scaleDivider), DivideCeil(bounds.Max.Y, scaleDivider))
		}
		bar.SetRefreshRate(250 * time.Millisecond).SetTotal(finalTiles).Start()

		done := make(chan struct{})
		defer func() {
			done <- struct{}{}
			bar.SetCurrent(bar.Total()).Finish()
		}()

		go func() {
			ticker := time.NewTicker(250 * time.Millisecond)
			for {
				select {
				case <-done:
					return
				case <-ticker.C:
					bar.SetCurrent(exportedTiles.Load())
				}
			}
		}()
	}

	// Start with the highest zoom level (Where every world pixel is exactly mapped into one image pixel).
	// Generate all tiles for this level, and then stitch another image (scaled down by a factor of 2) based on the previously generated tiles.
	// Repeat this process until we have generated level 0.

	// The current stitched image we are working with.
	stitchedImage := d.stitchedImage

	for zoomLevel := d.maxZoomLevel; zoomLevel >= 0; zoomLevel-- {

		levelBasePath := filepath.Join(outputDir, fmt.Sprintf("%d", zoomLevel))
		if err := os.MkdirAll(levelBasePath, 0755); err != nil {
			return fmt.Errorf("failed to create zoom level base directory %q: %w", levelBasePath, err)
		}

		// Store list of tiles, so that we can reuse them in the next step for the smaller zoom level.
		imageTiles := ImageTiles{}

		// Export tiles.
		lg := NewLimitGroup(runtime.NumCPU())
		for iY := 0; iY <= (stitchedImage.bounds.Dy()-1)/d.tileSize; iY++ {
			for iX := 0; iX <= (stitchedImage.bounds.Dx()-1)/d.tileSize; iX++ {
				rect := image.Rect(iX*d.tileSize, iY*d.tileSize, iX*d.tileSize+d.tileSize, iY*d.tileSize+d.tileSize)
				rect = rect.Add(stitchedImage.bounds.Min)
				rect = rect.Inset(-d.overlap)
				img := stitchedImage.SubStitchedImage(rect)
				filePath := filepath.Join(levelBasePath, fmt.Sprintf("%d_%d%s", iX, iY, d.fileExtension))

				lg.Add(1)
				go func() {
					defer lg.Done()
					if err := exportWebP(img, filePath, webPLevel); err != nil {
						log.Printf("Failed to export WebP: %v", err)
					}
					exportedTiles.Add(1)
				}()

				imageTiles = append(imageTiles, ImageTile{
					fileName:         filePath,
					modTime:          time.Now(),
					scaleDivider:     scaleDivider,
					image:            image.Rect(DivideFloor(img.Bounds().Min.X, scaleDivider), DivideFloor(img.Bounds().Min.Y, scaleDivider), DivideCeil(img.Bounds().Max.X, scaleDivider), DivideCeil(img.Bounds().Max.Y, scaleDivider)),
					imageMutex:       &sync.RWMutex{},
					invalidationChan: make(chan struct{}, 1),
					timeoutChan:      make(chan struct{}, 1),
				})
			}
		}
		lg.Wait()

		// Create new stitched image from the previously exported tiles.
		// The tiles are already created in a way, that they are scaled down by a factor of 2.
		var err error
		stitchedImage, err = NewStitchedImage(imageTiles, imageTiles.Bounds(), BlendMethodFast{}, 128, nil)
		if err != nil {
			return fmt.Errorf("failed to run NewStitchedImage(): %w", err)
		}
	}

	return nil
}
