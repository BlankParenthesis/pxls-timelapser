# Pxls Timelapser
A bash script for generating timelapses and final images of [Pxls](https://pxls.space) using [PxlsLog-Explorer](https://github.com/Etos2/pxlslog-explorer).

## Prerequisites
You will need to build or acquire a build of [PxlsLog-Explorer](https://github.com/Etos2/pxlslog-explorer) to make use of this.
Specifically, this script works with the `dev` branch as of commit `f37930ce` and the `render` binary (compared to the `filter` binary).

Instructions for building are not provided here, but once you have the binary you will need rename it to `pxlslog-render` and to place it somewhere in your path (such as `~/.local/bin/pxlslog-render` or `/usr/share/bin/pxlslog-render`).

You will also need the following GNU and common programs installed:
- `ffmpeg`
- `curl`
- `tar`
- `magick`
- `grep`
- `awk`
- `sed`
- `printf`
- `head`
- `tail`
- `optipng`
- `numfmt`

The script will check this for you and inform you about missing programs.

## Running
Simply execute [generate.sh](generate.sh) in a terminal of your choice, providing the canvas name you would like to generate timelapses and images for.
See [Parameters](#Parameters) or use `--help` for more configuration options.

### Error 403 when downloading logs
Since [Pxls](https://pxls.space) currently has automated request protection in place, it is highly likely that the automatic downloading of logs and palettes will be blocked with a 403 response from the server.
If you have a developer token for pxls, you can provide it with the `--authentication` (`-a`) parameter.
Otherwise, you can manually download the required files yourself:
- Save [canvas logs](https://pxls.space/extra/logs/) to `~/.cache/pxls-timelapser/canvas/<canvas name>/logs.tar.xz`
- Save initial canvas images from the [archives](https://archives.pxls.space) to `~/.cache/pxls-timelapser/canvas/<canvas name>/initial_normal.png`
- Save [palettes](https://pxls.space/extra/palette/) to `~/.cache/pxls-timelapser/palette/<palette_name>.gpl`

The location may differ depending on the value of `$XDG_CACHE_DIR`.

Once you have placed these three files in the correct location for a canvas, the script should then be able to proceed without any network usage.

### Parameters
#### Output (`-o`, `--output=<DIRECTORY>`)
Set the directory in which to store output.

*Default: current directory*
#### Authentication (`-a`, `--authentication=<TOKEN>`)
Set the bot detection bypass header.

`TOKEN` is a unique value provided to you directly by pxls' staff.
To obtain one, please contact staff and ask for the API access form.
#### Timescale (`--timescale=<TIMESCALE>`)
Set the speed multiplier of generated videos.

*Default: 9000 (5 mintues per frame at 30 frames per second)*
#### Scale (`--scale=<SCALE>`)
Set the scale of generated vides.

*Default: 1*
#### Framerate (`--framerate=<FRAMERATE>`)
Set the framerate of generated videos.

*Default: 30*
#### Codec (`--codec=<CODEC>`)
Set the codec of generated videos.

`CODEC` can be: h264 (default), h265, vp9, or av1.
#### Quality (`--quality=<QUALITY>`)
Set the quality of generated videos.

`QUALITY` can be: low, medium (default), high, or lossless.
Note that vp9 does not support 444 chrome subsampling and "lossless" will not
produce a truly lossless output when it is used as a codec.
#### Skip Images (`--skip-images`)
Skip generating timelapse videos.
#### Skip Videos (`--skip-videos`)
Skip generating final images.
#### Skip Optimization (`--skip-optimization`)
Skip running optipng on outputted images.
