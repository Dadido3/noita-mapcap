// Copyright (c) 2022 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	"archive/zip"
	"io"
	"io/fs"
	"log"
	"os"
	"path/filepath"

	"golang.org/x/exp/slices"
)

// addPathToZip adds the given file or directory at srcPath to the zipWriter.
//
// The ignorePaths list is compared to the archive path (archive base path + relative path).
func addPathToZip(zipWriter *zip.Writer, srcPath, archiveBasePath string, ignorePaths []string) error {
	return filepath.WalkDir(srcPath, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}

		relPath, err := filepath.Rel(srcPath, path)
		if err != nil {
			return err
		}
		archivePath := filepath.Join(archiveBasePath, relPath)

		// Skip if path is in ignore list.
		// This applies to directories or files.
		if slices.Contains(ignorePaths, archivePath) {
			log.Printf("Skipped %q", archivePath)
			if d.IsDir() {
				return fs.SkipDir
			}
			return nil
		}

		// Ignore directories.
		if d.IsDir() {
			return nil
		}

		fileToZip, err := os.Open(path)
		if err != nil {
			return err
		}
		defer fileToZip.Close()

		info, err := fileToZip.Stat()
		if err != nil {
			return err
		}

		header, err := zip.FileInfoHeader(info)
		if err != nil {
			return err
		}

		header.Name = archivePath
		header.Method = zip.Deflate

		writer, err := zipWriter.CreateHeader(header)
		if err != nil {
			return err
		}

		if _, err = io.Copy(writer, fileToZip); err != nil {
			return err
		}

		return nil
	})
}
