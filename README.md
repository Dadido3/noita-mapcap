# Noita MapCapture addon [![Build Status](https://travis-ci.com/Dadido3/noita-mapcap.svg?branch=master)](https://travis-ci.com/Dadido3/noita-mapcap)

Addon that captures the map and saves it as image.

![](images/example1.png)

A resulting image with close to 3 gigapixels can be [seen here](https://easyzoom.com/image/158284/album/0/4) (Warning: Spoilers).

## Usage

1. Have Noita installed.
2. Download the [latest release of the mod from this link](https://github.com/Dadido3/noita-mapcap/releases/latest) (The `Windows.x86.7z`, not the source)
3. Unpack it into your mods folder, so that you get the following file structure `.../Noita/mods/noita-mapcap/mod.xml`.
4. Enable mod, and restart Noita.
5. In the game you should see a `>> Start capturing map <<` text on the screen, click it.
6. The screen will jump around, and the game will take screenshots automatically. Don't interfere with it. Screenshots are saved in `.../Noita/mods/noita-mapcap/output/`.
7. When you think you are done, close noita.
8. Start `.../Noita/mods/noita-mapcap/bin/stitch/stitch.exe`.
    - Use the default value to create a complete stitch.
    - It will take the screenshots from the `output` folder.
9. An `output.png` with the stitched result will appear.

## Advanced usage

If you use `noita_dev.exe`, you can enable the debug mode by pressing `F5`. Once in debug mode, you can use `F8` to toggle shaders (Includes fog of war), and you can use `F12` to disable the UI. There are some more options in the `F7` and `Shift + F7` menu.

## License

[MIT](LICENSE)
