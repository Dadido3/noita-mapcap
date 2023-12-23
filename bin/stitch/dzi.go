// Copyright (c) 2023 David Vogel
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
	"strconv"
	"sync"
	"time"
)

const (
	dziTileSize = 512 // The (maximum) width and height of a tile in pixels, not including the overlap.
	dziOverlap  = 0   // The amount of additional pixels on every side of every tile. The real (max) width/height of an image is `2*overlap + tileSize`.
)

type DZI struct {
	stitchedImage *StitchedImage

	fileExtension string

	tileSize int // The (maximum) width and height of a tile in pixels, not including the overlap.
	overlap  int // The amount of additional pixels on every side of every tile. The real (max) width/height of an image is `2*overlap + tileSize`.

	maxZoomLevel int // The maximum zoom level that is needed.
}

func NewDZI(stitchedImage *StitchedImage) DZI {
	dzi := DZI{
		stitchedImage: stitchedImage,

		fileExtension: ".png",

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
		}
	}

	dziDescriptor.Image.XMLNS = "http://schemas.microsoft.com/deepzoom/2008"
	dziDescriptor.Image.Format = "png"
	dziDescriptor.Image.Overlap = strconv.Itoa(d.overlap)
	dziDescriptor.Image.TileSize = strconv.Itoa(d.tileSize)
	dziDescriptor.Image.Size.Width = strconv.Itoa(d.stitchedImage.bounds.Dx())
	dziDescriptor.Image.Size.Height = strconv.Itoa(d.stitchedImage.bounds.Dy())

	jsonEnc := json.NewEncoder(f)
	return jsonEnc.Encode(dziDescriptor)
}

// ExportDZITiles exports the single image tiles for every zoom level.
func (d DZI) ExportDZITiles(outputDir string) error {
	log.Printf("Creating DZI tiles in %q.", outputDir)

	// Start with the highest zoom level (Where every world pixel is exactly mapped into one image pixel).
	// Generate all tiles for this level, and then stitch another image (scaled down by a factor of 2) based on the previously generated tiles.
	// Repeat this process until we have generated level 0.

	// The current stitched image we are working with.
	stitchedImage := d.stitchedImage

	for zoomLevel := d.maxZoomLevel; zoomLevel >= 0; zoomLevel-- {

		levelBasePath := filepath.Join(outputDir, fmt.Sprintf("%d", zoomLevel))
		if err := os.Mkdir(levelBasePath, 0755); err != nil {
			return fmt.Errorf("failed to create zoom level base directory %q: %w", levelBasePath, err)
		}

		// Store list of tiles, so that we can reuse them in the next step for the smaller zoom level.
		imageTiles := ImageTiles{}

		// Export tiles.
		for iY := 0; iY <= (stitchedImage.bounds.Dy()-1)/d.tileSize; iY++ {
			for iX := 0; iX <= (stitchedImage.bounds.Dx()-1)/d.tileSize; iX++ {
				rect := image.Rect(iX*d.tileSize, iY*d.tileSize, iX*d.tileSize+d.tileSize, iY*d.tileSize+d.tileSize)
				rect = rect.Add(stitchedImage.bounds.Min)
				rect = rect.Inset(-d.overlap)
				img := stitchedImage.SubStitchedImage(rect)
				filePath := filepath.Join(levelBasePath, fmt.Sprintf("%d_%d%s", iX, iY, d.fileExtension))
				if err := exportPNGSilent(img, filePath); err != nil {
					return fmt.Errorf("failed to export PNG: %w", err)
				}

				scaleDivider := 2
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

		// Create new stitched image from the previously exported tiles.
		// The tiles are already created in a way, that they are scaled down by a factor of 2.
		var err error
		stitchedImage, err = NewStitchedImage(imageTiles, imageTiles.Bounds(), BlendMethodMedian{BlendTileLimit: 0}, 128, nil)
		if err != nil {
			return fmt.Errorf("failed to run NewStitchedImage(): %w", err)
		}
	}

	return nil
}
