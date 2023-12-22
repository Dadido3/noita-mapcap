package main

import (
	"image/jpeg"
	"log"
	"os"
)

func exportJPEG(stitchedImage *StitchedImage) error {
	log.Printf("Creating output file %q.", *flagOutputPath)
	f, err := os.Create(*flagOutputPath)
	if err != nil {
		log.Panic(err)
	}
	defer f.Close()

	options := &jpeg.Options{
		Quality: 80,
	}

	if err := jpeg.Encode(f, stitchedImage, options); err != nil {
		log.Panic(err)
	}

	return nil
}
