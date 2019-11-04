# Noita MapCapture addon [![Build Status](https://travis-ci.com/Dadido3/noita-mapcap.svg?branch=master)](https://travis-ci.com/Dadido3/noita-mapcap)

Addon that captures the map and saves it as image.

![missing image](images/example1.png)

A resulting image with 3.8 gigapixels can be [seen here](https://easyzoom.com/image/159431) (Warning: Spoilers).

## System requirements

- Windows Vista, ..., 10 (64 bit version)
- A few GB of free drive space
- 16-32 GB of RAM (But works with less as long as the software doesn't run out of virtual memory)
- A processor
- Optionally a monitor, keyboard and mouse to interact with the mod/software
- A sound card to listen to music while it's grabbing screenshots

## Usage

1. Have Noita installed.
2. Download the [latest release of the mod from this link](https://github.com/Dadido3/noita-mapcap/releases/latest) (The `Windows.x86.7z`, not the source)
3. Unpack it into your mods folder, so that you get the following file structure `.../Noita/mods/noita-mapcap/mod.xml`.
4. Set your resolution to 1280x720, and use the `Windowed` mode. (Not `Fullscreen (Windowed)`!) If you have to use a different resolution, see advanced usage.
5. Enable the mod and restart Noita.
6. In the game you should see text on screen.
    - Either press `>> Start capturing map around view <<` to capture in a spiral around your current view.
    - Or press `>> Start capturing full map <<` to capture the whole map.
7. The screen will jump around, and the game will take screenshots automatically.
    - Screenshots are saved in `.../Noita/mods/noita-mapcap/output/`.
    - Don't cover the game window.
    - Don't move the game window outside of screen space.
    - If you need to pause, use the ESC menu.
8. When you think you are done, close noita.
9. Start `.../Noita/mods/noita-mapcap/bin/stitch/stitch.exe`.
    - Use the default values to create a complete stitch.
    - It will take the screenshots from the `output` folder.
10. The result will be saved as `.../Noita/mods/noita-mapcap/bin/stitch/output.png` if not defined otherwise.

## Advanced usage

If you use `noita_dev.exe`, you can enable the debug mode by pressing `F5`. Once in debug mode, you can use `F8` to toggle shaders (Includes fog of war), and you can use `F12` to disable the UI. There are some more options in the `F7` and `Shift + F7` menu.

You can capture in a different resolution if you want or need to. If you do so, you have to adjust some values inside of the mod.

The following two formulae have to be true:

![CAPTURE_PIXEL_SIZE = SCREEN_RESOLUTION_* / VIRTUAL_RESOLUTION_*](https://latex.codecogs.com/png.latex?%5Cinline%20%5Cdpi%7B120%7D%20%5Clarge%20%5Cbegin%7Balign*%7D%20%5Ctext%7BCAPTURE%5C_PIXEL%5C_SIZE%7D%20%26%3D%20%5Cfrac%7B%5Ctext%7BSCREEN%5C_RESOLUTION%5C_X%7D%7D%7B%5Ctext%7BVIRTUAL%5C_RESOLUTION%5C_X%7D%7D%5C%5C%20%5Ctext%7BCAPTURE%5C_PIXEL%5C_SIZE%7D%20%26%3D%20%5Cfrac%7B%5Ctext%7BSCREEN%5C_RESOLUTION%5C_Y%7D%7D%7B%5Ctext%7BVIRTUAL%5C_RESOLUTION%5C_Y%7D%7D%20%5Cend%7Balign*%7D)

- Where `CAPTURE_PIXEL_SIZE` can be found inside `.../Noita/mods/noita-mapcap/files/capture.lua`
- `VIRTUAL_RESOLUTION_*` can be found inside `.../Noita/mods/noita-mapcap/files/magic_numbers.xml`
- and `SCREEN_RESOLUTION_*` is the screen resolution you have set up in noita.

You can also change how much the tiles overlap by adjusting the `CAPTURE_GRID_SIZE` in `.../Noita/mods/noita-mapcap/files/capture.lua`. If you increase the grid size, you can capture more area per time. But on the other hand the stitcher may not be able to remove artifacts if the tiles don't overlap enough.

The rectangle for the full map capture mode is defined in `.../Noita/mods/noita-mapcap/files/capture.lua`.

## How to do a full map capture with minimal trouble

For the best experience and result, follow these steps:

1. Change the following values inside of `.../Noita/mods/noita-mapcap/files/magic_numbers.xml`:

    ``` xml
    <MagicNumbers
        VIRTUAL_RESOLUTION_X="840"
        VIRTUAL_RESOLUTION_Y="840"
        STREAMING_CHUNK_TARGET="12"
        ...
    >
    ```

2. Change the following values inside of `.../Noita/save_shared/config.xml`: (Not the one in AppData!)

    ``` xml
    <Config
        ...
        backbuffer_height="840"
        backbuffer_width="840"
        internal_size_h="840"
        internal_size_w="840"
        window_h="840"
        window_w="840"
        fullscreen="0"
        framerate="600"
        ...
    >
    ```

    If that file doesn't exist do step 3 and 5, and come back here.

3. Copy `.../Noita/tools_modding/noita_dev.exe` to `.../Noita/noita_dev.exe`.
    - Also copy it again, if there was an update.

4. Patch your `.../Noita/noita_dev.exe` with [Large Address Aware](https://www.techpowerup.com/forums/threads/large-address-aware.112556/) or a similar tool.

5. Start `.../Noita/noita_dev.exe`.
    - Click `Ignore always` on the `ASSERT FAILED!` requester.

6. When the game is loaded (When you can control your character):
    - Press `F5`, `F8` and `F12` (In that order).
    - Press `F7`, and disable `mTrailerMode` in the menu. (This should reduce chunk loading problems)
    - Press `F7` again to close the menu.

7. Press the `>> Start capturing full map <<` button.

8. Wait a few hours until it's complete.

9. Stitch the image as described above.

## License

[MIT](LICENSE)
