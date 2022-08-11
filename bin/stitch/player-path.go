// Copyright (c) 2022 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	"encoding/json"
	"image"
	"image/color"
	"math"
	"os"

	"github.com/tdewolff/canvas"
	"github.com/tdewolff/canvas/renderers/rasterizer"
)

var playerPathDisplayStyle = canvas.Style{
	FillColor: canvas.Transparent,
	//StrokeColor:  color.RGBA{0, 0, 0, 127},
	StrokeWidth:  3.0,
	StrokeCapper: canvas.RoundCap,
	StrokeJoiner: canvas.MiterJoin,
	DashOffset:   0.0,
	Dashes:       []float64{},
	FillRule:     canvas.NonZero,
}

type PlayerPathElement struct {
	From        [2]float64 `json:"from"`
	To          [2]float64 `json:"to"`
	HP          float64    `json:"hp"`
	MaxHP       float64    `json:"maxHP"`
	Polymorphed bool       `json:"polymorphed"`
}

type PlayerPath []PlayerPathElement

func LoadPlayerPath(path string) (PlayerPath, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}

	var result PlayerPath

	jsonDec := json.NewDecoder(file)
	if err := jsonDec.Decode(&result); err != nil {
		return nil, err
	}

	return result, nil
}

func (p PlayerPath) Draw(destImage *image.RGBA) {
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

	for _, pathElement := range p {
		from, to := pathElement.From, pathElement.To

		// Only draw if the path may cross the image rectangle.
		pathRect := image.Rectangle{image.Point{int(from[0]), int(from[1])}, image.Point{int(to[0]), int(to[1])}}.Canon().Inset(int(-playerPathDisplayStyle.StrokeWidth) - 1)
		if pathRect.Overlaps(destRect) {
			path := &canvas.Path{}
			path.MoveTo(from[0], from[1])
			path.LineTo(to[0], to[1])

			if pathElement.Polymorphed {
				// Set stroke color to typically polymorph color.
				ctx.Style.StrokeColor = color.RGBA{127, 50, 83, 127}
			} else {
				// Set stroke color depending on HP level.
				hpFactor := math.Max(math.Min(pathElement.HP/pathElement.MaxHP, 1), 0)
				hpFactorInv := 1 - hpFactor
				r, g, b, a := uint8((0*hpFactor+1*hpFactorInv)*127), uint8((1*hpFactor+0*hpFactorInv)*127), uint8(0), uint8(127)
				ctx.Style.StrokeColor = color.RGBA{r, g, b, a}
			}

			ctx.DrawPath(0, 0, path)
		}
	}

	// Theoretically we would need to linearize imgRGBA first, but DefaultColorSpace assumes that the color space is linear already.
	r := rasterizer.FromImage(originImage, canvas.DPMM(1.0), canvas.DefaultColorSpace)
	c.Render(r)
	r.Close() // This just transforms the image's luminance curve back from linear into non linear.
}
