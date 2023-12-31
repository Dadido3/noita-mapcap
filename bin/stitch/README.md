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

``` Text
0,0.png
512,0.png
-512,0.png
512,-512.png
```

## Usage

- Either run the program and follow the interactive prompt.
- Or run the program with parameters:
  - `divide int`
    A downscaling factor. 2 will produce an image with half the side lengths. Defaults to 1.
  - `blend-tile-limit int`
    Limits median blending to the n newest tiles by file modification time.
    If set to 0, all available tiles will be median blended.
    If set to 1, only the newest tile will be used for any resulting pixel.
    Use 1 to prevent ghosting and blurry objects.
  - `input string`
    The source path of the image tiles to be stitched. Defaults to "./..//..//output")
  - `entities string`
    The path to the `entities.json` file. This contains Noita specific entity data. Defaults to "./../../output/entities.json".
  - `player-path string`
    The path to the player-path.json file. This contains the tracked path of the player. Defaults to "./../../output/player-path.json".
  - `output string`
    The path and filename of the resulting stitched image. Defaults to "output.png".
    Supported formats/file extensions: `.png`, `.jpg`, `.dzi`.
  - `dzi-tile-size`
    The size of the resulting deep zoom image (DZI) tiles in pixels. Defaults to 512.
  - `dzi-tile-overlap`
    The number of additional pixels around every deep zoom image (DZI) tile. Defaults to 2.
  - `xmax int`
    Right bound of the output rectangle. This coordinate is not included in the output.
  - `xmin int`
    Left bound of the output rectangle. This coordinate is included in the output.
  - `ymax int`
    Lower bound of the output rectangle. This coordinate is not included in the output.
  - `ymin int`
    Upper bound of the output rectangle. This coordinate is included in the output.

To output the 100x100 area that is centered at the origin use:

``` Shell Session
./stitch -divide 1 -xmin -50 -xmax 50 -ymin -50 -ymax 50
```

To output a [Deep Zoom Image (DZI)](https://en.wikipedia.org/wiki/Deep_Zoom), which can be used with [OpenSeadragon](https://openseadragon.github.io/examples/tilesource-dzi/), use:

``` Shell Session
./stitch -output capture.dzi
```

To start the program interactively:

``` Shell Session
./stitch
```

Example output:

``` Shell Session
Enter downscaling factor:1
Enter input path:..\..\output
2019/11/04 23:53:20 Starting to read tile information at "..\..\output"
2019/11/04 23:53:32 Got 20933 tiles
2019/11/04 23:53:32 Total size of the possible output space is (-25620,-36540)-(25620,36540)
Enter output rectangle (xMin,yMin;xMax,yMax):-25620,-36540;25620,36540
Enter output filename and path:output.png
2019/11/04 23:53:35 Creating output file "output.png"
105 / 571 [--------------->____________________________________________________________________] 18.39% 1 p/s ETA 14m0s
```
