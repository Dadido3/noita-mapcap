// Copyright (c) 2019-2022 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	"fmt"
	"image"
	_ "image/png"
	"log"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"sync"
	"time"

	"github.com/nfnt/resize"
)

var ImageTileFileRegex = regexp.MustCompile(`^(-?\d+),(-?\d+).png$`)

type ImageTile struct {
	fileName string
	modTime  time.Time

	scaleDivider int // Downscales the coordinates and images on the fly.

	image      image.Image // Either a rectangle or an RGBA image. The bounds of this image are determined by the filename.
	imageMutex *sync.RWMutex

	invalidationChan chan struct{} // Used to send invalidation requests to the tile's goroutine.
	timeoutChan      chan struct{} // Used to determine whether the tile is still being accessed or not.
}

// NewImageTile returns an image tile object that represents the image at the given path.
// The filename will be used to determine the top left x and y coordinate of the tile.
// This will not load the image into RAM.
func NewImageTile(path string, scaleDivider int) (ImageTile, error) {
	if scaleDivider < 1 {
		return ImageTile{}, fmt.Errorf("invalid scale of %v", scaleDivider)
	}

	baseName := filepath.Base(path)
	result := ImageTileFileRegex.FindStringSubmatch(baseName)
	var x, y int
	if parsed, err := strconv.ParseInt(result[1], 10, 0); err == nil {
		x = int(parsed)
	} else {
		return ImageTile{}, fmt.Errorf("error parsing %q to integer: %w", result[1], err)
	}
	if parsed, err := strconv.ParseInt(result[2], 10, 0); err == nil {
		y = int(parsed)
	} else {
		return ImageTile{}, fmt.Errorf("error parsing %q to integer: %w", result[2], err)
	}

	width, height, err := GetImageFileDimension(path)
	if err != nil {
		return ImageTile{}, err
	}

	var modTime time.Time
	fileInfo, err := os.Lstat(path)
	if err == nil {
		modTime = fileInfo.ModTime()
	}

	return ImageTile{
		fileName:         path,
		modTime:          modTime,
		scaleDivider:     scaleDivider,
		image:            image.Rect(DivideFloor(x, scaleDivider), DivideFloor(y, scaleDivider), DivideCeil(x+width, scaleDivider), DivideCeil(y+height, scaleDivider)),
		imageMutex:       &sync.RWMutex{},
		invalidationChan: make(chan struct{}, 1),
		timeoutChan:      make(chan struct{}, 1),
	}, nil
}

// GetImage returns an image.Image that contains the tile pixel data.
// This will not return errors in case something went wrong, but will just return nil.
// All errors are written to stdout.
func (it *ImageTile) GetImage() *image.RGBA {
	it.imageMutex.RLock()

	// Clear the timeout chan to signal that the image is still being used.
	select {
	case <-it.timeoutChan:
	default:
	}

	// Check if the image is already loaded.
	if img, ok := it.image.(*image.RGBA); ok {
		it.imageMutex.RUnlock()
		return img
	}

	it.imageMutex.RUnlock()
	// It's possible that the image got changed in between here.
	it.imageMutex.Lock()
	defer it.imageMutex.Unlock()

	// Check again if the image is already loaded.
	if img, ok := it.image.(*image.RGBA); ok {
		return img
	}

	// Store rectangle of the old image.
	oldRect := it.image.Bounds()

	file, err := os.Open(it.fileName)
	if err != nil {
		log.Printf("Couldn't load file %q: %v.", it.fileName, err)
		return nil
	}
	defer file.Close()

	img, _, err := image.Decode(file)
	if err != nil {
		log.Printf("Couldn't decode image %q: %v.", it.fileName, err)
		return nil
	}

	if it.scaleDivider > 1 {
		img = resize.Resize(uint(oldRect.Dx()), uint(oldRect.Dy()), img, resize.NearestNeighbor)
	}

	imgRGBA, ok := img.(*image.RGBA)
	if !ok {
		log.Printf("Expected an RGBA image for %q, got %T instead.", it.fileName, img)
		return nil
	}

	imgRGBA.Rect = imgRGBA.Rect.Add(oldRect.Min)

	it.image = imgRGBA

	// Clear any old invalidation request.
	select {
	case <-it.invalidationChan:
	default:
	}

	// Fill timeout channel with one element.
	// This is needed, as the ticker doesn't send a tick on initialization.
	select {
	case it.timeoutChan <- struct{}{}:
	default:
	}

	// Free the image after some time or if requested externally.
	go func() {
		// Set up watchdog that checks if the image is being used.
		ticker := time.NewTicker(5000 * time.Millisecond)
		defer ticker.Stop()

	loop:
		for {
			select {
			case <-ticker.C:
				// Try to send to the timeout channel.
				select {
				case it.timeoutChan <- struct{}{}:
				default:
					// Timeout channel is full because the tile image wasn't queried recently.
					break loop
				}
			case <-it.invalidationChan:
				// An invalidation was requested externally.
				break loop
			}
		}

		// Free image and other stuff.
		it.imageMutex.Lock()
		defer it.imageMutex.Unlock()
		it.image = it.image.Bounds()
	}()

	return imgRGBA
}

// Clears the cached image.
func (it *ImageTile) Invalidate() {
	it.imageMutex.RLock()
	defer it.imageMutex.RUnlock()

	// Try to send invalidation request.
	select {
	case it.invalidationChan <- struct{}{}:
	default:
	}
}

// The scaled image boundaries.
// This matches exactly to what GetImage() returns.
func (it *ImageTile) Bounds() image.Rectangle {
	it.imageMutex.RLock()
	defer it.imageMutex.RUnlock()

	return it.image.Bounds()
}

func (it *ImageTile) String() string {
	return fmt.Sprintf("{ImageTile: %q}", it.fileName)
}
