// Copyright (c) 2022 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	"image/color"

	"github.com/tdewolff/canvas"
)

//var entityDisplayFontFamily = canvas.NewFontFamily("times")
//var entityDisplayFontFace *canvas.FontFace

var entityDisplayAreaDamageStyle = canvas.Style{
	Fill:         canvas.Paint{Color: color.RGBA{100, 0, 0, 100}},
	Stroke:       canvas.Paint{},
	StrokeWidth:  1.0,
	StrokeCapper: canvas.ButtCap,
	StrokeJoiner: canvas.MiterJoin,
	DashOffset:   0.0,
	Dashes:       []float64{},
	FillRule:     canvas.NonZero,
}

var entityDisplayMaterialAreaCheckerStyle = canvas.Style{
	Fill:         canvas.Paint{Color: color.RGBA{0, 0, 127, 127}},
	Stroke:       canvas.Paint{},
	StrokeWidth:  1.0,
	StrokeCapper: canvas.ButtCap,
	StrokeJoiner: canvas.MiterJoin,
	DashOffset:   0.0,
	Dashes:       []float64{},
	FillRule:     canvas.NonZero,
}

var entityDisplayTeleportStyle = canvas.Style{
	Fill:         canvas.Paint{Color: color.RGBA{0, 127, 0, 127}},
	Stroke:       canvas.Paint{},
	StrokeWidth:  1.0,
	StrokeCapper: canvas.ButtCap,
	StrokeJoiner: canvas.MiterJoin,
	DashOffset:   0.0,
	Dashes:       []float64{},
	FillRule:     canvas.NonZero,
}

var entityDisplayHitBoxStyle = canvas.Style{
	Fill:         canvas.Paint{Color: color.RGBA{64, 64, 0, 64}},
	Stroke:       canvas.Paint{Color: color.RGBA{0, 0, 0, 64}},
	StrokeWidth:  1.0,
	StrokeCapper: canvas.ButtCap,
	StrokeJoiner: canvas.MiterJoin,
	DashOffset:   0.0,
	Dashes:       []float64{},
	FillRule:     canvas.NonZero,
}

var entityDisplayCollisionTriggerStyle = canvas.Style{
	Fill:         canvas.Paint{Color: color.RGBA{0, 64, 64, 64}},
	Stroke:       canvas.Paint{Color: color.RGBA{0, 0, 0, 64}},
	StrokeWidth:  1.0,
	StrokeCapper: canvas.ButtCap,
	StrokeJoiner: canvas.MiterJoin,
	DashOffset:   0.0,
	Dashes:       []float64{},
	FillRule:     canvas.NonZero,
}

func init() {
	//fontName := "NimbusRoman-Regular"

	//if err := entityDisplayFontFamily.LoadLocalFont(fontName, canvas.FontRegular); err != nil {
	//	log.Printf("Couldn't load font %q: %v", fontName, err)
	//}

	//entityDisplayFontFace = entityDisplayFontFamily.Face(48.0, canvas.White, canvas.FontRegular, canvas.FontNormal)
}

type Entity struct {
	Filename   string          `json:"filename"`
	Transform  EntityTransform `json:"transform"`
	Children   []Entity        `json:"children"`
	Components []Component     `json:"components"`
	Name       string          `json:"name"`
	Tags       []string        `json:"tags"`
}

type EntityTransform struct {
	X        float32 `json:"x"`
	Y        float32 `json:"y"`
	ScaleX   float32 `json:"scaleX"`
	ScaleY   float32 `json:"scaleY"`
	Rotation float32 `json:"rotation"`
}

type Component struct {
	TypeName string         `json:"typeName"`
	Members  map[string]any `json:"members"`
}

func (e Entity) Draw(c *canvas.Context) {
	x, y := float64(e.Transform.X), float64(e.Transform.Y)

	for _, component := range e.Components {
		switch component.TypeName {
		case "AreaDamageComponent": // Area damage like in cursed rock.
			var aabbMinX, aabbMinY, aabbMaxX, aabbMaxY float64
			if member, ok := component.Members["aabb_min"]; ok {
				if aabbMin, ok := member.([]any); ok && len(aabbMin) == 2 {
					aabbMinX, _ = aabbMin[0].(float64)
					aabbMinY, _ = aabbMin[1].(float64)
				}
			}
			if member, ok := component.Members["aabb_max"]; ok {
				if aabbMax, ok := member.([]any); ok && len(aabbMax) == 2 {
					aabbMaxX, _ = aabbMax[0].(float64)
					aabbMaxY, _ = aabbMax[1].(float64)
				}
			}
			if aabbMinX < aabbMaxX && aabbMinY < aabbMaxY {
				c.Style = entityDisplayAreaDamageStyle
				c.DrawPath(x+aabbMinX, y+aabbMinY, canvas.Rectangle(aabbMaxX-aabbMinX, aabbMaxY-aabbMinY))
			}
			if member, ok := component.Members["circle_radius"]; ok {
				if radius, ok := member.(float64); ok && radius > 0 {
					// Theoretically we need to clip the damage area to the intersection of the AABB and the circle, but meh.
					// TODO: Clip the area to the intersection of the box and the circle
					cx, cy := (aabbMinX+aabbMaxX)/2, (aabbMinY+aabbMaxY)/2
					c.Style = entityDisplayAreaDamageStyle
					c.DrawPath(x+cx, y+cy, canvas.Circle(radius))
				}
			}

		case "MaterialAreaCheckerComponent": // Checks for materials in the given AABB.
			var aabbMinX, aabbMinY, aabbMaxX, aabbMaxY float64
			if member, ok := component.Members["area_aabb"]; ok {
				if aabb, ok := member.([]any); ok && len(aabb) == 4 {
					aabbMinX, _ = aabb[0].(float64)
					aabbMinY, _ = aabb[1].(float64)
					aabbMaxX, _ = aabb[2].(float64)
					aabbMaxY, _ = aabb[3].(float64)
				}
			}
			if aabbMinX < aabbMaxX && aabbMinY < aabbMaxY {
				c.Style = entityDisplayMaterialAreaCheckerStyle
				c.DrawPath(x+aabbMinX, y+aabbMinY, canvas.Rectangle(aabbMaxX-aabbMinX, aabbMaxY-aabbMinY))
			}

		case "TeleportComponent":
			var aabbMinX, aabbMinY, aabbMaxX, aabbMaxY float64
			if member, ok := component.Members["source_location_camera_aabb"]; ok {
				if aabb, ok := member.([]any); ok && len(aabb) == 4 {
					aabbMinX, _ = aabb[0].(float64)
					aabbMinY, _ = aabb[1].(float64)
					aabbMaxX, _ = aabb[2].(float64)
					aabbMaxY, _ = aabb[3].(float64)
				}
			}
			if aabbMinX < aabbMaxX && aabbMinY < aabbMaxY {
				c.Style = entityDisplayTeleportStyle
				c.DrawPath(x+aabbMinX, y+aabbMinY, canvas.Rectangle(aabbMaxX-aabbMinX, aabbMaxY-aabbMinY))
			}

		case "HitboxComponent": // General hit box component.
			var aabbMinX, aabbMinY, aabbMaxX, aabbMaxY float64
			if member, ok := component.Members["aabb_min_x"]; ok {
				aabbMinX, _ = member.(float64)
			}
			if member, ok := component.Members["aabb_min_y"]; ok {
				aabbMinY, _ = member.(float64)
			}
			if member, ok := component.Members["aabb_max_x"]; ok {
				aabbMaxX, _ = member.(float64)
			}
			if member, ok := component.Members["aabb_max_y"]; ok {
				aabbMaxY, _ = member.(float64)
			}
			if aabbMinX < aabbMaxX && aabbMinY < aabbMaxY {
				c.Style = entityDisplayHitBoxStyle
				c.DrawPath(x+aabbMinX, y+aabbMinY, canvas.Rectangle(aabbMaxX-aabbMinX, aabbMaxY-aabbMinY))
			}

		case "CollisionTriggerComponent": // Checks if another entity is inside the given radius and box with the given width and height.
			var width, height float64
			path := &canvas.Path{}
			if member, ok := component.Members["width"]; ok {
				width, _ = member.(float64)
			}
			if member, ok := component.Members["height"]; ok {
				height, _ = member.(float64)
			}
			if width > 0 && height > 0 {
				path = canvas.Rectangle(width, height).Translate(-width/2, -height/2)
			}
			// Theoretically we need to clip the area to the intersection of the box and the circle, but meh.
			// TODO: Clip the area to the intersection of the box and the circle
			//if member, ok := component.Members["radius"]; ok {
			//	if radius, ok := member.(float64); ok && radius > 0 {
			//		path = path.Append(canvas.Circle(radius))
			//		path.And()
			//	}
			//}
			if !path.Empty() {
				c.Style = entityDisplayCollisionTriggerStyle
				c.DrawPath(x, y, path)
			}

		}
	}

	c.SetFillColor(color.RGBA{255, 255, 255, 128})
	c.SetStrokeColor(color.RGBA{255, 0, 0, 255})
	c.DrawPath(x, y, canvas.Circle(3))

	//text := canvas.NewTextLine(entityDisplayFontFace, fmt.Sprintf("%s\n%s", e.Name, e.Filename), canvas.Left)
	//c.DrawText(x, y, text)
}
