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

#ifndef PDFVIEWERAPP_RENDERPLAN_H
#define PDFVIEWERAPP_RENDERPLAN_H

#include <QRect>
#include <QSizeF>
#include <QString>

#include <optional>

/*
 * What QML asks the page provider for, from the part of the image URL after
 * "image://pdfpage/":
 *
 *     <document id>/<page>/<width>/<rotation>/<night>[/<x>,<y>,<w>,<h>]
 *
 * page from 0; width in pixels of the whole page as shown (turned); rotation
 * 0, 90, 180 or 270; night 1 for inverted colours; and the optional part of
 * that whole page to draw, in its pixels - the sharp detail over a page
 * zoomed in too far to render whole.
 */
struct PageRequest
{
    QString documentId;
    int page = -1;
    int width = 0;
    int rotation = 0;
    bool night = false;
    QRect crop;

    static std::optional<PageRequest> parse(const QString &id);
};

/*
 * How poppler is to draw a request: the resolution, and the area of the
 * page at that resolution. A request over the pixel budget is drawn
 * smaller - the same area, scaled down - and shown stretched.
 */
struct RenderPlan
{
    double dpi = 72.0;
    QRect area;
    bool reduced = false;

    // pageSize in points as the page is stored, before turning.
    static std::optional<RenderPlan> make(const QSizeF &pageSize, int rotation, int width,
                                          const QRect &crop, qint64 maxPixels);
};

// The largest width a request may ask for, and the most pixels drawn at once
// (12 megapixels: 48 MB, the most a 1 GB armv7 device should give one page).
constexpr int MaxRequestWidth = 32768;
constexpr qint64 MaxRenderPixels = 12 * 1000 * 1000;

#endif // PDFVIEWERAPP_RENDERPLAN_H
