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

	offset image.Point // Correction offset of the image, so that it aligns pixel perfect with other images. Determined by image matching.
	image  image.Image // Either a rectangle or an RGBA image. The bounds of this image are determined by the filename.
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

func (it *imageTile) String() string {
	return fmt.Sprintf("<ImageTile \"%v\">", it.fileName)
}
