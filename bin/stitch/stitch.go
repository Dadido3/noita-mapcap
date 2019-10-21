// Copyright (c) 2019 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	"fmt"
	"log"
	"path/filepath"
)

var inputPath = filepath.Join(".", "..", "..", "output")

func main() {
	tiles, err := loadImages(inputPath)
	if err != nil {
		log.Panic(err)
	}

	for _, tile := range tiles {
		fmt.Printf("%v\n", tile)
	}
}
