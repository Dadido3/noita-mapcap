// Copyright (c) 2023 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

func exportDZI(stitchedImage *StitchedImage, outputPath string) error {
	descriptorPath := outputPath
	extension := filepath.Ext(outputPath)
	outputTilesPath := strings.TrimSuffix(outputPath, extension) + "_files"

	dzi := NewDZI(stitchedImage)

	// Create base directory of all DZI files.
	if err := os.MkdirAll(outputTilesPath, 0755); err != nil {
		return fmt.Errorf("failed to create output directory: %w", err)
	}

	// Export DZI descriptor.
	if err := dzi.ExportDZIDescriptor(descriptorPath); err != nil {
		return fmt.Errorf("failed to export DZI descriptor: %w", err)
	}

	// Export DZI tiles.
	if err := dzi.ExportDZITiles(outputTilesPath); err != nil {
		return fmt.Errorf("failed to export DZI tiles: %w", err)
	}

	return nil
}
