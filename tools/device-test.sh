#!/bin/bash
# Takes the app through its states on a device with the screen on and
# unlocked, and saves a screenshot of each: the library, a document
# opened as Files opens one (applicationManager/open), full screen, double
# tap zoom, a flick, the contents, every page, Go to Page, a held word, a
# password. Fingers come from tools/touch.c (built here, static), at
# positions for the screen's size.
#
#   tools/device-test.sh <adb serial> <name> <cross gcc> <sysroot> [cpu flags]
#
# WAIT (seconds, 5 by default) is how long a document gets to open: more on
# a slow device (the TouchPad wants 9).
#
# Install the app first (tools/install.sh). The test documents go to
# /media/internal/pdf-viewer-test and are removed after; the app's settings
# are put back. Writes build/test-output/device/<name>/.
set -e
cd "$(dirname "$0")/.."
SERIAL=${1:?usage: tools/device-test.sh <adb serial> <name> <cross gcc> <sysroot> [cpu flags]}
NAME=${2:?}
CC=${3:?}
SYSROOT=${4:?}
CPU=${5:-}
ADB="adb -s $SERIAL"
WAIT=${WAIT:-5}
ID=org.webosports.app.pdf
DIR=/media/internal/pdf-viewer-test
OUT=build/test-output/device/$NAME
mkdir -p "$OUT"

# shellcheck disable=SC2086
"$CC" --sysroot="$SYSROOT" $CPU -O2 -Wall -Wextra -static -o "$OUT/touch" tools/touch.c
$ADB push "$OUT/touch" /tmp/pdf-touch >/dev/null
$ADB shell chmod +x /tmp/pdf-touch

sh_() { $ADB shell "$1" | tr -d '\r'; }
awake() { sh_ "luna-send -n 1 -w 3000 luna://com.palm.display/control/notifyUserActivity '{}' > /dev/null 2>&1"; }
shot() {
    awake
    sh_ "luna-send -w 10000 -n 1 luna://com.webos.surfacemanager/captureCompositorOutput '{\"output\":\"/tmp/pdf-shot.png\",\"format\":\"PNG\"}' > /tmp/pdf-c.out 2>&1"
    $ADB pull /tmp/pdf-shot.png "$OUT/$1.png" > /dev/null
    echo "   $OUT/$1.png"
}
launch() {
    awake
    sh_ "luna-send -n 1 -w 8000 luna://com.webos.service.applicationmanager/launch '{\"id\":\"$ID\",\"params\":$1}' > /dev/null 2>&1"
}
close() { sh_ "luna-send -n 1 -w 8000 luna://com.webos.service.applicationmanager/closeByAppId '{\"id\":\"$ID\"}' > /dev/null 2>&1; sleep 2"; }

sh_ "luna-send -n 1 -w 3000 luna://com.palm.display/control/setState '{\"state\":\"on\"}' > /dev/null 2>&1"
shot probe
SIZE=$(python3 -I -c 'import sys,struct; d=open(sys.argv[1],"rb").read(24); print(*struct.unpack(">II", d[16:24]))' "$OUT/probe.png")
W=${SIZE% *}
H=${SIZE#* }
rm -f "$OUT/probe.png"
echo "   screen ${W}x${H}"
# The touchscreen: TOUCH=/dev/input/eventN where there is no touchscreen0 link (Q25).
TOUCH=${TOUCH:-/dev/input/touchscreen0}
touch_() { sh_ "/tmp/pdf-touch $TOUCH $W $H $*"; }

# Closed first: the app writes its settings as it closes.
close
PREFS=$(sh_ "find / -path /proc -prune -o -path '*/$ID/preferences.ini' -print 2>/dev/null | sed -n 1p")
[ -n "$PREFS" ] && sh_ "cp '$PREFS' /tmp/pdf-prefs.saved && rm -f '$PREFS'"
cleanup() {
    close
    sh_ "rm -rf $DIR /tmp/pdf-touch /tmp/pdf-shot.png"
    if [ -n "$PREFS" ]; then sh_ "cp /tmp/pdf-prefs.saved '$PREFS'"; fi
    echo "   removed the test documents, put back the app's settings"
}
trap cleanup EXIT

sh_ "mkdir -p $DIR"
for f in guide.pdf locked.pdf tracemonkey.pdf helloworld.pdf; do
    $ADB push "tests/data/$f" "$DIR/" > /dev/null
done

close
launch '{}'
sleep 6
shot 01-library

# As Files and Email open a document. luna-appmanager answers false while
# it launches it (its launch hands over to SAM and returns no process id).
awake
sh_ "luna-send -n 1 -w 8000 luna://com.palm.applicationManager/open '{\"target\":\"file://$DIR/tracemonkey.pdf\"}' > /dev/null 2>&1"
sleep "$WAIT"
shot 02-opened-from-files

close
launch "{\"target\":\"$DIR/guide.pdf\"}"
sleep "$WAIT"
shot 03-reading
touch_ tap $((W / 2)) $((H * 6 / 10)); sleep 1.3
shot 04-full-screen
touch_ tap $((W / 2)) $((H * 6 / 10)); sleep 1.3
touch_ doubletap $((W / 3)) $((H * 3 / 10)); sleep 2.5
shot 05-double-tap
touch_ doubletap $((W / 3)) $((H * 3 / 10)); sleep 2
# Well inside the window: from its edges the shell takes a swipe.
touch_ swipe $((W / 2)) $((H * 65 / 100)) $((W / 2)) $((H * 35 / 100)) 200; sleep 2.5
shot 06-flicked
touch_ tap $((W / 2)) $((H * 6 / 10)); sleep 1.3
# The command menu: contents at its left end, the page key in the middle.
# Found in the screenshot: the dark grey rows at the foot of the window,
# above the gesture strip (black) where the device has one.
shot 06b-bars
BAR_Y=$(python3 -I -c '
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGB")
w, h = im.size
x = int(w * 0.18)
level = lambda y: max(im.getpixel((x, y)))
y = h - 1
while y > 0 and level(y) < 12:
    y -= 1
bottom = y
while y > 0 and 12 <= level(y) < 90:
    y -= 1
print((y + bottom) // 2)
' "$OUT/06b-bars.png")
rm -f "$OUT/06b-bars.png"
echo "   command menu at y=$BAR_Y"
touch_ tap 30 $BAR_Y; sleep 1.5
shot 07-contents
touch_ tap $((W - 30)) $((H / 2)); sleep 1.5
touch_ tap $((W / 2)) $BAR_Y; sleep 1.5
shot 08-go-to-page
sh_ "luna-send -n 1 -w 3000 luna://com.palm.display/control/notifyUserActivity '{}' > /dev/null 2>&1"
close

launch "{\"target\":\"$DIR/locked.pdf\"}"
sleep "$WAIT"
shot 09-password
close
