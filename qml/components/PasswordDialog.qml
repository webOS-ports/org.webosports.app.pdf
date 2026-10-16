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

import LunaNext.Common 0.1
import LuneOS.Components 1.0

/*
 * The password of a protected document, in the platform's dialog (as
 * PromptDialog: a line to type in, then the green key and Cancel). Kept
 * nowhere: asked each time.
 */
KeyboardClearDialog {
    id: dialog

    property string fileName
    // Asked again after a wrong one.
    property bool wrong: false

    signal passwordEntered(string password)
    signal rejected()

    function accept() {
        close();
        passwordEntered(typedText(field));
    }

    function reject() {
        close();
        rejected();
    }

    title: "Password"
    // Not "wrong password": the guidelines ask for no negative phrasing.
    message: wrong ? "Try the password for “" + fileName + "” again."
                   : "“" + fileName + "” is protected by a password."
    dialogWidth: Units.gu(30)
    dialogHeight: Units.gu(23.5)

    onAboutToShow: {
        field.text = "";
        padField(field);
        var input = inputOf(field);
        if (input) {
            // A dot Prelude has (the default one is not in it, and nothing
            // showed), and no capitals or guesses in a password.
            input.passwordCharacter = "\u2022";
            input.inputMethodHints = Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                    | Qt.ImhNoAutoUppercase | Qt.ImhPreferLowercase;
            Qt.callLater(function() { input.forceActiveFocus(); });
        }
    }

    // DialogLineInput sits 2 units above the middle of its row, so a row
    // this short puts it just over the keys, at the same gap as between them.
    Row {
        height: Units.gu(2)
        DialogLineInput {
            id: field
            objectName: "passwordField"
            echoMode: TextInput.Password
            onAccepted: dialog.accept()
        }
    }
    Row {
        DialogButton {
            objectName: "passwordOpenButton"
            text: "Open"
            // The green of an accepting key (LuneOSButton.affirmativeColor).
            color: "#2aa100"
            fontcolor: "white"
            buttonWidth: Units.gu(26)
            onClicked: dialog.accept()
        }
    }
    Row {
        DialogButton {
            objectName: "passwordCancelButton"
            text: "Cancel"
            color: "transparent"
            fontcolor: "#444444"
            buttonWidth: Units.gu(26)
            onClicked: dialog.reject()
        }
    }
}
