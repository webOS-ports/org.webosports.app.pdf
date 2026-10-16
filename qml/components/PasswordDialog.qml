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
import QtQuick.Layouts
import QtQuick.Controls.LuneOS 2.0

import LunaNext.Common 0.1
import LuneOS.Forms 1.0

/*
 * The password of a protected document. Kept nowhere: asked each time.
 */
Dialog {
    id: dialog

    property string fileName
    // Asked again after a wrong one.
    property bool wrong: false

    signal passwordEntered(string password)

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(parent ? parent.width - Units.gu(4) : Units.gu(45), Units.gu(45))
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape
    title: "Password"
    standardButtons: Dialog.Open | Dialog.Cancel

    onAboutToShow: {
        field.text = "";
        field.forceActiveFocus();
    }

    onAccepted: passwordEntered(field.text)

    ColumnLayout {
        anchors.fill: parent
        spacing: Units.gu(1)

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: dialog.wrong ? "That password is not right. Try again."
                               : "“" + dialog.fileName + "” is protected by a password."
            color: dialog.wrong ? Colors.error : Colors.text
        }

        TextField {
            id: field
            objectName: "passwordField"
            Layout.fillWidth: true
            echoMode: TextInput.Password
            inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
            onAccepted: dialog.accept()
        }
    }
}
