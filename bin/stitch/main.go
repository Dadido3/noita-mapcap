// Copyright (c) 2019-2024 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	"flag"
	"fmt"
	"image"
	"log"
	"path/filepath"
	"strings"
	"time"

	"github.com/1lann/promptui"
	"github.com/cheggaaa/pb/v3"
)

var flagInputPath = flag.String("input", filepath.Join(".", "..", "..", "output"), "The source path of the image tiles to be stitched.")
var flagEntitiesInputPath = flag.String("entities", filepath.Join(".", "..", "..", "output", "entities.json"), "The path to the entities.json file.")
var flagPlayerPathInputPath = flag.String("player-path", filepath.Join(".", "..", "..", "output", "player-path.json"), "The path to the player-path.json file.")
var flagOutputPath = flag.String("output", filepath.Join(".", "output.png"), "The path and filename of the resulting stitched image. Supported formats/file extensions: `.png`, `.webp`, `.jpg`, `.dzi`.")
var flagScaleDivider = flag.Int("divide", 1, "A downscaling factor. 2 will produce an image with half the side lengths.")
var flagBlendTileLimit = flag.Int("blend-tile-limit", 9, "Limits median blending to the n newest tiles by file modification time. If set to 0, all available tiles will be median blended.")
var flagDZITileSize = flag.Int("dzi-tile-size", 512, "The size of the resulting deep zoom image (DZI) tiles in pixels.")
var flagDZIOverlap = flag.Int("dzi-tile-overlap", 2, "The number of additional pixels around every deep zoom image (DZI) tile.")
var flagWebPLevel = flag.Int("webp-level", 8, "Compression level of WebP files, from 0 (fast) to 9 (slow, best compression).")
var flagXMin = flag.Int("xmin", 0, "Left bound of the output rectangle. This coordinate is included in the output.")
var flagYMin = flag.Int("ymin", 0, "Upper bound of the output rectangle. This coordinate is included in the output.")
var flagXMax = flag.Int("xmax", 0, "Right bound of the output rectangle. This coordinate is not included in the output.")
var flagYMax = flag.Int("ymax", 0, "Lower bound of the output rectangle. This coordinate is not included in the output.")

func main() {
	log.Printf("Noita MapCapture stitching tool v%s.", version)

	flag.Parse()

	var overlays []StitchedImageOverlay

	// Query the user, if there were no cmd arguments given.
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
					return fmt.Errorf("number must be larger than 0")
				}

				return nil
			},
		}

		result, err := prompt.Run()
		if err != nil {
			log.Panicf("Error while getting user input: %v.", err)
		}
		fmt.Sscanf(result, "%d", flagScaleDivider)
	}

	// Query the user, if there were no cmd arguments given.
	if flag.NFlag() == 0 {
		prompt := promptui.Prompt{
			Label:     "Enter blend tile limit:",
			Default:   fmt.Sprint(*flagBlendTileLimit),
			AllowEdit: true,
			Validate: func(s string) error {
				var num int
				_, err := fmt.Sscanf(s, "%d", &num)
				if err != nil {
					return err
				}
				if int(num) < 0 {
					return fmt.Errorf("number must be at least 0")
				}

				return nil
			},
		}

		result, err := prompt.Run()
		if err != nil {
			log.Panicf("Error while getting user input: %v.", err)
		}
		fmt.Sscanf(result, "%d", flagBlendTileLimit)
	}

	// Query the user, if there were no cmd arguments given.
	if flag.NFlag() == 0 {
		prompt := promptui.Prompt{
			Label:     "Enter input path:",
			Default:   *flagInputPath,
			AllowEdit: true,
		}

		result, err := prompt.Run()
		if err != nil {
			log.Panicf("Error while getting user input: %v.", err)
		}
		*flagInputPath = result
	}

	// Query the user, if there were no cmd arguments given.
	if flag.NFlag() == 0 {
		prompt := promptui.Prompt{
			Label:     "Enter \"entities.json\" path:",
			Default:   *flagEntitiesInputPath,
			AllowEdit: true,
		}

		result, err := prompt.Run()
		if err != nil {
			log.Panicf("Error while getting user input: %v.", err)
		}
		*flagEntitiesInputPath = result
	}

	// Load entities if requested.
	entities, err := LoadEntities(*flagEntitiesInputPath)
	if err != nil {
		log.Printf("Failed to load entities: %v.", err)
	}
	if len(entities) > 0 {
		log.Printf("Got %v entities.", len(entities))
		overlays = append(overlays, entities) // Add entities to overlay drawing list.
	}

	// Query the user, if there were no cmd arguments given.
	if flag.NFlag() == 0 {
		prompt := promptui.Prompt{
			Label:     "Enter \"player-path.json\" path:",
			Default:   *flagPlayerPathInputPath,
			AllowEdit: true,
		}

		result, err := prompt.Run()
		if err != nil {
			log.Panicf("Error while getting user input: %v.", err)
		}
		*flagPlayerPathInputPath = result
	}

	// Load player path if requested.
	playerPath, err := LoadPlayerPath(*flagPlayerPathInputPath)
	if err != nil {
		log.Printf("Failed to load player path: %v.", err)
	}
	if len(playerPath) > 0 {
		log.Printf("Got %v player path entries.", len(playerPath))
		overlays = append(overlays, playerPath) // Add player path to overlay drawing list.
	}

	log.Printf("Starting to read tile information at %q.", *flagInputPath)
	tiles, err := LoadImageTiles(*flagInputPath, *flagScaleDivider)
	if err != nil {
		log.Panic(err)
	}
	if len(tiles) == 0 {
		log.Panicf("Got no image tiles from %q.", *flagInputPath)
	}
	log.Printf("Got %v tiles.", len(tiles))

	totalBounds := image.Rectangle{}
	for i, tile := range tiles {
		if i == 0 {
			totalBounds = tile.Bounds()
		} else {
			totalBounds = totalBounds.Union(tile.Bounds())
		}
	}
	log.Printf("Total size of the possible output space is %v.", totalBounds)

	// If the output rect is empty, use the rectangle that encloses all tiles.
	outputRect := image.Rect(*flagXMin, *flagYMin, *flagXMax, *flagYMax)
	if outputRect.Empty() {
		outputRect = totalBounds
	}

	// Query the user, if there were no cmd arguments given.
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
					return fmt.Errorf("rectangle must not be empty")
				}

				outputRect = rect

				return nil
			},
		}

		result, err := prompt.Run()
		if err != nil {
			log.Panicf("Error while getting user input: %v.", err)
		}
		var xMin, yMin, xMax, yMax int
		fmt.Sscanf(result, "%d,%d;%d,%d", &xMin, &yMin, &xMax, &yMax)
		outputRect = image.Rect(xMin, yMin, xMax, yMax)
	}

	// Query the user, if there were no cmd arguments given.
	if flag.NFlag() == 0 {
		prompt := promptui.Prompt{
			Label:     "Enter output filename and path:",
			Default:   *flagOutputPath,
			AllowEdit: true,
		}

		result, err := prompt.Run()
		if err != nil {
			log.Panicf("Error while getting user input: %v.", err)
		}
		*flagOutputPath = result
	}

	fileExtension := strings.ToLower(filepath.Ext(*flagOutputPath))

	// Query the user, if there were no cmd arguments given.
	if flag.NFlag() == 0 && fileExtension == ".dzi" {
		prompt := promptui.Prompt{
			Label:     "Enter DZI tile size:",
			Default:   fmt.Sprint(*flagDZITileSize),
			AllowEdit: true,
			Validate: func(s string) error {
				var num int
				_, err := fmt.Sscanf(s, "%d", &num)
				if err != nil {
					return err
				}
				if int(num) < 1 {
					return fmt.Errorf("number must be at least 1")
				}

				return nil
			},
		}

		result, err := prompt.Run()
		if err != nil {
			log.Panicf("Error while getting user input: %v.", err)
		}
		fmt.Sscanf(result, "%d", flagDZITileSize)
	}

	// Query the user, if there were no cmd arguments given.
	if flag.NFlag() == 0 && fileExtension == ".dzi" {
		prompt := promptui.Prompt{
			Label:     "Enter DZI tile overlap:",
			Default:   fmt.Sprint(*flagDZIOverlap),
			AllowEdit: true,
			Validate: func(s string) error {
				var num int
				_, err := fmt.Sscanf(s, "%d", &num)
				if err != nil {
					return err
				}
				if int(num) < 0 {
					return fmt.Errorf("number must be at least 0")
				}

				return nil
			},
		}

		result, err := prompt.Run()
		if err != nil {
			log.Panicf("Error while getting user input: %v.", err)
		}
		fmt.Sscanf(result, "%d", flagDZIOverlap)
	}

	// Query the user, if there were no cmd arguments given.
	if flag.NFlag() == 0 && (fileExtension == ".dzi" || fileExtension == ".webp") {
		prompt := promptui.Prompt{
			Label:     "Enter WebP compression level:",
			Default:   fmt.Sprint(*flagWebPLevel),
			AllowEdit: true,
			Validate: func(s string) error {
				var num int
				_, err := fmt.Sscanf(s, "%d", &num)
				if err != nil {
					return err
				}
				if int(num) < 0 {
					return fmt.Errorf("level must be at least 0")
				}
				if int(num) > 9 {
					return fmt.Errorf("level must not be larger than 9")
				}

				return nil
			},
		}

		result, err := prompt.Run()
		if err != nil {
			log.Panicf("Error while getting user input: %v.", err)
		}
		fmt.Sscanf(result, "%d", flagWebPLevel)
	}

	blendMethod := BlendMethodMedian{
		BlendTileLimit: *flagBlendTileLimit, // Limit median blending to the n newest tiles by file modification time.
	}

	stitchedImage, err := NewStitchedImage(tiles, outputRect, blendMethod, 128, overlays)
	if err != nil {
		log.Panicf("NewStitchedImage() failed: %v.", err)
	}

	bar := pb.Full.New(0)

	switch fileExtension {
	case ".png":
		if err := exportPNGStitchedImage(stitchedImage, *flagOutputPath, bar); err != nil {
			log.Panicf("Export of PNG file failed: %v", err)
		}
	case ".jpg", ".jpeg":
		if err := exportJPEGStitchedImage(stitchedImage, *flagOutputPath, bar); err != nil {
			log.Panicf("Export of JPEG file failed: %v", err)
		}
	case ".webp":
		if err := exportWebPStitchedImage(stitchedImage, *flagOutputPath, bar, *flagWebPLevel); err != nil {
			log.Panicf("Export of WebP file failed: %v", err)
		}
	case ".dzi":
		if err := exportDZIStitchedImage(stitchedImage, *flagOutputPath, bar, *flagDZITileSize, *flagDZIOverlap, *flagWebPLevel); err != nil {
			log.Panicf("Export of DZI file failed: %v", err)
		}
	default:
		log.Panicf("Unknown output format %q.", fileExtension)
	}

	log.Printf("Created output in %v.", time.Since(bar.StartTime()))

	//fmt.Println("Press the enter key to terminate the console screen!")
	//fmt.Scanln()
}
