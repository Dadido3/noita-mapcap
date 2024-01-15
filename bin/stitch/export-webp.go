// Copyright (c) 2024 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	"fmt"
	"image"
	"log"
	"os"

	"github.com/chai2010/webp"
)

func exportWebP(stitchedImage image.Image, outputPath string) error {
	log.Printf("Creating output file %q.", outputPath)

	return exportWebPSilent(stitchedImage, outputPath)
}

func exportWebPSilent(stitchedImage image.Image, outputPath string) error {
	bounds := stitchedImage.Bounds()
	if bounds.Dx() > 16383 || bounds.Dy() > 16383 {
		return fmt.Errorf("image size exceeds the maximum allowed size (16383) of a WebP image: %d x %d", bounds.Dx(), bounds.Dy())
	}

	f, err := os.Create(outputPath)
	if err != nil {
		return fmt.Errorf("failed to create file: %w", err)
	}
	defer f.Close()

	if err = webp.Encode(f, stitchedImage, &webp.Options{Lossless: true}); err != nil {
		return fmt.Errorf("failed to encode image %q: %w", outputPath, err)
	}

	return nil
}
