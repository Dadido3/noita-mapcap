# Stitch

A program to stitch (overlapping) image tiles of pixel-art to one big image.

The program will use median filtering for overlapping images.
That means that all moving object will completely disappear, and only the static pixels will be outputted.
But this has the disadvantage of being slower, and objects that move only a little bit may become blurred.

You can also use this program to remove moving objects from a series of photographs taken with a tripod.
But as this tool is designed for pixel art, it only accepts png as input.

## Source images

The source images need to contain their coordinates in the filename, as this program doesn't align the images:

`%d,%d.png`

example list of files:

``` Shell Session
0,0.png
512,0.png
-512,0.png
512,-512.png
```

## Usage

- Run the program and follow the interactive prompt.
- Run the program with parameters:
  - `divide int`
    A downscaling factor. 2 will produce an image with half the side lengths. (default 2)
  - `input string`The source path of the image tiles to be stitched. (default "..\\..\\output")
  - `output string`
    The path and filename of the resulting stitched image. (default "output.png")
  - `xmax int`
    Right bound of the output rectangle. This coordinate is not included in the output.
  - `xmin int`
    Left bound of the output rectangle. This coordinate is included in the output.
  - `ymax int`
    Lower bound of the output rectangle. This coordinate is not included in the output.
  - `ymin int`
    Upper bound of the output rectangle. This coordinate is included in the output.

Example of usage:

``` Shell Session
./stitch -divide 2
```

Example of output:

``` Shell Session
2019/10/25 16:02:25 Starting to read tile information at "..\..\output"
2019/10/25 16:02:34 Got 43338 tiles
2019/10/25 16:02:34 Total size of the possible output space is (-19968,-36864)-(21184,35100)
2019/10/25 16:02:34 Creating output image with a size of (41152,71964)
2019/10/25 16:02:46 Stitching 43338 tiles into an image at (-19968,-36864)-(21184,35100)
 100% |████████████████████████████████████████|  [33m13s:0s]
2019/10/25 16:35:59 Creating output file "output.png"
2019/10/25 16:44:17 Created output file "output.png"
```
