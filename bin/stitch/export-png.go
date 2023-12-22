package main

import (
	"fmt"
	"image/png"
	"log"
	"os"
)

func exportPNG(stitchedImage *StitchedImage, outputPath string) error {
	log.Printf("Creating output file %q.", outputPath)
	f, err := os.Create(outputPath)
	if err != nil {
		return fmt.Errorf("failed to create file: %w", err)
	}
	defer f.Close()

	encoder := png.Encoder{
		CompressionLevel: png.DefaultCompression,
	}

	if err := encoder.Encode(f, stitchedImage); err != nil {
		return fmt.Errorf("failed to encode image %q: %w", outputPath, err)
	}

	return nil
}
