package main

import (
	"fmt"
	"image/jpeg"
	"log"
	"os"
)

func exportJPEG(stitchedImage *StitchedImage, outputPath string) error {
	log.Printf("Creating output file %q.", outputPath)
	f, err := os.Create(outputPath)
	if err != nil {
		return fmt.Errorf("failed to create file: %w", err)
	}
	defer f.Close()

	options := &jpeg.Options{
		Quality: 80,
	}

	if err := jpeg.Encode(f, stitchedImage, options); err != nil {
		return fmt.Errorf("failed to encode image %q: %w", outputPath, err)
	}

	return nil
}
