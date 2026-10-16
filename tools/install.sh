#!/bin/bash
# Packs the app with a device build of its plugin into an ipk and installs
# it through com.webos.appInstallService, as Preware does: opkg with its own
# root (/media/cryptofs/apps), so system packages are left alone, and the
# app's bus permissions come from requiredPermissions in appinfo.json.
# For development; the recipe does the real install.
#
#   tools/install.sh <build dir> <adb serial> [sysroot]
#
# Build the plugin for the device's architecture first (tests/README.md).
# Until the image has poppler's Qt 6 library, give the sysroot it was built
# into: libpoppler-qt6 and the libpoppler it was built with go next to the
# plugin, which then needs -Wl,--disable-new-dtags -Wl,-rpath,'$ORIGIN'.
# The package says "Architecture: all" although it holds the plugin: the
# installer's opkg (/etc/palm/appinstalld/opkg.conf) takes nothing else.
set -e
cd "$(dirname "$0")/.."
BUILD=${1:?usage: tools/install.sh <build dir> <adb serial> [sysroot]}
SERIAL=${2:?usage: tools/install.sh <build dir> <adb serial> [sysroot]}
SYSROOT=${3:-}
ADB="adb -s $SERIAL"

ID=$(python3 -I -c 'import json; print(json.load(open("appinfo.json"))["id"])')
VERSION=$(python3 -I -c 'import json; print(json.load(open("appinfo.json"))["version"])')
PLUGIN=$BUILD/PdfViewerApp/libpdfviewer-qml.so
[ -f "$PLUGIN" ] || { echo "no plugin at $PLUGIN"; exit 1; }

WORK=$BUILD/ipk
rm -rf "$WORK"
APP=$WORK/data/usr/palm/applications/$ID
mkdir -p "$WORK/control" "$APP/PdfViewerApp"
cp -r appinfo.json icon.png icon-256x256.png qml "$APP/"
cp "$PLUGIN" PdfViewerApp/qmldir "$APP/PdfViewerApp/"
if [ -n "$SYSROOT" ]; then
    cp -L "$SYSROOT/usr/lib/libpoppler-qt6.so.3" "$SYSROOT/usr/lib/libpoppler.so.155" "$APP/PdfViewerApp/"
fi

cat > "$WORK/control/control" <<CONTROL
Package: $ID
Version: $VERSION
Section: misc
Priority: optional
Architecture: all
Installed-Size: $(du -sk "$WORK/data" | cut -f1)
Maintainer: Herman van Hazendonk <github.com@herrie.org>
Description: PDF Viewer
 Reads the PDF documents on the device.
webOS-Package-Format-Version: 2
webOS-Packager-Version: x.y.x
CONTROL

echo "2.0" > "$WORK/debian-binary"
TAROPTS="--owner=0 --group=0 --numeric-owner --sort=name"
tar $TAROPTS -czf "$WORK/control.tar.gz" -C "$WORK/control" ./control
tar $TAROPTS -czf "$WORK/data.tar.gz" -C "$WORK/data" ./usr
IPK=${ID}_${VERSION}_all.ipk
rm -f "$BUILD/$IPK"
(cd "$WORK" && ar rc "../$IPK" debian-binary control.tar.gz data.tar.gz)

$ADB push "$BUILD/$IPK" /tmp/ >/dev/null
# luna-send prints nothing on an adb pipe; results go through a file.
$ADB shell "luna-send -w 90000 -i luna://com.webos.appInstallService/install '{\"id\":\"$ID\",\"ipkUrl\":\"/tmp/$IPK\",\"subscribe\":true}' > /tmp/pdf-inst.out 2>&1 & P=\$!; \
    for i in \$(seq 1 60); do sleep 1; grep -qE '\"installed\"|failed|errorCode' /tmp/pdf-inst.out && break; done; kill \$P 2>/dev/null; \
    rm -f /tmp/$IPK; grep -oE '\"state\":\"installed\"|errorText\":\"[^\"]*\"' /tmp/pdf-inst.out | tail -n 1"
