// Copyright (c) 2022 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	"image"
	"image/color"
	"sort"
)

// BlendMethodMedian takes the given tiles and median blends them into destImage.
type BlendMethodMedian struct {
	LimitToNew int // If larger than 0, limits median blending to the `LimitToNew` newest tiles by file modification time.
}

func (b BlendMethodMedian) Draw(tiles []*ImageTile, destImage *image.RGBA) {
	bounds := destImage.Bounds()

	if b.LimitToNew > 0 {
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
	rListEmpty, gListEmpty, bListEmpty := make([]int, 0, len(tiles)), make([]int, 0, len(tiles)), make([]int, 0, len(tiles))

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
						rList, gList, bList = append(rList, int(col.R)), append(gList, int(col.G)), append(bList, int(col.B))
						count++
						// Limit number of tiles to median blend.
						// Will be ignored if LimitToNew is 0.
						if count == b.LimitToNew {
							break
						}
					}
				}
			}

			// If there were no images to get data from, ignore the pixel.
			if count == 0 {
				continue
			}

			// Sort colors. Not needed if there is only one color.
			if count > 1 {
				sort.Ints(rList)
				sort.Ints(gList)
				sort.Ints(bList)
			}

			// Take the middle element of each color.
			var r, g, b uint8
			switch count % 2 {
			case 0: // Even.
				r = uint8((rList[count/2-1] + rList[count/2]) / 2)
				g = uint8((gList[count/2-1] + gList[count/2]) / 2)
				b = uint8((bList[count/2-1] + bList[count/2]) / 2)
			default: // Odd.
				r = uint8(rList[(count-1)/2])
				g = uint8(gList[(count-1)/2])
				b = uint8(bList[(count-1)/2])
			}

			destImage.SetRGBA(ix, iy, color.RGBA{r, g, b, 255})
		}
	}
}

/*// BlendNewestPixel takes the given tiles and only draws the newest pixel (based on file modification time) of any overlapping tiles.
func BlendNewestPixel(tiles []*ImageTile, destImage *image.RGBA) {
	bounds := destImage.Bounds()

	// Sort tiles by date.
	sort.Slice(tiles, func(i, j int) bool { return tiles[i].modTime.After(tiles[j].modTime) })

	// List of images corresponding with every tile.
	// Can contain empty/nil entries for images that failed to load.
	images := []*image.RGBA{}
	for _, tile := range tiles {
		images = append(images, tile.GetImage())
	}

	for iy := bounds.Min.Y; iy < bounds.Max.Y; iy++ {
		for ix := bounds.Min.X; ix < bounds.Max.X; ix++ {
			point := image.Point{ix, iy}
			found := false

			// Look for first valid pixel in stack of tiles.
			var col color.RGBA
			for _, img := range images {
				if img != nil {
					if point.In(img.Bounds()) {
						col = img.RGBAAt(point.X, point.Y)
						found = true
						break
					}
				}
			}

			// If there were no images to get data from, ignore the pixel.
			if !found {
				continue
			}

			destImage.SetRGBA(ix, iy, col)
		}
	}
}

// BlendNewestPixelsMedian takes the given tiles and median blends the n newest pixels (based on file modification time) of any overlapping tiles.
// n is some hardcoded value inside this function.
func BlendNewestPixelsMedian(tiles []*ImageTile, destImage *image.RGBA) {
	bounds := destImage.Bounds()

	// Sort tiles by date.
	sort.Slice(tiles, func(i, j int) bool { return tiles[i].modTime.After(tiles[j].modTime) })

	// List of images corresponding with every tile.
	// Can contain empty/nil entries for images that failed to load.
	images := []*image.RGBA{}
	for _, tile := range tiles {
		images = append(images, tile.GetImage())
	}

	// Create arrays to be reused every pixel.
	rListEmpty, gListEmpty, bListEmpty := make([]int, 0, len(tiles)), make([]int, 0, len(tiles)), make([]int, 0, len(tiles))

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
						rList, gList, bList = append(rList, int(col.R)), append(gList, int(col.G)), append(bList, int(col.B))
						count++
						if count == 9 { // Max. number of tiles to median blend.
							break
						}
					}
				}
			}

			// If there were no images to get data from, ignore the pixel.
			if count == 0 {
				continue
			}

			// Sort colors.
			sort.Ints(rList)
			sort.Ints(gList)
			sort.Ints(bList)

			// Take the middle element of each color.
			var r, g, b uint8
			if l := len(rList); l%2 == 0 {
				// Even.
				r = uint8((rList[l/2-1] + rList[l/2]) / 2)
			} else {
				// Odd.
				r = uint8(rList[(l-1)/2])
			}
			if l := len(gList); l%2 == 0 {
				// Even.
				g = uint8((gList[l/2-1] + gList[l/2]) / 2)
			} else {
				// Odd.
				g = uint8(gList[(l-1)/2])
			}
			if l := len(bList); l%2 == 0 {
				// Even.
				b = uint8((bList[l/2-1] + bList[l/2]) / 2)
			} else {
				// Odd.
				b = uint8(bList[(l-1)/2])
			}

			destImage.SetRGBA(ix, iy, color.RGBA{r, g, b, 255})
		}
	}
}*/
