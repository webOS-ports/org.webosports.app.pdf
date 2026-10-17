#!/bin/sh
# Runs the QML tests on the build host: the helpers (tst_geometry.qml,
# tst_library.qml) and the app itself (tst_ui.qml), with the real plugin
# built for the host and luneos-components' desktop stand-ins.
#
#   tests/run-qml-tests.sh <plugin build dir> [path to luneos-components [qmltestrunner arguments]]
#
# The plugin build dir is a host build of this tree (see README.md: its
# PdfViewerApp/ holds the plugin and its qmldir). luneos-components needs
# its desktop build (CONFIG+=desktop) for the style and LuneOS.Components
# plugins. Screenshots of each state go to build/test-output/ui/.
#
# tst_ui runs once for each screen in PROFILES (by default the TouchPad,
# Galaxy Nexus, mindphone and Q25). The stand-ins read the profile, and
# with it the grid unit, once as they load - each JavaScript library keeps
# its own copy, so Settings.setProfile() in a test moves Settings and not
# Units or FontUtils - and qmltestrunner takes no --profile of its own. So
# each run imports a copy of LunaNext.Common whose default profile is that
# screen's.
set -e
cd "$(dirname "$0")/.."
BUILD=${1:?usage: run-qml-tests.sh <plugin build dir> [luneos-components [args]]}
shift
LC=${1:-../luneos-components}
[ $# -gt 0 ] && shift
PROFILES=${PROFILES:-tp gnex mindphone q25}
CONF=$(mktemp -d)
trap 'rm -rf "$CONF"' EXIT
mkdir -p build/test-output/ui

run() {
    XDG_CONFIG_HOME=$CONF/config XDG_CACHE_HOME=$CONF/cache QT_QPA_PLATFORM=${QT_QPA_PLATFORM:-offscreen} \
    QT_QUICK_CONTROLS_STYLE=QtQuick.Controls.LuneOS \
        ${QMLTESTRUNNER:-/usr/lib/qt6/bin/qmltestrunner} \
        -import "$BUILD" -import "$LC/modules" -import "$LC/test/imports" "$@"
}

status=0
run -input tests/qml/tst_geometry.qml "$@" || status=1
run -input tests/qml/tst_library.qml "$@" || status=1
for profile in $PROFILES; do
    common=$CONF/profile-$profile/LunaNext/Common
    mkdir -p "$common"
    cp "$LC"/test/imports/LunaNext/Common/* "$common/"
    sed -i "s/^var defaultProfile = .*/var defaultProfile = \"$profile\";/" "$common/SettingsStub.js"
    grep -q "^var defaultProfile = \"$profile\";" "$common/SettingsStub.js"
    rm -rf "$CONF/config" "$CONF/cache"
    run -import "$CONF/profile-$profile" -input tests/qml/tst_ui.qml "$@" || status=1
done
exit $status
