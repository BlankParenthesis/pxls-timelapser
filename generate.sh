#!/usr/bin/bash

HAS_DEPENDENCIES=true
DEPENDENCIES=(
	pxlslog-explorer
	curl
	tar
	magick
	grep
	awk
	sed
	printf
	head
)

for DEPENDENCY in ${DEPENDENCIES[@]}; do
	if ! command -v $DEPENDENCY 2>&1 >/dev/null; then
		echo "required program $DEPENDENCY not found"
		HAS_DEPENDENCIES=false
	fi
done

if [ $HAS_DEPENDENCIES = false ]; then
	exit 1
fi

OUTPUT=.
AUTHENTICATION=""
TIMESCALE=9000
SCALE=1
FRAMERATE=30
CODEC=h264
QUALITY=medium
POSITIONAL_ARGS=()

usage () {
	cat << EOF
Usage: $0 [OPTION]… CANVAS
Generate final videos and images of a pxls canvas.

Mandatory arguments to long options are mandatory for short options too.
  -o, --output=DIRECTORY       set the directory in which to store output
                                 default: current directory
  -a, --authentication=TOKEN   set the bot detection bypass header
                                 see TOKEN below
      --timescale=TIMESCALE    set the speed multiplier of generated videos
                                 default: 9000
      --scale=SCALE            set the scale of generated vides
                                 default: 1
      --framerate=FRAMERATE    set the framerate of generated videos
                                 default: 30
      --codec=CODEC            set the codec of generated videos
                                 see CODEC below
      --quality=QUALITY        set the quality of generated videos
                                 see QUALITY below
  -h, --help                   display this help and exit
  
TOKEN is a unique value provided to you directly by pxls' staff. To obtain
one, please contact staff and ask for the API access form.

CODEC can be: h264 (default), h265, vp9, or av1.

QUALITY can be: low, medium (default), high, or lossless.
Note that vp9 does not support 444 chrome subsampling and "lossless" will not
produce a truly lossless output when it is used as a codec.
EOF
}

while [ $# -gt 0 ]; do
	case $1 in
		-h | --help)
			usage
			exit 0
			;;
		--output=*)
			OUTPUT=$(echo $1 | sed -r s/^[^=]+=//)
			shift
			;;
		-o | --output)
			if [[ $2 =~ ^-[A-Za-z-] ]]; then
				echo "Expected a value for $1 and got $2"
				exit 1
			fi
			OUTPUT=$2
			shift
			shift
			;;
		--authentication=*)
			OUTPUT=$(echo $1 | sed -r s/^[^=]+=//)
			shift
			;;
		-a | --authentication)
			if [[ $2 =~ ^-[A-Za-z-] ]]; then
				echo "Expected a value for $1 and got $2"
				exit 1
			elif [ -z $2 ]; then
				echo "Missing value for authentication"
				exit 1
			fi
			AUTHENTICATION=$2
			shift
			shift
			;;
		--timescale=*)
			TIMESCALE=$(echo $1 | sed -r s/^[^=]+=//)
			shift
			;;
		--timescale)
			if [[ $2 =~ ^-[A-Za-z-] ]]; then
				echo "Expected a value for $1 and got $2"
				exit 1
			fi
			TIMESCALE=$2
			shift
			shift
			;;
		--scale=*)
			SCALE=$(echo $1 | sed -r s/^[^=]+=//)
			shift
			;;
		--scale)
			if [[ $2 =~ ^-[A-Za-z-] ]]; then
				echo "Expected a value for $1 and got $2"
				exit 1
			fi
			SCALE=$2
			shift
			shift
			;;
		--framerate=*)
			FRAMERATE=$(echo $1 | sed -r s/^[^=]+=//)
			shift
			;;
		--framerate)
			if [[ $2 =~ ^-[A-Za-z-] ]]; then
				echo "Expected a value for $1 and got $2"
				exit 1
			fi
			FRAMERATE=$2
			shift
			shift
			;;
		--codec=*)
			CODEC=$(echo $1 | sed -r s/^[^=]+=//)
			shift
			;;
		--codec)
			if [[ $2 =~ ^-[A-Za-z-] ]]; then
				echo "Expected a value for $1 and got $2"
				exit 1
			fi
			CODEC=$2
			shift
			shift
			;;
		--quality=*)
		QUALITY=$(echo $1 | sed -r s/^[^=]+=//)
			shift
			;;
		--quality)
			if [[ $2 =~ ^-[A-Za-z-] ]]; then
				echo "Expected a value for $1 and got $2"
				exit 1
			fi
			QUALITY=$2
			shift
			shift
			;;
		-*|--*)
			echo "Unknown option $1"
			exit 1
			;;
		*)
			POSITIONAL_ARGS+=("$1")
			shift
			;;
	esac
done

# restore positional parameters
set -- "${POSITIONAL_ARGS[@]}"
CANVAS="$1"

if [ -z $OUTPUT ]; then
	echo "Missing value for output"
	exit 1
fi

if [ -z $TIMESCALE ]; then
	echo "Missing value for timescale"
	exit 1
elif ! [[ $TIMESCALE =~ ^[0-9]+$ && $TIMESCALE -ne "0" ]]; then
	echo "Invalid timescale value: $TIMESCALE"
	exit 1
fi

if [ -z $SCALE ]; then
	echo "Missing value for scale"
	exit 1
elif ! [[ $SCALE =~ ^[0-9]+$ && $SCALE -ne "0" ]]; then
	echo "Invalid scale value: $SCALE"
	exit 1
fi

if [ -z $FRAMERATE ]; then
	echo "Missing value for framerate"
	exit 1
elif ! [[ $FRAMERATE =~ ^[0-9]+$ && $FRAMERATE -ne "0" ]]; then
	echo "Invalid framerate value: $FRAMERATE"
	exit 1
fi

if [ $# -gt 1 ]; then
	echo "Too many positional arguments"
	exit 1
elif [ $# -lt 1 ]; then
	echo "Missing canvas argument"
	exit 1
fi

STEP=$(($TIMESCALE * 1000 / $FRAMERATE))

ENCODE=""

case $CODEC in
	h264 | x264 | avc | mp4)
		case $QUALITY in
			low)      ENCODE="-c:v libx264 -preset:v slow   -pix_fmt yuv420p -crf 32 -profile:v baseline -movflags +faststart" ;;
			medium)   ENCODE="-c:v libx264 -preset:v slow   -pix_fmt yuv420p -crf 23 -profile:v baseline -movflags +faststart" ;;
			high)     ENCODE="-c:v libx264 -preset:v slow   -pix_fmt yuv444p -crf 16 -profile:v high444  -movflags +faststart" ;;
			lossless) ENCODE="-c:v libx264 -preset:v faster -pix_fmt yuv444p -crf 0  -profile:v high444  -movflags +faststart" ;;
			*)
				echo "Unknown quality $QUALITY, options are [low, medium, high, lossless]"
				exit 1
				;;
		esac
		;;
	h265 | x265 | hevc)
		case $QUALITY in
			low)      ENCODE="-c:v libx265 -preset:v slow   -pix_fmt yuv420p -crf 32" ;;
			medium)   ENCODE="-c:v libx265 -preset:v slow   -pix_fmt yuv420p -crf 20" ;;
			high)     ENCODE="-c:v libx265 -preset:v slow   -pix_fmt yuv444p -crf 16 -profile:v main444-8" ;;
			lossless) ENCODE="-c:v libx265 -preset:v faster -pix_fmt yuv444p -crf 0  -profile:v main444-8 -x265-params lossless=1" ;;
			*)
				echo "Unknown quality $QUALITY, options are [low, medium, high, lossless]"
				exit 1
				;;
		esac
		;;
		
	vp9)
		case $QUALITY in
			low)      ENCODE="-c:v libvpx-vp9 -cpu-used 2 -crf 48" ;;
			medium)   ENCODE="-c:v libvpx-vp9 -cpu-used 2 -crf 32" ;;
			high)     ENCODE="-c:v libvpx-vp9 -cpu-used 2 -crf 16" ;;
			lossless) ENCODE="-c:v libvpx-vp9 -cpu-used 5 -crf 0 -lossless 1"
				echo "WARNING: vp9 cannot do 444 subsampling and therefore is not lossless"
				;;
			*)
				echo "Unknown quality $QUALITY, options are [low, medium, high, lossless]"
				exit 1
				;;
		esac
		;;
	av1 | webm)
		case $QUALITY in
			low)      ENCODE="-c:v libaom-av1 -cpu-used 4 -pix_fmt yuv420p -row-mt 1 -tiles 2x2 -crf 36" ;;
			medium)   ENCODE="-c:v libaom-av1 -cpu-used 4 -pix_fmt yuv420p -row-mt 1 -tiles 2x2 -crf 24" ;;
			high)     ENCODE="-c:v libaom-av1 -cpu-used 4 -pix_fmt yuv444p -row-mt 1 -tiles 2x2 -crf 24" ;;
			lossless) ENCODE="-c:v libaom-av1 -cpu-used 4 -pix_fmt yuv444p -row-mt 1 -tiles 2x2 -crf 0" ;;
			*)
				echo "Unknown quality $QUALITY, options are [low, medium, high, lossless]"
				exit 1
				;;
		esac
		;;
	"")
		echo "Missing value for codec"
		exit 1
		;;
	*)
		echo "Unknown codec $CODEC, options are [h264, h265, vp9, av1]"
		exit 1
		;;
esac

if ! [ -d $OUTPUT ]; then
	echo "Output directory $OUTPUT does not exist"
	exit 1
fi

CACHE_DIR="$HOME/.cache"

if ! [ -z $XDG_CACHE_DIR ]; then
	CACHE_DIR="$XDG_CACHE_DIR"
fi
CACHE_DIR="$CACHE_DIR/pxls-timelapser"

mkdir -p "$CACHE_DIR/canvas/$CANVAS"

pushd "$CACHE_DIR/canvas/$CANVAS" > /dev/null

# enable exit on external error
set -e

if ! [ -f logs.tar.xz ]; then
	echo "Downloading logs for canvas $CANVAS…"
	curl "https://pxls.space/extra/logs/dl/pixels_c$CANVAS.sanit.log.tar.xz" \
		--progress-bar \
		--fail \
		--header "X-Pxls-CFAuth: $AUTHENTICATION" \
		--output logs.tar.xz
fi

if ! [ -f pixels.log ]; then
	echo "Extracting pixel log from logs archive…"
	tar -xf logs.tar.xz "pixels_c$CANVAS.sanit.log"
	mv "pixels_c$CANVAS.sanit.log" pixels.log
fi

mkdir -p "$CACHE_DIR/palette"

PALETTE=palette_13

case $CANVAS in
	1 | 2) PALETTE=palette_1 ;;
	3 | 4 | 5 | 6 | 7) PALETTE=palette_2 ;;
	8 | 9 | 10 | 11) PALETTE=palette_3 ;;
	12 | 13 | 13b | 14 | 15 | 16 | 17 | 18 | 19 | 20 | 21 | 22) PALETTE=palette_4 ;;
	23) PALETTE=palette_5 ;;
	24 | 25 | 26 | 27 | 28 | 29 | 30 | 31 | 32 | 33) PALETTE=palette_6 ;;
	34 | 34a | 35 | 36 | 37 | 38 | 39 | 40 | 41 | 42) PALETTE=palette_7 ;;
	43 | 43a) PALETTE=palette_8 ;;
	44 | 45 | 45a) PALETTE=palette_9 ;;
	46 | 47 | 48 | 49 | 50 | 51 | 52 | 53 | 54 | 55 | 56 | 57 | 58 | 59 | 60) PALETTE=palette_10 ;;
	60a) PALETTE=palette_11 ;;
	61 | 62 | 63 | 64 | 64a | 65 | 65a | 66 | 67 | 68 | 69 | 70 | 71 | 72 | 73 | 74 | 75) PALETTE=palette_12 ;;
	76 | 77 | 78 | 78a | 79 | 80 | 81 | 82 | 83 | 84 | 85 | 86 | 87 | 88 | 88a | 89) PALETTE=palette_13 ;;
	21a) PALETTE=gimmick_1 ;;
	30a) PALETTE=gimmick_2 ;;
	56a) PALETTE=gimmick_3 ;;
	*) echo "Unknown canvas $CANVAS, using palette $PALETTE" ;;
esac

if ! [ -f "$CACHE_DIR/palette/$PALETTE.gpl" ]; then
	echo "Downloading palette $PALETTE…"
	curl "https://pxls.space/extra/palette/dl/$PALETTE.gpl" \
		--progress-bar \
		--fail \
		--header "X-Pxls-CFAuth: $AUTHENTICATION" \
		--output "$CACHE_DIR/palette/$PALETTE.gpl"
fi

if ! [ -f initial_normal.png ]; then
	echo "Downloading initial image for canvas $CANVAS…"
	curl "https://archives.pxls.space/data/images/canvas-$CANVAS-initial.png" \
		--progress-bar \
		--fail \
		--header "X-Pxls-CFAuth: $AUTHENTICATION" \
		--output initial_normal.png
fi

SIZE=$(identify initial_normal.png | awk -F ' ' '{print $3}')
WIDTH=$(echo $SIZE | awk -F 'x' '{print $1}')
HEIGHT=$(echo $SIZE | awk -F 'x' '{print $2}')

if ! [ -f initial_heat.png ]; then
	magick -size $SIZE xc:#000000 initial_heat.png
fi
if ! [ -f initial_activity.png ]; then
	magick -size $SIZE xc:#000000 initial_activity.png
fi
if ! [ -f initial_virgin.png ]; then
	magick -size $SIZE xc:#00FF00 initial_virgin.png
fi
if ! [ -f initial_action.png ]; then
	magick -size $SIZE xc:#FFFFFF initial_action.png
fi
if ! [ -f initial_age.png ]; then
	magick -size $SIZE xc:#FFFFFF initial_age.png
fi
if ! [ -f initial_combined.png ]; then
	magick -size $SIZE xc:#FFFFFF initial_combined.png
fi
if ! [ -f initial_minutes.png ]; then
	magick -size $SIZE xc:#FFFFFF initial_minutes.png
fi
if ! [ -f initial_seconds.png ]; then
	magick -size $SIZE xc:#FFFFFF initial_seconds.png
fi
if ! [ -f initial_milliseconds.png ]; then
	magick -size $SIZE xc:#FFFFFF initial_milliseconds.png
fi
if ! [ -f initial_normal_timelapse.png ]; then
	magick initial_normal.png -fill white -opaque none initial_normal_timelapse.png
fi
if ! [ -f initial_heat_timelapse.png ]; then
	magick initial_heat.png -fill black -opaque none initial_heat_timelapse.png
fi
if ! [ -f initial_virgin_timelapse.png ]; then
	magick initial_virgin.png -fill black -opaque none initial_virgin_timelapse.png
fi

FIRST_PIXEL=$(date --date="$(cat pixels.log | head -n1 | awk -F "\t" '{print $1}')" +%s%N)
LAST_PIXEL=$(date --date="$(cat pixels.log | tail -n1 | awk -F "\t" '{print $1}')" +%s%N)

# canvas duration in milliseconds
TIMESPAN=$(( ($LAST_PIXEL - $FIRST_PIXEL) / 1000000 ))
APPROX_FRAMES=$(($TIMESPAN / $STEP))

popd > /dev/null

FILTERS=""
CONTAINER=""
SCALEWIDTH=$(($WIDTH * $SCALE))
SCALEHEIGHT=$(($HEIGHT * $SCALE))
SCALESIZE="${SCALEWIDTH}x$SCALEHEIGHT"

case $CODEC in
	h264 | x264 | h265 | x265 | avc | mp4)
		FILTERS="-sws_flags neighbor -vf scale=$SCALESIZE,pad=ceil($SCALEWIDTH/2)*2:ceil($SCALEHEIGHT/2)*2"
		CONTAINER="mp4"
		;;
	vp9 | av1 | webm)
		FILTERS="-sws_flags neighbor -vf scale=$SCALESIZE"
		CONTAINER="webm"
		;;
	*) exit 1 ;;
esac

KEYFRAME_INTERVAL=$((5 * $FRAMERATE))

pxlslog-render \
	--quiet \
	--step $STEP \
	--step-type time \
	--log "$CACHE_DIR/canvas/$CANVAS/pixels.log" \
	--bg "$CACHE_DIR/canvas/$CANVAS/initial_normal_timelapse.png" \
	--palette "$CACHE_DIR/palette/$PALETTE.gpl" \
	--output-format rgba \
	normal | ffmpeg \
		-hide_banner \
		-loglevel error \
		-progress pipe:1 \
		-nostats \
		-nostdin \
		-y \
		-f rawvideo \
		-pixel_format rgba \
		-video_size $SIZE \
		-r $FRAMERATE \
		-i pipe:0 \
		$ENCODE \
		-g $KEYFRAME_INTERVAL \
		$FILTERS \
		"c${CANVAS}_timelapse_normal.$CONTAINER" \
		| grep --line-buffered ^frame= \
		| awk -F '=' "{printf \"\rGenerating normal timelapse frame %s/$APPROX_FRAMES\", \$2}"

SPACING=$(echo $APPROX_FRAMES | sed 's/./ /g')
printf "\rGenerated normal timelapse        $SPACING $SPACING\n"

pxlslog-render \
	--quiet \
	--step $STEP \
	--step-type time \
	--log "$CACHE_DIR/canvas/$CANVAS/pixels.log" \
	--bg "$CACHE_DIR/canvas/$CANVAS/initial_heat_timelapse.png" \
	--palette "$CACHE_DIR/palette/$PALETTE.gpl" \
	--output-format rgba \
	heat | ffmpeg \
		-hide_banner \
		-loglevel error \
		-progress pipe:1 \
		-nostats \
		-nostdin \
		-y \
		-f rawvideo \
		-pixel_format rgba \
		-video_size $SIZE \
		-r $FRAMERATE \
		-i pipe:0 \
		$ENCODE \
		-g $KEYFRAME_INTERVAL \
		$FILTERS \
		"c${CANVAS}_timelapse_activity.$CONTAINER" \
		| grep --line-buffered ^frame= \
		| awk -F '=' "{printf \"\rGenerating activity timelapse frame %s/$APPROX_FRAMES\", \$2}"

printf "\rGenerated activity timelapse        $SPACING $SPACING\n"

pxlslog-render \
	--quiet \
	--step $STEP \
	--step-type time \
	--log "$CACHE_DIR/canvas/$CANVAS/pixels.log" \
	--bg "$CACHE_DIR/canvas/$CANVAS/initial_virgin_timelapse.png" \
	--palette "$CACHE_DIR/palette/$PALETTE.gpl" \
	--output-format rgba \
	virgin | ffmpeg \
		-hide_banner \
		-loglevel error \
		-progress pipe:1 \
		-nostats \
		-nostdin \
		-y \
		-f rawvideo \
		-pixel_format rgba \
		-video_size $SIZE \
		-r $FRAMERATE \
		-i pipe:0 \
		$ENCODE \
		-g $KEYFRAME_INTERVAL \
		$FILTERS \
		"c${CANVAS}_timelapse_virgin.$CONTAINER" \
		| grep --line-buffered ^frame= \
		| awk -F '=' "{printf \"\rGenerating virgin timelapse frame %s/$APPROX_FRAMES\", \$2}"

printf "\rGenerated timelapse timelapse        $SPACING $SPACING\n"

echo "Generating normal final image"
pxlslog-render \
	--quiet \
	--log "$CACHE_DIR/canvas/$CANVAS/pixels.log" \
	--bg "$CACHE_DIR/canvas/$CANVAS/initial_normal.png" \
	--palette "$CACHE_DIR/palette/$PALETTE.gpl" \
	--screenshot \
	--output "canvas-${CANVAS}-final.png" \
	normal

echo "Generating activity final image"
pxlslog-render \
	--quiet \
	--log "$CACHE_DIR/canvas/$CANVAS/pixels.log" \
	--bg "$CACHE_DIR/canvas/$CANVAS/initial_activity.png" \
	--palette "$CACHE_DIR/palette/$PALETTE.gpl" \
	--screenshot \
	--output "c${CANVAS}_heat.png" \
	activity

echo "Generating virgin final image"
pxlslog-render \
	--quiet \
	--log "$CACHE_DIR/canvas/$CANVAS/pixels.log" \
	--bg "$CACHE_DIR/canvas/$CANVAS/initial_virgin.png" \
	--palette "$CACHE_DIR/palette/$PALETTE.gpl" \
	--screenshot \
	--output "c${CANVAS}_virgin.png" \
	virgin

echo "Generating action final image"
pxlslog-render \
	--quiet \
	--log "$CACHE_DIR/canvas/$CANVAS/pixels.log" \
	--bg "$CACHE_DIR/canvas/$CANVAS/initial_action.png" \
	--palette "$CACHE_DIR/palette/$PALETTE.gpl" \
	--screenshot \
	--output "c${CANVAS}_action.png" \
	action

echo "Generating age final image"
pxlslog-render \
	--quiet \
	--log "$CACHE_DIR/canvas/$CANVAS/pixels.log" \
	--bg "$CACHE_DIR/canvas/$CANVAS/initial_age.png" \
	--palette "$CACHE_DIR/palette/$PALETTE.gpl" \
	--screenshot \
	--output "c${CANVAS}_age.png" \
	age

echo "Generating combined final image"
pxlslog-render \
	--quiet \
	--log "$CACHE_DIR/canvas/$CANVAS/pixels.log" \
	--bg "$CACHE_DIR/canvas/$CANVAS/initial_combined.png" \
	--palette "$CACHE_DIR/palette/$PALETTE.gpl" \
	--screenshot \
	--output "c${CANVAS}_combined.png" \
	combined

echo "Generating minutes final image"
pxlslog-render \
	--quiet \
	--log "$CACHE_DIR/canvas/$CANVAS/pixels.log" \
	--bg "$CACHE_DIR/canvas/$CANVAS/initial_minutes.png" \
	--palette "$CACHE_DIR/palette/$PALETTE.gpl" \
	--screenshot \
	--output "c${CANVAS}_minutes.png" \
	minutes

echo "Generating seconds final image"
pxlslog-render \
	--quiet \
	--log "$CACHE_DIR/canvas/$CANVAS/pixels.log" \
	--bg "$CACHE_DIR/canvas/$CANVAS/initial_seconds.png" \
	--palette "$CACHE_DIR/palette/$PALETTE.gpl" \
	--screenshot \
	--output "c${CANVAS}_seconds.png" \
	seconds

echo "Generating milliseconds final image"
pxlslog-render \
	--quiet \
	--log "$CACHE_DIR/canvas/$CANVAS/pixels.log" \
	--bg "$CACHE_DIR/canvas/$CANVAS/initial_milliseconds.png" \
	--palette "$CACHE_DIR/palette/$PALETTE.gpl" \
	--screenshot \
	--output "c${CANVAS}_milliseconds.png" \
	milliseconds
