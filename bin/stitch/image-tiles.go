// Copyright (c) 2019-2022 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	"fmt"
	"path/filepath"
)

// LoadImageTiles "loads" all images in the directory at the given path.
func LoadImageTiles(path string, scaleDivider int) ([]ImageTile, error) {
	if scaleDivider < 1 {
		return nil, fmt.Errorf("invalid scale of %v", scaleDivider)
	}

	var imageTiles []ImageTile

	files, err := filepath.Glob(filepath.Join(path, "*.png"))
	if err != nil {
		return nil, err
	}

	for _, file := range files {
		imageTile, err := NewImageTile(file, scaleDivider)
		if err != nil {
			return nil, err
		}

		imageTiles = append(imageTiles, imageTile)
	}

	return imageTiles, nil
}
