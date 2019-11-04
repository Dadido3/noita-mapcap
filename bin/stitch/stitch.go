// Copyright (c) 2019 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	"flag"
	"fmt"
	"image"
	"image/png"
	"log"
	"os"
	"path/filepath"

	"github.com/manifoldco/promptui"
)

var flagInputPath = flag.String("input", filepath.Join(".", "..", "..", "output"), "The source path of the image tiles to be stitched.")
var flagOutputPath = flag.String("output", filepath.Join(".", "output.png"), "The path and filename of the resulting stitched image.")
var flagScaleDivider = flag.Int("divide", 1, "A downscaling factor. 2 will produce an image with half the side lengths.")
var flagXMin = flag.Int("xmin", 0, "Left bound of the output rectangle. This coordinate is included in the output.")
var flagYMin = flag.Int("ymin", 0, "Upper bound of the output rectangle. This coordinate is included in the output.")
var flagXMax = flag.Int("xmax", 0, "Right bound of the output rectangle. This coordinate is not included in the output.")
var flagYMax = flag.Int("ymax", 0, "Lower bound of the output rectangle. This coordinate is not included in the output.")
var flagLowRAM = flag.Bool("lowram", true, "Reduces the needed ram drastically, at the expense of speed.")

func main() {
	flag.Parse()

	// Query the user, if there were no cmd arguments given
	if flag.NFlag() == 0 {
		prompt := promptui.Prompt{
			Label:     "Enter downscaling factor:",
			Default:   fmt.Sprint(*flagScaleDivider),
			AllowEdit: true,
			Validate: func(s string) error {
				var num int
				_, err := fmt.Sscanf(s, "%d", &num)
				if err != nil {
					return err
				}
				if int(num) < 1 {
					return fmt.Errorf("Number must be larger than 0")
				}

				return nil
			},
		}

		result, err := prompt.Run()
		if err != nil {
			log.Panicf("Error while getting user input: %v", err)
		}
		fmt.Sscanf(result, "%d", flagScaleDivider)
	}

	// Query the user, if there were no cmd arguments given
	if flag.NFlag() == 0 {
		prompt := promptui.Prompt{
			Label:     "Enter input path:",
			Default:   *flagInputPath,
			AllowEdit: true,
		}

		result, err := prompt.Run()
		if err != nil {
			log.Panicf("Error while getting user input: %v", err)
		}
		*flagInputPath = result
	}

	log.Printf("Starting to read tile information at \"%v\"", *flagInputPath)
	tiles, err := loadImages(*flagInputPath, *flagScaleDivider)
	if err != nil {
		log.Panic(err)
	}
	if len(tiles) == 0 {
		log.Panicf("Got no tiles inside of %v", *flagInputPath)
	}
	log.Printf("Got %v tiles", len(tiles))

	totalBounds := image.Rectangle{}
	for i, tile := range tiles {
		if i == 0 {
			totalBounds = tile.Bounds()
		} else {
			totalBounds = totalBounds.Union(tile.Bounds())
		}
	}
	log.Printf("Total size of the possible output space is %v", totalBounds)

	/*profFile, err := os.Create("cpu.prof")
	if err != nil {
		log.Panicf("could not create CPU profile: %v", err)
	}
	defer profFile.Close()
	if err := pprof.StartCPUProfile(profFile); err != nil {
		log.Panicf("could not start CPU profile: %v", err)
	}
	defer pprof.StopCPUProfile()*/

	// If the output rect is empty, use the rectangle that encloses all tiles
	outputRect := image.Rect(*flagXMin, *flagYMin, *flagXMax, *flagYMax)
	if outputRect.Empty() {
		outputRect = totalBounds
	}

	// Query the user, if there were no cmd arguments given
	if flag.NFlag() == 0 {
		prompt := promptui.Prompt{
			Label:     "Enter output rectangle (xMin,yMin;xMax,yMax):",
			Default:   fmt.Sprintf("%d,%d;%d,%d", outputRect.Min.X, outputRect.Min.Y, outputRect.Max.X, outputRect.Max.Y),
			AllowEdit: true,
			Validate: func(s string) error {
				var xMin, yMin, xMax, yMax int
				_, err := fmt.Sscanf(s, "%d,%d;%d,%d", &xMin, &yMin, &xMax, &yMax)
				if err != nil {
					return err
				}
				rect := image.Rect(xMin, yMin, xMax, yMax)
				if rect.Empty() {
					return fmt.Errorf("Rectangle must not be empty")
				}

				outputRect = rect

				return nil
			},
		}

		result, err := prompt.Run()
		if err != nil {
			log.Panicf("Error while getting user input: %v", err)
		}
		var xMin, yMin, xMax, yMax int
		fmt.Sscanf(result, "%d,%d;%d,%d", &xMin, &yMin, &xMax, &yMax)
		outputRect = image.Rect(xMin, yMin, xMax, yMax)
	}

	// Query the user, if there were no cmd arguments given
	if flag.NFlag() == 0 {
		prompt := promptui.Prompt{
			Label:     "Enter output filename and path:",
			Default:   *flagOutputPath,
			AllowEdit: true,
		}

		result, err := prompt.Run()
		if err != nil {
			log.Panicf("Error while getting user input: %v", err)
		}
		*flagOutputPath = result
	}

	var outputImage image.Image
	if *flagLowRAM {
		outputImage = NewMedianBlendedImage(tiles)
	} else {
		log.Printf("Creating output image with a size of %v", outputRect.Size())
		tempImage := image.NewRGBA(outputRect)

		log.Printf("Stitching %v tiles into an image at %v", len(tiles), outputImage.Bounds())
		if err := StitchGrid(tiles, tempImage, 512); err != nil {
			log.Panic(err)
		}

		outputImage = tempImage
	}

	log.Printf("Creating output file \"%v\"", "output.png")
	f, err := os.Create("output.png")
	if err != nil {
		log.Panic(err)
	}

	if err := png.Encode(f, outputImage); err != nil {
		f.Close()
		log.Panic(err)
	}

	if err := f.Close(); err != nil {
		log.Panic(err)
	}
	log.Printf("Created output file \"%v\"", "output.png")

}
