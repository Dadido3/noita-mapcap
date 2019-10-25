# Noita MapCapture addon

Addon that captures the map and saves it as image.

![](images/example1.png)

A resulting image with close to 3 gigapixels can be [seen here](https://easyzoom.com/image/158284/album/0/4).

## State

Works somewhat, still in development.

**To-Do:**

- [x] Reduce memory usage of stitching program
- [x] Make stitching multi threaded
- [x] Add parameters to stitching program
- [x] Show progress while stitching
- [x] Improve image quality, reduce artifacts
- [ ] Travis or similar for automatic builds, right now there are no executables
- [x] Fix crash while taking screenshots

## Usage

**DLLs and executables are not included in the repo yet! They will be uploaded once releases are built automatically. The mod won't function without them!**

1. Have Noita beta installed
2. Install the repository as mod
    - mod.xml and the rest should be in `.../Noita/mods/noita-mapcap/`
3. Enable mod, and restart Noita
4. In the game you should see a `Start capturing map` text on the screen, click it
5. The screen will jump around, and the game will take screenshots automatically. Don't interfere with it. Screenshots are saved in `.../Noita/mods/noita-mapcap/output/`
6. When you think you are done, close noita
7. Start `.../Noita/mods/noita-mapcap/bin/stitch/stitch.exe`
    - It will take the screenshots from the `output` folder
8. An `output.png` with the stitched result will appear

## Advanced usage

If you use `noita_dev.exe`, you can enable the debug mode by pressing `F5`. Once in debug mode, you can use `F8` to toggle shaders (Includes fog of war), and you can use `F12` to disable the UI. There are some more options in the `F7` and `Shift + F7` menu.

## License

[MIT](LICENSE)
