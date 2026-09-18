# Batch Video Preprocessor

This small Bash script can be used to quickly preprocess video files before uploading them for online use.

What it does:

 - read all video files – .mp4, .mov, .mkv, .avi, .webm, .flv, .wmv, .m4v, .mpg, .mpeg, .ts – in a given directory
 - converts each into .mp4 files with the H.264 video codec at a CRF quality factor of 18 (visually lossless) and the AAC audio codec at a birate of 192k
 - caps output dimensions to 2560 x 1440 pixels (16:9 QHD)
 - save each file in the same directory with the same filename and the "web_" prefix

What it doesn't do:

- for .mp4 input files, it does not output files that are larger in file size
- take into account any upload restrictions for particular websites

## Prerequisites

A MacOS or Linux system is required to run the Shell script. For Windows support, you will need to prepare your system to run these files first.

You also need to install [FFmpeg](https://ffmpeg.org/), if it is not already present on your computer (which likely is not needed).

## Installation

 1. Download the script file `video_preprocessor.sh`and put it into some location.
 2. Grant execution permissions:
	1. Open MacOS Terminal or Linux Shell and enter ``chmod +x `` (with a trailing space)
	2. Drag `video_preprocessor.sh` into the Terminal/Shell window. Its file path should appear here.
	3. Press enter and close Terminal/Shell.


## Options

At the top of the Bash script file, you can find a few options for you to change if needed.

- CRF: quality factor
- FFmpeg preset
- maximum video dimensions
- audio bitrate
- file types to process


## Usage

 1. Open MacOS Terminal or Linux Shell.
 2. Drag `video_preprocessor.sh` into the Terminal/Shell window. Its file path should appear here.
 3. If you'd like to read the video files from the same directory that the script is in, hit enter.
 4. Otherwise, add a space to the end and drag the folder containing your videos into the Terminal/Shell. Press enter to start the conversion.
