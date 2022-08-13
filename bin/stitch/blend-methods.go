// Copyright (c) 2022 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	"image"
	"image/color"
	"math"
	"sort"
)

// BlendMethodMedian takes the given tiles and median blends them into destImage.
type BlendMethodMedian struct {
	BlendTileLimit int // If larger than 0, limits median blending to the n newest tiles by file modification time.
}

// Draw implements the StitchedImageBlendMethod interface.
func (b BlendMethodMedian) Draw(tiles []*ImageTile, destImage *image.RGBA) {
	bounds := destImage.Bounds()

	if b.BlendTileLimit > 0 {
		// Sort tiles by date.
		sort.Slice(tiles, func(i, j int) bool { return tiles[i].modTime.After(tiles[j].modTime) })
	}

	// List of images corresponding with every tile.
	// Can contain empty/nil entries for images that failed to load.
	images := []*image.RGBA{}
	for _, tile := range tiles {
		images = append(images, tile.GetImage())
	}

	// Create arrays to be reused every pixel.
	rListEmpty, gListEmpty, bListEmpty := make([]uint8, 0, len(tiles)), make([]uint8, 0, len(tiles)), make([]uint8, 0, len(tiles))

	for iy := bounds.Min.Y; iy < bounds.Max.Y; iy++ {
		for ix := bounds.Min.X; ix < bounds.Max.X; ix++ {
			rList, gList, bList := rListEmpty, gListEmpty, bListEmpty
			point := image.Point{ix, iy}
			count := 0

			// Iterate through all images and create a list of colors.
			for _, img := range images {
				if img != nil {
					if point.In(img.Bounds()) {
						col := img.RGBAAt(point.X, point.Y)
						rList, gList, bList = append(rList, col.R), append(gList, col.G), append(bList, col.B)
						count++
						// Limit number of tiles to median blend.
						// Will be ignored if the blend tile limit is 0.
						if count == b.BlendTileLimit {
							break
						}
					}
				}
			}

			switch count {
			case 0: // If there were no images to get data from, ignore the pixel.
				continue

			case 1: // Only a single tile for this pixel.
				r, g, b := uint8(rList[0]), uint8(gList[0]), uint8(bList[0])
				destImage.SetRGBA(ix, iy, color.RGBA{r, g, b, 255})

			default: // Multiple overlapping tiles, median blend them.
				var r, g, b uint8
				switch count % 2 {
				case 0: // Even.
					r = uint8((int(QuickSelectUInt8(rList, count/2-1)) + int(QuickSelectUInt8(rList, count/2))) / 2)
					g = uint8((int(QuickSelectUInt8(gList, count/2-1)) + int(QuickSelectUInt8(gList, count/2))) / 2)
					b = uint8((int(QuickSelectUInt8(bList, count/2-1)) + int(QuickSelectUInt8(bList, count/2))) / 2)
				default: // Odd.
					r = QuickSelectUInt8(rList, count/2)
					g = QuickSelectUInt8(gList, count/2)
					b = QuickSelectUInt8(bList, count/2)
				}
				destImage.SetRGBA(ix, iy, color.RGBA{r, g, b, 255})
			}
		}
	}
}

// BlendMethodVoronoi maps every pixel to the tile with the closest center point distance.
// The result is basically a Voronoi partitioning.
type BlendMethodVoronoi struct {
	BlendTileLimit int // If larger than 0, limits blending to the n newest tiles by file modification time.
}

// Draw implements the StitchedImageBlendMethod interface.
func (b BlendMethodVoronoi) Draw(tiles []*ImageTile, destImage *image.RGBA) {
	bounds := destImage.Bounds()

	if b.BlendTileLimit > 0 {
		// Sort tiles by date.
		sort.Slice(tiles, func(i, j int) bool { return tiles[i].modTime.After(tiles[j].modTime) })
	}

	// List of images corresponding to the "tiles" list.
	// Can contain empty/nil entries for images that failed to load.
	images := []*image.RGBA{}
	for _, tile := range tiles {
		images = append(images, tile.GetImage())
	}

	// Create arrays to be reused every pixel.
	var col color.RGBA
	var centerDistSqrMin int

	for iy := bounds.Min.Y; iy < bounds.Max.Y; iy++ {
		for ix := bounds.Min.X; ix < bounds.Max.X; ix++ {
			point := image.Point{ix, iy}
			count := 0
			centerDistSqrMin = math.MaxInt

			// Iterate through all images and create a list of colors.
			for _, img := range images {
				if img != nil {
					if point.In(img.Bounds()) {
						center := img.Bounds().Min.Add(img.Bounds().Max).Div(2)
						centerDiff := point.Sub(center)
						distSqr := centerDiff.X*centerDiff.X + centerDiff.Y*centerDiff.Y
						if centerDistSqrMin > distSqr {
							centerDistSqrMin = distSqr
							col = img.RGBAAt(point.X, point.Y)
						}
						count++
						// Limit number of tiles to blend.
						// Will be ignored if the blend tile limit is 0.
						if count == b.BlendTileLimit {
							break
						}
					}
				}
			}

			// If there were no images to get data from, ignore the pixel.
			if count == 0 {
				continue
			}

			col.A = 255
			destImage.SetRGBA(ix, iy, col)
		}
	}
}
