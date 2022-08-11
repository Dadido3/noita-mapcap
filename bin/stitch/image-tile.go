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

	image         image.Image   // Either a rectangle or an RGBA image. The bounds of this image are determined by the filename.
	imageMutex    *sync.RWMutex //
	imageUsedFlag bool          // Flag signalling, that the image was used recently.

	pixelErrorSum uint64 // Sum of the difference between the (sub)pixels of all overlapping images. 0 Means that all overlapping images are identical.
}

// NewImageTile returns an image tile object that represents the image at the given path.
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

	width, height, err := getImageFileDimension(path)
	if err != nil {
		return ImageTile{}, err
	}

	var modTime time.Time
	fileInfo, err := os.Lstat(path)
	if err == nil {
		modTime = fileInfo.ModTime()
	}

	return ImageTile{
		fileName:     path,
		modTime:      modTime,
		scaleDivider: scaleDivider,
		image:        image.Rect(x/scaleDivider, y/scaleDivider, (x+width)/scaleDivider, (y+height)/scaleDivider),
		imageMutex:   &sync.RWMutex{},
	}, nil
}

// GetImage returns an image.Image that contains the tile pixel data.
// This will not return errors in case something went wrong, but will just return nil.
// All errors are written to stdout.
func (it *ImageTile) GetImage() *image.RGBA {
	it.imageMutex.RLock()

	it.imageUsedFlag = true // Race condition may happen on this flag, but doesn't matter here.

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

	// Free the image after some time.
	go func() {
		for it.imageUsedFlag {
			it.imageUsedFlag = false
			time.Sleep(1000 * time.Millisecond)
		}

		it.imageMutex.Lock()
		defer it.imageMutex.Unlock()
		it.image = it.image.Bounds()
	}()

	return imgRGBA
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
