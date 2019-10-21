// Copyright (c) 2019 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	"fmt"
	"image"
	"path/filepath"
	"regexp"
	"strconv"
)

var regexFileParse = regexp.MustCompile(`^(-?\d+),(-?\d+).png$`)

func loadImages(path string) ([]imageTile, error) {
	var imageTiles []imageTile

	files, err := filepath.Glob(filepath.Join(inputPath, "*.png"))
	if err != nil {
		return nil, err
	}

	for _, file := range files {
		baseName := filepath.Base(file)
		result := regexFileParse.FindStringSubmatch(baseName)
		var x, y int
		if parsed, err := strconv.ParseInt(result[1], 10, 0); err == nil {
			x = int(parsed)
		} else {
			return nil, fmt.Errorf("Error parsing %v to integer: %w", result[1], err)
		}
		if parsed, err := strconv.ParseInt(result[2], 10, 0); err == nil {
			y = int(parsed)
		} else {
			return nil, fmt.Errorf("Error parsing %v to integer: %w", result[2], err)
		}

		width, height, err := getImageFileDimension(file)
		if err != nil {
			return nil, err
		}

		imageTiles = append(imageTiles, imageTile{
			fileName:     file,
			originalRect: image.Rect(x, y, x+width, y+height),
			image:        image.Rect(x, y, x+width, y+height),
		})
	}

	return imageTiles, nil
}
