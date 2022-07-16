// Copyright (c) 2019-2022 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	"fmt"
	"image"
	_ "image/png"
	"os"
	"sync"
	"time"

	"github.com/nfnt/resize"
)

type imageTile struct {
	fileName string

	scaleDivider int // Downscales the coordinates and images on the fly.

	offset image.Point // Correction offset of the image, so that it aligns pixel perfect with other images. Determined by image matching.

	image         image.Image   // Either a rectangle or an RGBA image. The bounds of this image are determined by the filename.
	imageMutex    *sync.RWMutex //
	imageUsedFlag bool          // Flag signalling, that the image was used recently

	pixelErrorSum uint64 // Sum of the difference between the (sub)pixels of all overlapping images. 0 Means that all overlapping images are identical.
}

func (it *imageTile) GetImage() (*image.RGBA, error) {
	it.imageMutex.RLock()

	it.imageUsedFlag = true // Race condition may happen on this flag, but doesn't matter here.

	// Check if the image is already loaded
	if img, ok := it.image.(*image.RGBA); ok {
		it.imageMutex.RUnlock()
		return img, nil
	}

	it.imageMutex.RUnlock()
	// It's possible that the image got changed in between here
	it.imageMutex.Lock()
	defer it.imageMutex.Unlock()

	// Check again if the image is already loaded
	if img, ok := it.image.(*image.RGBA); ok {
		return img, nil
	}

	// Store rectangle of the old image
	oldRect := it.image.Bounds()

	file, err := os.Open(it.fileName)
	if err != nil {
		return &image.RGBA{}, err
	}
	defer file.Close()

	img, _, err := image.Decode(file)
	if err != nil {
		return &image.RGBA{}, err
	}

	if it.scaleDivider > 1 {
		img = resize.Resize(uint(oldRect.Dx()), uint(oldRect.Dy()), img, resize.NearestNeighbor)
	}

	imgRGBA, ok := img.(*image.RGBA)
	if !ok {
		return &image.RGBA{}, fmt.Errorf("expected an RGBA image, got %T instead", img)
	}

	// Restore the position of the image rectangle
	imgRGBA.Rect = imgRGBA.Rect.Add(oldRect.Min)

	it.image = imgRGBA

	// Free the image after some time
	go func() {
		for it.imageUsedFlag {
			time.Sleep(1 * time.Second)
			it.imageUsedFlag = false
		}

		it.imageMutex.Lock()
		defer it.imageMutex.Unlock()
		it.image = it.image.Bounds()
	}()

	return imgRGBA, nil
}

func (it *imageTile) OffsetBounds() image.Rectangle {
	it.imageMutex.RLock()
	defer it.imageMutex.RUnlock()

	return it.image.Bounds().Add(it.offset)
}

func (it *imageTile) Bounds() image.Rectangle {
	it.imageMutex.RLock()
	defer it.imageMutex.RUnlock()

	return it.image.Bounds()
}

func (it *imageTile) String() string {
	return fmt.Sprintf("<ImageTile \"%v\">", it.fileName)
}
