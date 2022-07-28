// Copyright (c) 2022 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	"archive/zip"
	"compress/flate"
	"flag"
	"io"
	"log"
	"os"
	"path/filepath"
	"time"
)

func main() {
	clean := flag.Bool("clean", true, "Remove distribution dir before starting")
	dist := flag.String("dist", "dist", "Directory to put distribution files in")
	flag.Parse()

	start := time.Now()

	if *clean {
		os.RemoveAll(*dist)
	}

	// Create dist directory tree.
	os.MkdirAll(filepath.Join(*dist), 0755)

	toCopy := []string{
		"AREAS.md", "compatibility.xml", "init.lua", "LICENSE", "mod.xml", "README.md", "settings.lua",

		filepath.Join("bin", "capture-b", "capture.dll"), filepath.Join("bin", "capture-b", "README.md"),
		filepath.Join("bin", "stitch", "stitch.exe"), filepath.Join("bin", "stitch", "README.md"),
		filepath.Join("data"),
		filepath.Join("files"),
		filepath.Join("images"),
	}

	toIgnore := []string{
		filepath.Join("noita-mapcap", "images", "coordinates.pdn"),
	}

	// Create distribution archive.
	newZipFile, err := os.Create(filepath.Join("dist", "dist.zip"))
	if err != nil {
		log.Panicf("Couldn't create output archive: %v", err)
	}
	defer newZipFile.Close()

	zipWriter := zip.NewWriter(newZipFile)
	defer zipWriter.Close()

	zipWriter.RegisterCompressor(zip.Deflate, func(out io.Writer) (io.WriteCloser, error) {
		return flate.NewWriter(out, flate.BestCompression)
	})

	for _, v := range toCopy {
		srcPath, archivePath := filepath.Join(".", v), filepath.Join("noita-mapcap", v)
		if err := addPathToZip(zipWriter, srcPath, archivePath, toIgnore); err != nil {
			log.Panicf("Failed to copy %q into distribution directory: %v", v, err)
		}
		log.Printf("Copied %q", v)
	}

	log.Printf("Distribution script complete in %v", time.Since(start))
}
