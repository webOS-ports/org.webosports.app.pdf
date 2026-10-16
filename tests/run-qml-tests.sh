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
set -e
cd "$(dirname "$0")/.."
BUILD=${1:?usage: run-qml-tests.sh <plugin build dir> [luneos-components [args]]}
shift
LC=${1:-../luneos-components}
[ $# -gt 0 ] && shift
CONF=$(mktemp -d)
trap 'rm -rf "$CONF"' EXIT
mkdir -p build/test-output/ui
# The preferences, the reading positions and the caches go to a throwaway
# directory, not the user's.
XDG_CONFIG_HOME=$CONF XDG_CACHE_HOME=$CONF/cache QT_QPA_PLATFORM=${QT_QPA_PLATFORM:-offscreen} \
QT_QUICK_CONTROLS_STYLE=QtQuick.Controls.LuneOS \
    ${QMLTESTRUNNER:-/usr/lib/qt6/bin/qmltestrunner} \
    -import "$BUILD" -import "$LC/modules" -import "$LC/test/imports" \
    -input tests/qml "$@"
