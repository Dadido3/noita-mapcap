// Copyright (c) 2023-2024 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	"fmt"
	"image"
	"image/jpeg"
	"log"
	"os"
	"time"

	"github.com/cheggaaa/pb/v3"
)

func exportJPEGStitchedImage(stitchedImage *StitchedImage, outputPath string, bar *pb.ProgressBar) error {
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

	return exportJPEG(stitchedImage, outputPath)
}

func exportJPEG(img image.Image, outputPath string) error {
	f, err := os.Create(outputPath)
	if err != nil {
		return fmt.Errorf("failed to create file: %w", err)
	}
	defer f.Close()

	options := &jpeg.Options{
		Quality: 80,
	}

	if err := jpeg.Encode(f, img, options); err != nil {
		return fmt.Errorf("failed to encode image %q: %w", outputPath, err)
	}

	return nil
}
