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

type PlayerPath struct {
	PathElements []PlayerPathElement
}

func loadPlayerPath(path string) (*PlayerPath, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}

	var result []PlayerPathElement

	jsonDec := json.NewDecoder(file)
	if err := jsonDec.Decode(&result); err != nil {
		return nil, err
	}

	return &PlayerPath{PathElements: result}, nil
}

func (p PlayerPath) Draw(c *canvas.Context, imgRect image.Rectangle) {
	// Set drawing style.
	c.Style = playerPathDisplayStyle

	for _, pathElement := range p.PathElements {
		from, to := pathElement.From, pathElement.To

		// Only draw if the path may cross the image rectangle.
		pathRect := image.Rectangle{image.Point{int(from[0]), int(from[1])}, image.Point{int(to[0]), int(to[1])}}.Canon().Inset(int(-playerPathDisplayStyle.StrokeWidth) - 1)
		if pathRect.Overlaps(imgRect) {
			path := &canvas.Path{}
			path.MoveTo(from[0], from[1])
			path.LineTo(to[0], to[1])

			if pathElement.Polymorphed {
				// Set stroke color to typically polymorph color.
				c.Style.StrokeColor = color.RGBA{127, 50, 83, 127}
			} else {
				// Set stroke color depending on HP level.
				hpFactor := math.Max(math.Min(pathElement.HP/pathElement.MaxHP, 1), 0)
				hpFactorInv := 1 - hpFactor
				r, g, b, a := uint8((0*hpFactor+1*hpFactorInv)*127), uint8((1*hpFactor+0*hpFactorInv)*127), uint8(0), uint8(127)
				c.Style.StrokeColor = color.RGBA{r, g, b, a}
			}

			c.DrawPath(0, 0, path)
		}
	}
}
