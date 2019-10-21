// Copyright (c) 2019 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	"fmt"
	"image"
	_ "image/png"
	"os"
)

type imageTile struct {
	fileName string

	originalRect image.Rectangle // Rectangle of the original position. Determined by the file name, the real coordinates may differ a few pixels.
	image        image.Image     // Either a rectangle or an RGBA image. The bounds of this image represent the real and corrected coordinates.
}

func (it *imageTile) loadImage() error {
	// Check if the image is already loaded
	if _, ok := it.image.(*image.RGBA); ok {
		return nil
	}

	// Store rectangle of the old image
	oldRect := it.image.Bounds()

	file, err := os.Open(it.fileName)
	if err != nil {
		return err
	}
	defer file.Close()

	img, _, err := image.Decode(file)
	if err != nil {
		return err
	}

	imgRGBA, ok := img.(*image.RGBA)
	if !ok {
		return fmt.Errorf("Expected an RGBA image, got %T instead", img)
	}

	// Restore the position of the image rectangle
	imgRGBA.Rect = imgRGBA.Rect.Add(oldRect.Min)

	it.image = imgRGBA

	return nil
}

func (it *imageTile) unloadImage() {
	it.image = it.image.Bounds()
}
