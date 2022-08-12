// Copyright (c) 2019-2022 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	"fmt"
	"path/filepath"
)

type ImageTiles []ImageTile

// LoadImageTiles "loads" all images in the directory at the given path.
func LoadImageTiles(path string, scaleDivider int) (ImageTiles, error) {
	if scaleDivider < 1 {
		return nil, fmt.Errorf("invalid scale of %v", scaleDivider)
	}

	var imageTiles ImageTiles

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

// InvalidateAboveY invalidates all cached images that have no pixel at the given y coordinate or below.
func (it ImageTiles) InvalidateAboveY(y int) {
	for i := range it {
		tile := &it[i] // Need to copy a reference.
		if tile.Bounds().Max.Y <= y {
			tile.Invalidate()
		}
	}
}
