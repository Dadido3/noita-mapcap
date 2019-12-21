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
	"sync"
	"time"

	"github.com/cheggaaa/pb/v3"
	"github.com/manifoldco/promptui"
)

var flagInputPath = flag.String("input", filepath.Join(".", "..", "..", "output"), "The source path of the image tiles to be stitched.")
var flagOutputPath = flag.String("output", filepath.Join(".", "output.png"), "The path and filename of the resulting stitched image.")
var flagScaleDivider = flag.Int("divide", 1, "A downscaling factor. 2 will produce an image with half the side lengths.")
var flagXMin = flag.Int("xmin", 0, "Left bound of the output rectangle. This coordinate is included in the output.")
var flagYMin = flag.Int("ymin", 0, "Upper bound of the output rectangle. This coordinate is included in the output.")
var flagXMax = flag.Int("xmax", 0, "Right bound of the output rectangle. This coordinate is not included in the output.")
var flagYMax = flag.Int("ymax", 0, "Lower bound of the output rectangle. This coordinate is not included in the output.")
var flagPrerender = flag.Bool("prerender", false, "Pre renders the image in RAM before saving. Can speed things up if you have enough RAM.")
var flagCleanupThreshold = flag.Float64("cleanup", 0, "Enable cleanup mode with the given threshold. This will DELETE images from the input folder, no stitching will be done in this mode. A good value to start with is 0.999, which deletes images where the sum of the min-max difference of each sub-pixel overlapping with other images is less than 99.9%% of the maximum possible sum of pixel differences.")

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
	/*if flag.NFlag() == 0 {
		fmt.Println("\nYou can now define a cleanup threshold. This mode will DELETE input images based on their similarity with other overlapping input images. The range is from 0, where no images are deleted, to 1 where all images will be deleted. A good value to get rid of most artifacts is 0.999. If you enter a threshold above 0, the program will not stitch, but DELETE some of your input images. If you want to stitch, enter 0.")
		prompt := promptui.Prompt{
			Label:     "Enter cleanup threshold:",
			Default:   strconv.FormatFloat(*flagCleanupThreshold, 'f', -1, 64),
			AllowEdit: true,
			Validate: func(s string) error {
				result, err := strconv.ParseFloat(s, 64)
				if err != nil {
					return err
				}

				if result < 0 || result > 1 {
					return fmt.Errorf("Number %v outside of valid range [0;1]", result)
				}

				return nil
			},
		}

		result, err := prompt.Run()
		if err != nil {
			log.Panicf("Error while getting user input: %v", err)
		}
		*flagCleanupThreshold, err = strconv.ParseFloat(result, 64)
		if err != nil {
			log.Panicf("Error while parsing user input: %v", err)
		}
	}*/

	if *flagCleanupThreshold < 0 || *flagCleanupThreshold > 1 {
		log.Panicf("Cleanup threshold (%v) outside of valid range [0;1]", *flagCleanupThreshold)
	}
	if *flagCleanupThreshold > 0 {
		bar := pb.Full.New(0)

		log.Printf("Cleaning up %v tiles at %v", len(tiles), outputRect)
		if err := CompareGrid(tiles, outputRect, 512, bar); err != nil {
			log.Panic(err)
		}
		bar.Finish()

		for _, tile := range tiles {
			pixelErrorSumNormalized := float64(tile.pixelErrorSum) / float64(tile.Bounds().Size().X*tile.Bounds().Size().Y*3*255)
			if 1-pixelErrorSumNormalized <= *flagCleanupThreshold {
				os.Remove(tile.fileName)
				log.Printf("Tile %v has matching factor of %f. Deleted file!", &tile, 1-pixelErrorSumNormalized)
			} else {
				log.Printf("Tile %v has matching factor of %f", &tile, 1-pixelErrorSumNormalized)
			}

		}

		return
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
	bar := pb.Full.New(0)
	var wg sync.WaitGroup
	done := make(chan bool)

	if *flagPrerender {
		log.Printf("Creating output image with a size of %v", outputRect.Size())
		tempImage := image.NewRGBA(outputRect)

		log.Printf("Stitching %v tiles into an image at %v", len(tiles), tempImage.Bounds())
		if err := StitchGrid(tiles, tempImage, 512, bar); err != nil {
			log.Panic(err)
		}
		bar.Finish()

		outputImage = tempImage
	} else {
		tempImage := NewMedianBlendedImage(tiles, outputRect)
		_, max := tempImage.Progress()
		bar.SetTotal(int64(max)).Start().SetRefreshRate(1 * time.Second)

		wg.Add(1)
		go func() {
			defer wg.Done()

			ticker := time.NewTicker(1 * time.Second)
			for {
				select {
				case <-done:
					value, _ := tempImage.Progress()
					bar.SetCurrent(int64(value))
					bar.Finish()
					return
				case <-ticker.C:
					value, _ := tempImage.Progress()
					bar.SetCurrent(int64(value))
				}
			}
		}()

		outputImage = tempImage
	}

	log.Printf("Creating output file \"%v\"", *flagOutputPath)
	f, err := os.Create(*flagOutputPath)
	if err != nil {
		log.Panic(err)
	}

	if err := png.Encode(f, outputImage); err != nil {
		f.Close()
		log.Panic(err)
	}

	if !*flagPrerender {
		done <- true
		wg.Wait()
	}

	if err := f.Close(); err != nil {
		log.Panic(err)
	}
	log.Printf("Created output file \"%v\"", *flagOutputPath)

}
