PDF Viewer
==========

Reads the PDF documents on the device, and any that other apps hand it
(Files, Email, the browser's downloads), on every LuneOS form factor:
tablet, tall phone, small phone and the square Q25.

A QML app in the LuneOS style (LuneOS.Components, LuneOS.Forms), drawing
pages with poppler's Qt 6 library on two threads of their own. It replaces
the Enyo 2 app with pdf.js 1.3 that was here before: that one found no
documents on a device (it asked db8 for `com.palm.media.misc.file`, which
the media indexer never fills), drew one page at a time on the GUI thread,
and was not registered for PDF files.

On a device
-----------

A mindphone (480x800, a keypad) running `tools/device-test.sh`: the
library, a paper opened from Files, its contents, and a protected document
asking for its password over the keyboard.

<table>
  <tr>
    <td align="center"><img src="docs/screenshots/device-mindphone-library.png" height="320" alt="Library"></td>
    <td align="center"><img src="docs/screenshots/device-mindphone-opened-from-files.png" height="320" alt="Opened from Files"></td>
    <td align="center"><img src="docs/screenshots/device-mindphone-contents.png" height="320" alt="Contents"></td>
    <td align="center"><img src="docs/screenshots/device-mindphone-password.png" height="320" alt="Password"></td>
  </tr>
  <tr>
    <td align="center"><sub>Library</sub></td>
    <td align="center"><sub>Opened from Files</sub></td>
    <td align="center"><sub>Contents</sub></td>
    <td align="center"><sub>Password</sub></td>
  </tr>
</table>

On every form factor
--------------------

The same screens on the four screens the QML tests run the app on
(`tests/run-qml-tests.sh`, with luneos-components' desktop stand-ins, so
the fonts are the build host's rather than Prelude).

<table>
  <tr>
    <th></th>
    <th>HP TouchPad<br><sub>1024×768</sub></th>
    <th>Galaxy Nexus<br><sub>720×1280</sub></th>
    <th>mindphone<br><sub>480×800</sub></th>
    <th>Q25<br><sub>720×720</sub></th>
  </tr>
  <tr>
    <th align="left">Library<br><sub>Every PDF on the device, the last five read with how far</sub></th>
    <td align="center"><img src="docs/screenshots/tp-library-recent.png" height="200" alt="Library on HP TouchPad"></td>
    <td align="center"><img src="docs/screenshots/gnex-library-recent.png" height="200" alt="Library on Galaxy Nexus"></td>
    <td align="center"><img src="docs/screenshots/mindphone-library-recent.png" height="200" alt="Library on mindphone"></td>
    <td align="center"><img src="docs/screenshots/q25-library-recent.png" height="200" alt="Library on Q25"></td>
  </tr>
  <tr>
    <th align="left">Reading<br><sub>Pages one under the other, fit to width or to the page</sub></th>
    <td align="center"><img src="docs/screenshots/tp-viewer.png" height="200" alt="Reading on HP TouchPad"></td>
    <td align="center"><img src="docs/screenshots/gnex-viewer.png" height="200" alt="Reading on Galaxy Nexus"></td>
    <td align="center"><img src="docs/screenshots/mindphone-viewer.png" height="200" alt="Reading on mindphone"></td>
    <td align="center"><img src="docs/screenshots/q25-viewer.png" height="200" alt="Reading on Q25"></td>
  </tr>
  <tr>
    <th align="left">Contents<br><sub>The document's own outline</sub></th>
    <td align="center"><img src="docs/screenshots/tp-contents.png" height="200" alt="Contents on HP TouchPad"></td>
    <td align="center"><img src="docs/screenshots/gnex-contents.png" height="200" alt="Contents on Galaxy Nexus"></td>
    <td align="center"><img src="docs/screenshots/mindphone-contents.png" height="200" alt="Contents on mindphone"></td>
    <td align="center"><img src="docs/screenshots/q25-contents.png" height="200" alt="Contents on Q25"></td>
  </tr>
  <tr>
    <th align="left">Pages<br><sub>Every page small, to jump to</sub></th>
    <td align="center"><img src="docs/screenshots/tp-pages.png" height="200" alt="Pages on HP TouchPad"></td>
    <td align="center"><img src="docs/screenshots/gnex-pages.png" height="200" alt="Pages on Galaxy Nexus"></td>
    <td align="center"><img src="docs/screenshots/mindphone-pages.png" height="200" alt="Pages on mindphone"></td>
    <td align="center"><img src="docs/screenshots/q25-pages.png" height="200" alt="Pages on Q25"></td>
  </tr>
  <tr>
    <th align="left">Find<br><sub>Every match marked, the current one stronger</sub></th>
    <td align="center"><img src="docs/screenshots/tp-find.png" height="200" alt="Find on HP TouchPad"></td>
    <td align="center"><img src="docs/screenshots/gnex-find.png" height="200" alt="Find on Galaxy Nexus"></td>
    <td align="center"><img src="docs/screenshots/mindphone-find.png" height="200" alt="Find on mindphone"></td>
    <td align="center"><img src="docs/screenshots/q25-find.png" height="200" alt="Find on Q25"></td>
  </tr>
  <tr>
    <th align="left">Copy<br><sub>Touch and hold a word, drag the handles</sub></th>
    <td align="center"><img src="docs/screenshots/tp-selection.png" height="200" alt="Copy on HP TouchPad"></td>
    <td align="center"><img src="docs/screenshots/gnex-selection.png" height="200" alt="Copy on Galaxy Nexus"></td>
    <td align="center"><img src="docs/screenshots/mindphone-selection.png" height="200" alt="Copy on mindphone"></td>
    <td align="center"><img src="docs/screenshots/q25-selection.png" height="200" alt="Copy on Q25"></td>
  </tr>
  <tr>
    <th align="left">Go to Page<br><sub>By number, or with a slider that shows the document's labels</sub></th>
    <td align="center"><img src="docs/screenshots/tp-goto.png" height="200" alt="Go to Page on HP TouchPad"></td>
    <td align="center"><img src="docs/screenshots/gnex-goto.png" height="200" alt="Go to Page on Galaxy Nexus"></td>
    <td align="center"><img src="docs/screenshots/mindphone-goto.png" height="200" alt="Go to Page on mindphone"></td>
    <td align="center"><img src="docs/screenshots/q25-goto.png" height="200" alt="Go to Page on Q25"></td>
  </tr>
  <tr>
    <th align="left">Password<br><sub>Asked for, and again if it does not open</sub></th>
    <td align="center"><img src="docs/screenshots/tp-password.png" height="200" alt="Password on HP TouchPad"></td>
    <td align="center"><img src="docs/screenshots/gnex-password.png" height="200" alt="Password on Galaxy Nexus"></td>
    <td align="center"><img src="docs/screenshots/mindphone-password.png" height="200" alt="Password on mindphone"></td>
    <td align="center"><img src="docs/screenshots/q25-password.png" height="200" alt="Password on Q25"></td>
  </tr>
  <tr>
    <th align="left">Night mode, turned<br><sub>Light on dark; turned a quarter</sub></th>
    <td align="center"><img src="docs/screenshots/tp-turned-night.png" height="200" alt="Night mode, turned on HP TouchPad"></td>
    <td align="center"><img src="docs/screenshots/gnex-turned-night.png" height="200" alt="Night mode, turned on Galaxy Nexus"></td>
    <td align="center"><img src="docs/screenshots/mindphone-turned-night.png" height="200" alt="Night mode, turned on mindphone"></td>
    <td align="center"><img src="docs/screenshots/q25-turned-night.png" height="200" alt="Night mode, turned on Q25"></td>
  </tr>
  <tr>
    <th align="left">Document Info<br><sub>Title, author, dates, producer, protection</sub></th>
    <td align="center"><img src="docs/screenshots/tp-info.png" height="200" alt="Document Info on HP TouchPad"></td>
    <td align="center"><img src="docs/screenshots/gnex-info.png" height="200" alt="Document Info on Galaxy Nexus"></td>
    <td align="center"><img src="docs/screenshots/mindphone-info.png" height="200" alt="Document Info on mindphone"></td>
    <td align="center"><img src="docs/screenshots/q25-info.png" height="200" alt="Document Info on Q25"></td>
  </tr>
</table>

Features
--------

### Finding a document

- **Library:** every `*.pdf` under `/media/internal` (USB copies,
  downloads), found on a worker thread and again whenever the app comes
  back to the front, each with its first page as its picture (kept in the
  cache directory, so a document is opened once for it).
- **Recent:** the last five read, with how far.
- Sort by name (numbers by value), date or size; a search box once there
  are six or more. Touch and hold for Open, Send by Email, Remove from
  Recent.
- **Opened from other apps:** appinfo.json's `mimeTypes` registers the app
  for `application/pdf`; `{"target": "<path or file: URL>"}` opens that
  document, in the reader already open.

### Reading

- The pages one under the other, scrolled as one, centred; each page fits
  the width, or the whole page fits the screen (the key at the right of
  the command menu).
- **Pinch** or **Ctrl+wheel** to zoom about the fingers, **double tap** to
  zoom in there and again to fit. Zoomed in past what a whole page can be
  drawn at, the part on screen is drawn sharp over it.
- Pages are drawn on two threads as they come into view, and a page
  scrolled past stops drawing.
- **Full screen:** a tap hides the header and the command menu (the legacy
  Full Screen Mode), another brings them back; scrolling hides them too.
  While they are away, a bubble says which page.
- **Where the reader was** (page, how far down it, zoom, turn) is kept per
  document and restored on opening it again.
- **Night mode:** the pages inverted, light on dark. **Rotate** clockwise
  or counterclockwise.

### Getting around

- **Command menu:** contents, page before, which page, page after, fit
  width / fit page.
- **Go to Page** (tap the page key): by number, or with a slider that shows
  the document's own labels ("xii"). On a keypad the field takes digits.
- **Contents:** the document's outline, and every page small, from the
  left.
- **Find:** every match highlighted, the current one stronger; "3 of 17",
  the one before and after, from the page being read on. Case and accents
  ignored, across line ends.
- **Links:** to a page (with "Back to page …" to return), and to the web
  (asked first, then opened by the browser).
- The back gesture closes what is open first (the selection, the contents,
  find), then goes back to the library. The header's Back does the same for
  devices without a gesture area.

### And

- **Copy:** touch and hold a word; drag the handles over more; Copy. Not in
  a document that forbids it.
- **Passwords:** asked for, and asked again when one does not open the
  document. Kept nowhere. Typed in T9 on a keypad, the last letter counts
  too.
- **Dialogs** (password, Go to Page, opening a web link) are
  LuneOS.Components' own, kept above the on-screen keyboard; the key that
  accepts is green.
- **App menu** (and the header's "…"): Go to Page, Find, Rotate, Night
  Mode, Send by Email, Document Info.
- **Document Info:** title, author, subject, keywords, pages, dates, the
  program and PDF version, protection, the file.

Building
--------

The app needs poppler with its Qt 6 frontend: poppler's `qt6`
PACKAGECONFIG (meta-webos-ports enables it for this app). It also needs a
luneos-components with ArtworkImage (88cdc3e or later): on an image with
an older one its pages cannot be made, and the window stays empty. With the webOS
CMake modules (the recipe) it installs to the applications directory with
its luna-service2 role and permissions; without them (a desktop build) under
the build tree.

    cmake -S . -B build -G Ninja && ninja -C build

The QML is installed as it is; the plugin (`PdfViewerApp/`) is the C++:

- `DocumentRegistry` - the documents open, by an id that stands for them in
  image URLs, and the threads. A poppler document must not be used from two
  threads at once, so each user leases a copy of its own.
- `PdfDocument` - opens a document on a worker; sizes, labels, the outline,
  links, text, the word under a finger, metadata, the password.
- `PageImageProvider` (`image://pdfpage/`), `ThumbnailImageProvider`
  (`image://pdfthumb/`) - pages and parts of pages, and the library's
  pictures, drawn on the render threads and cancelled when no longer
  wanted; `RenderPlan` keeps a page within a pixel budget.
- `DocumentSearch` - the search, page by page on a worker.
- `FileScanner` - the library's documents.

Tests
-----

See [tests/README.md](tests/README.md): unit tests for the C++ (gtest),
QML tests for the helpers and for the app on four screens (1024x768,
720x1280, 480x800, 720x720), static analysis, sanitizers, valgrind and the
six builds (GCC and Clang for armv7, aarch64 and x86-64), and the run on
a mindphone and an HP TouchPad.

License
-------

GPL version 3, see COPYING. poppler, which draws the pages, is GPL as well.
