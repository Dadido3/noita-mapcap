// Copyright (c) 2022 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	"encoding/json"
	"image"
	"os"

	"github.com/tdewolff/canvas"
	"github.com/tdewolff/canvas/renderers/rasterizer"
)

type Entities []Entity

func LoadEntities(path string) (Entities, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}

	var result Entities

	jsonDec := json.NewDecoder(file)
	if err := jsonDec.Decode(&result); err != nil {
		return nil, err
	}

	return result, nil
}

// Draw implements the StitchedImageOverlay interface.
func (e Entities) Draw(destImage *image.RGBA) {
	destRect := destImage.Bounds()

	// Same as destImage, but top left is translated to (0, 0).
	originImage := destImage.SubImage(destRect).(*image.RGBA)
	originImage.Rect = originImage.Rect.Sub(destRect.Min)

	c := canvas.New(float64(destRect.Dx()), float64(destRect.Dy()))
	ctx := canvas.NewContext(c)
	ctx.SetCoordSystem(canvas.CartesianIV)
	ctx.SetCoordRect(canvas.Rect{X: -float64(destRect.Min.X), Y: -float64(destRect.Min.Y), W: float64(destRect.Dx()), H: float64(destRect.Dy())}, float64(destRect.Dx()), float64(destRect.Dy()))

	// Set drawing style.
	ctx.Style = playerPathDisplayStyle

	for _, entity := range e {
		// Check if entity origin is near or around the current image rectangle.
		entityOrigin := image.Point{int(entity.Transform.X), int(entity.Transform.Y)}
		if entityOrigin.In(destRect.Inset(-512)) {
			entity.Draw(ctx)
		}
	}

	// Theoretically we would need to linearize imgRGBA first, but DefaultColorSpace assumes that the color space is linear already.
	r := rasterizer.FromImage(originImage, canvas.DPMM(1.0), canvas.DefaultColorSpace)
	c.Render(r)
	r.Close() // This just transforms the image's luminance curve back from linear into non linear.
}
