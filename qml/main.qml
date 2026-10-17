/*
 * (c) 2026 Herman van Hazendonk <github.com@herrie.org>
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 3, as published
 * by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranties of
 * MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
 * PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.LuneOS 2.0

import Eos.Window 0.1
import LunaNext.Common 0.1
import LuneOS.Service 1.0
import LuneOS.System 1.0
import LuneOS.Forms 1.0

import PdfViewerApp 1.0

import "js/Library.js" as Library

/*
 * PDF Viewer: the documents on the device, and a reader for them.
 *
 * Not LuneOS.Forms' AppWindow: its header always takes the top of the
 * window, and the reader wants all of it, with the bars over the page and
 * out of the way while reading. Each page draws its own AppHeader instead.
 *
 * Opened with {"target": "<path or file: URL>"} - by Files, Email, the
 * browser's downloads (appinfo.json's mimeTypes) - it shows that document.
 */
WebOSWindow {
    id: appWindow

    title: "PDF Viewer"
    width: Settings.displayWidth
    height: Settings.displayHeight
    visible: true
    color: Colors.pageBackground
    windowType: "_WEBOS_WINDOW_TYPE_CARD"

    // The settings apps' header, less of it where the screen has little to
    // spare (AppWindow's rule).
    readonly property real headerHeight: (height < Units.gu(70) || width < Units.gu(50)) ? Units.gu(7.5)
                                                                                     : Units.gu(10)
    readonly property bool compact: width < Units.gu(50)
    readonly property url appIcon: Qt.resolvedUrl("../icon.png")

    property alias prefs: preferences
    property alias reading: readingStore
    property alias scanner: fileScanner
    readonly property alias pageStack: stack

    // Says what went wrong, at the top of the library, until dismissed.
    property string notice: ""

    PreferencesModel {
        id: preferences
    }

    ReadingStore {
        id: readingStore
    }

    FileScanner {
        id: fileScanner
    }

    // Documents come and go over USB and from downloads while the app is in
    // the background: look again on coming back.
    Connections {
        target: Qt.application
        function onStateChanged() {
            if (Qt.application.state === Qt.ApplicationActive)
                fileScanner.rescan();
        }
    }

    LunaService {
        id: service
        name: "org.webosports.app.pdf"
    }

    // Needs "application.launcher" and "appmanager.management".
    AppLauncher {
        id: launcher
        clientName: "org.webosports.app.pdf"
    }

    // A web link from a document, in whatever handles it (the browser).
    function openUrl(url) {
        service.call("luna://com.palm.applicationManager/open", JSON.stringify({ "target": url }),
                     undefined, function(error) { appWindow.notice = "Could not open " + url + "."; });
    }

    // A new e-mail with the document attached (com.palm.app.email's
    // "newEmail" launch parameter).
    function sendByEmail(path) {
        launcher.launch("com.palm.app.email", {
            "newEmail": {
                "summary": Library.displayName(path),
                "attachments": [{ "fullPath": path, "mimeType": "application/pdf" }]
            }
        }, undefined, function(error) { appWindow.notice = "Could not open Email: " + error; });
    }

    // Shows a document: in the reader that is open, or a new one.
    function openDocument(target) {
        var path = Library.localPath(target);
        if (path === "") {
            notice = "Only documents on this device can be opened: " + target;
            return;
        }
        var viewer = stack.find(function(item) { return item.objectName === "viewerPage"; });
        if (viewer) {
            stack.pop(viewer, StackView.Immediate);
            viewer.source = path;
        } else {
            stack.push(Qt.resolvedUrl("ViewerPage.qml"), { "source": path });
        }
    }

    function showDocumentInfo(document) {
        stack.push(Qt.resolvedUrl("DocumentInfoPage.qml"), { "document": document });
    }

    LaunchParams {
        window: appWindow
        onLaunched: function(params) {
            if (typeof params.target === "string" && params.target !== "")
                appWindow.openDocument(params.target);
        }
        onAppMenuRequested: appWindow.openAppMenu()
    }

    // Each page fills the app menu with its own commands (appMenuItems); the
    // menu drops from the top of the window, as in every app.
    function openAppMenu() {
        var items = stack.currentItem && stack.currentItem.appMenuItems ? stack.currentItem.appMenuItems() : [];
        for (var i = 0; i < items.length; ++i) {
            var entry = items[i];
            var item = menuItem.createObject(null, {
                "text": entry.text,
                "enabled": entry.enabled !== false,
                "checkable": entry.checked !== undefined,
                "checked": entry.checked === true
            });
            item.triggered.connect(entry.action);
            appMenu.addItem(item);
        }
        if (appMenu.count > 0)
            appMenu.popup(0, 0);
    }

    Component {
        id: menuItem
        MenuItem { }
    }

    Menu {
        id: appMenu
        objectName: "appMenu"
        LuneOSMenu.appMenuStyle: true
        // Items made for one opening are thrown away at the next.
        onClosed: Qt.callLater(function() {
            for (var i = appMenu.count - 1; i >= 0; --i) {
                var item = appMenu.itemAt(i);
                appMenu.removeItem(item);
                item.destroy();
            }
        })
    }

    StackView {
        id: stack

        anchors.fill: parent
        focus: true
        initialItem: Qt.resolvedUrl("LibraryPage.qml").toString()

        // The back gesture arrives as Escape (see LunaNext.Common's
        // EventType). A page gets it first to close what it has open - the
        // search, the contents - and the stack pops otherwise.
        Keys.onReleased: function(event) {
            if (event.key !== Qt.Key_Escape)
                return;
            if (stack.currentItem && stack.currentItem.handleBack && stack.currentItem.handleBack()) {
                event.accepted = true;
            } else if (stack.depth > 1) {
                stack.pop();
                event.accepted = true;
            }
        }
    }
}
