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

import LunaNext.Common 0.1
import LuneOS.Components 1.0

/*
 * A toolbar key with a picture from qml/images ("<image>.svg"), drawn
 * sharp at its size by LuneOS.Components' ArtworkImage, on the style's
 * toolbar button (dark, lit while held or checked). With plain it has no
 * button behind it: for the light header.
 *
 * At least 54 px across, the legacy guidelines' smallest touch target.
 */
ToolButton {
    id: button

    property string image
    property bool plain: false
    // The picture's share of the button.
    property real iconSize: Units.gu(3)

    implicitWidth: Math.max(Units.gu(6), 54)
    implicitHeight: Math.max(Units.gu(5), 54)
    padding: 0
    focusPolicy: Qt.NoFocus

    contentItem: Item {
        ArtworkImage {
            anchors.centerIn: parent
            width: button.iconSize
            height: button.iconSize
            svg: button.image ? Qt.resolvedUrl("../images/" + button.image + ".svg") : ""
            opacity: button.enabled ? 1.0 : 0.35
        }
    }

    background: Rectangle {
        visible: !button.plain || button.pressed
        radius: Units.gu(0.6)
        color: button.plain ? "#30000000" : (button.pressed || button.checked ? "#1d1d1d" : "transparent")
        border.color: button.plain ? "transparent" : (button.pressed || button.checked ? "#0c0c0c" : "transparent")
    }
}
