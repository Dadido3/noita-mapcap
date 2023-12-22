package main

import (
	"image/png"
	"log"
	"os"
)

func exportPNG(stitchedImage *StitchedImage) error {
	log.Printf("Creating output file %q.", *flagOutputPath)
	f, err := os.Create(*flagOutputPath)
	if err != nil {
		log.Panic(err)
	}
	defer f.Close()

	encoder := png.Encoder{
		CompressionLevel: png.DefaultCompression,
	}

	if err := encoder.Encode(f, stitchedImage); err != nil {
		log.Panic(err)
	}

	return nil
}
