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
	"time"

	"github.com/Dadido3/go-libwebp/webp"
	"github.com/cheggaaa/pb/v3"
)

func exportWebPStitchedImage(stitchedImage *StitchedImage, outputPath string, bar *pb.ProgressBar, webPLevel int) error {
	log.Printf("Creating output file %q.", outputPath)

	// If there is a progress bar, start a goroutine that regularly updates it.
	// We will base the progress on the number of pixels read from the stitched image.
	if bar != nil {
		_, max := stitchedImage.Progress()
		bar.SetRefreshRate(250 * time.Millisecond).SetTotal(int64(max)).Start()

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
					value, max := stitchedImage.Progress()
					bar.SetCurrent(int64(value)).SetTotal(int64(max))
				}
			}
		}()
	}

	return exportWebP(stitchedImage, outputPath, webPLevel)
}

func exportWebP(img image.Image, outputPath string, webPLevel int) error {
	bounds := img.Bounds()
	if bounds.Dx() > 16383 || bounds.Dy() > 16383 {
		return fmt.Errorf("image size exceeds the maximum allowed size (16383) of a WebP image: %d x %d", bounds.Dx(), bounds.Dy())
	}

	f, err := os.Create(outputPath)
	if err != nil {
		return fmt.Errorf("failed to create file: %w", err)
	}
	defer f.Close()

	webPConfig, err := webp.ConfigLosslessPreset(webPLevel)
	if err != nil {
		return fmt.Errorf("failed to create webP config: %v", err)
	}

	if err = webp.Encode(f, img, webPConfig); err != nil {
		return fmt.Errorf("failed to encode image %q: %w", outputPath, err)
	}

	return nil
}
