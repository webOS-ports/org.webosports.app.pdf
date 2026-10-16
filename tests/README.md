# PDF Viewer tests

## Test documents (`data/`)

- `guide.pdf`, `locked.pdf`: made by `data/make-test-pdfs.sh` with
  Ghostscript. 12 pages labelled i, ii, 1-10, page 7 landscape; a nested
  outline; on page i a link to page 9 and one to https://webos-ports.org/,
  on page ii one into another file (not followed); "lunar" four times (pages
  3, 5 twice, 9). `locked.pdf` is the same with the user password `secret`.
- `helloworld.pdf`, `tracemonkey.pdf`: the old app's samples (one page; 14
  pages, a paper with no labels).

## Builds and sysroots

No recipe sysroot has poppler's Qt 6 library (the image's poppler had its
`qt6` PACKAGECONFIG off), so the tests build against sysroots put together
from a LuneOS build's sysroot components, with poppler-qt6 25.12.0 - the
image's release, from the build's downloads - built into each:

    tests/host-sysroot.sh <TMPDIR> <dir>/sysroot-x86_64
    tests/host-sysroot.sh <TMPDIR> <dir>/sysroot-aarch64 aarch64
    tests/host-sysroot.sh <TMPDIR> <dir>/sysroot-armv7 cortexa8t2hf-neon cortexa8t2hf-neon-halium
    tests/build-poppler.sh <TMPDIR> <dir>/sysroot-<arch> <x86_64|aarch64|armv7> <Qt host dir>/usr <work dir>

The armv7 sysroot is the non-halium components (their GLES is mesa) with
qtdeclarative from the -halium ones: the other was only half staged. Both
are Qt 6.12.0.

## Unit tests (`unit/`), gtest

`RenderPlan`/`PageRequest` (image URLs refused when they cannot be drawn,
turned pages, parts, the pixel budget), `DocumentRegistry` (leases go back
and are reused, ids never reused, a lease outliving its document, four
threads at once, why a document does not load), `PdfDocument` (metadata,
sizes, labels both ways, the outline, links - not into other files -, text
and the word under a finger, the clipboard, passwords, damaged and missing
files, a newer source winning over one still loading, destroyed while
loading), `DocumentSearch` (page order, from the reader's page round,
case, whole words, nothing from a search replaced), `FileScanner` (hidden
folders, symlinks, depth, numbers by value), page drawing (size, turned,
night, parts, cancelled) and the thumbnail cache.

    cmake -S . -B build/x86 -G Ninja -DBUILD_TESTING=ON \
        -DCMAKE_TOOLCHAIN_FILE=tests/host-toolchain.cmake \
        -DTEST_SYSROOT=<dir>/sysroot-x86_64 -DQT_HOST_PATH=<Qt host dir>/usr
    ninja -C build/x86
    QT_QPA_PLATFORM=offscreen QT_PLUGIN_PATH=<sysroot>/usr/lib/plugins \
        <sysroot>/usr/lib/ld-linux-x86-64.so.2 --library-path <sysroot>/usr/lib build/x86/tests/pdfviewer-tests

41 tests, passing. Mutation-checked: without the pixel budget, with leased
copies never reused, labels not looked up or never noticed, case always
ignored, symlinks followed, no depth limit, night not inverted, a stale load
or stale matches accepted, links into other files kept, empty text copied,
any turn accepted, the cache never pruned, the farthest word taken, and the
search not wrapping round, a test fails each time.

## QML tests (`qml/`), on the build host

    tests/run-qml-tests.sh <host plugin build> <luneos-components> [-import <dir>]

- `tst_geometry.qml`, `tst_library.qml`: `qml/js/Geometry.js` (turning
  rectangles and points every way round, fitting, links under a finger,
  render sizes) and `qml/js/Library.js` (paths, sizes, dates, search, the
  natural order, the reading store, Recent).
- `tst_ui.qml`: the app on the real plugin and the documents above, on four
  screens - `tp` 1024x768, `gnex` 720x1280, `mindphone` 480x800, `q25`
  720x720: the library and its pictures, opening, full screen and back,
  page keys, Go to Page by label, find (and a match never left under the
  find bar), links and back from them, the web link asking, the contents
  and the pages, turning, fit page, night, double tap zooming (and not
  counting as a tap), a password wrong then right, damaged, missing and
  remote documents, launch parameters reusing the reader, coming back where
  the reader left, copying a word (the copy bar clear of it), Document
  Info. Each state is saved to `build/test-output/ui/<profile>-<state>.png`.

The plugin has to be built for the host's Qt for these: a build against the
host Qt with poppler-qt6's headers from a sysroot and the host's
`libpoppler-qt6.so.3` (a `.pc` file pointing there). luneos-components
needs its desktop build with the LuneOS.Components plugin that has
`image://artwork` (the app's icons); a build of it made elsewhere goes ahead
of the checkout's with `-import`.

Mutation-checked: a wrong turn, Recent keeping gone files, back not closing
find, a tap not waiting for a double tap, a new reader per launch, no link
history, double tap not zooming, no Recent, find ignoring the find bar, the
copy bar over the word. Saving the position on leaving the reader is also
done when it is destroyed, so leaving out one of the two is not seen.

## Static analysis

    APP_SYSROOT=<dir>/sysroot-x86_64 tests/static-analysis.sh

gcc `-fanalyzer` at -O0 and -O2, the clang analyzer with the alpha
checkers, clang-tidy, cppcheck (exhaustive, inconclusive), flawfinder, and
Coccinelle with `cocci/`; all clean. sparse parses C only.

## Sanitizers and valgrind

The unit tests with GCC and Clang, `-fsanitize=address,undefined`, linked
with the sysroot's loader as interpreter and `-Wl,--disable-new-dtags
-Wl,-rpath,<sysroot>/usr/lib` (run through the loader instead, the
sanitizers take the test's own code for the loader's and cannot name it):
passing, no errors, no leaks.

`-fsanitize=thread` (GCC and Clang, under `setarch x86_64 -R`), one test per
process: passing, with reports that are all one thing - a worker thread
fills in a result and the GUI thread reads it in the call queued with
`QMetaObject::invokeMethod(..., Qt::QueuedConnection)`. The queue's mutex is
in libQt6Core, which is not built with TSan, so the order it gives is not
seen. A TSan-built Qt would be needed to go further. All tests in one
process end in TSan's own "CHECK failed" in its thread registry once a
QThread has ended unseen, for the same reason.

Valgrind memcheck, with `TEST_TIMEOUT_SCALE=20` (waits made longer for its
pace): passing, no errors, nothing definitely lost. Both found 2 KB lost in
`QString::localeAwareCompare()`'s per-thread collator, which Qt does not
free when a pool thread ends; the file scan uses a `QCollator` of its own
now.

## Six builds

    tests/build-matrix.sh <TMPDIR> <dir with the three sysroots> <Qt host dir>/usr <out dir>

GCC 15 (the build's 15.3 cross compilers for armv7 and aarch64, the host's
15.2 for x86-64) and Clang 21 for armv7, aarch64 and x86-64, with `-Wall
-Wextra -Wpedantic -Wshadow -Wnon-virtual-dtor -Wold-style-cast -Wcast-align
-Wformat=2`: no warnings, in the app's code or in Qt's and poppler's headers.

## On a device

    tools/install.sh <device build dir> <adb serial> <sysroot>
    WAIT=<seconds> tools/device-test.sh <adb serial> <name> <cross gcc> <sysroot> [cpu flags]

`install.sh` installs through com.webos.appInstallService, leaving system
packages alone. Until the image has poppler's Qt 6 library, the sysroot's
`libpoppler-qt6.so.3` and `libpoppler.so.155` go next to the plugin, which
is then linked with `-Wl,--disable-new-dtags -Wl,-rpath,'$ORIGIN'`.

`device-test.sh` builds `tools/touch.c` (static) to put fingers on the
screen - multi-touch protocol A or B, whichever the touch screen has - and
takes the app through the library, a document opened as Files opens one
(`applicationManager/open` with a `file:` target), full screen, double tap,
a flick, the contents, Go to Page and a password, with a screenshot of
each in `build/test-output/device/<name>/`. The test documents are removed
and the app's settings put back after.

Passed on the mindphone (armv7, 480x800, WAIT=5) and the HP TouchPad
(armv7, 1024x768, WAIT=9), 2026-10-16. Pinch was checked there too: two
injected fingers reach the app only a few times per gesture, but each pinch
that arrived zoomed and kept its zoom; how smooth it feels needs a real
hand. Also seen there: `luna://com.palm.applicationManager/open` answers
`returnValue: false` although it opens the document, because
luna-appmanager hands the launch to SAM and returns no process id
(`Src/remote/ApplicationProcessManager.cpp`, `launch()`).
