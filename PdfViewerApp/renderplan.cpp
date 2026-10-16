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

#include "renderplan.h"

#include <QStringList>

#include <algorithm>
#include <cmath>

namespace {

bool toInt(const QString &text, int *value)
{
    bool ok = false;
    const int v = text.toInt(&ok);
    if (ok)
        *value = v;
    return ok;
}

} // namespace

std::optional<PageRequest> PageRequest::parse(const QString &id)
{
    const QStringList parts = id.split(QLatin1Char('/'));
    if (parts.size() != 5 && parts.size() != 6)
        return std::nullopt;

    PageRequest request;
    request.documentId = parts.at(0);
    if (request.documentId.isEmpty())
        return std::nullopt;

    int night = 0;
    if (!toInt(parts.at(1), &request.page) || !toInt(parts.at(2), &request.width)
        || !toInt(parts.at(3), &request.rotation) || !toInt(parts.at(4), &night))
        return std::nullopt;
    if (request.page < 0 || request.width <= 0 || request.width > MaxRequestWidth)
        return std::nullopt;
    if (request.rotation != 0 && request.rotation != 90 && request.rotation != 180 && request.rotation != 270)
        return std::nullopt;
    if (night != 0 && night != 1)
        return std::nullopt;
    request.night = night == 1;

    if (parts.size() == 6) {
        const QStringList crop = parts.at(5).split(QLatin1Char(','));
        int x = 0, y = 0, w = 0, h = 0;
        if (crop.size() != 4 || !toInt(crop.at(0), &x) || !toInt(crop.at(1), &y) || !toInt(crop.at(2), &w)
            || !toInt(crop.at(3), &h))
            return std::nullopt;
        if (x < 0 || y < 0 || w <= 0 || h <= 0)
            return std::nullopt;
        request.crop = QRect(x, y, w, h);
    }
    return request;
}

std::optional<RenderPlan> RenderPlan::make(const QSizeF &pageSize, int rotation, int width, const QRect &crop,
                                           qint64 maxPixels)
{
    if (!(pageSize.width() > 0.0) || !(pageSize.height() > 0.0) || width <= 0 || maxPixels <= 0)
        return std::nullopt;

    const bool sideways = rotation == 90 || rotation == 270;
    const double shownWidth = sideways ? pageSize.height() : pageSize.width();
    const double shownHeight = sideways ? pageSize.width() : pageSize.height();

    RenderPlan plan;
    plan.dpi = 72.0 * width / shownWidth;
    const QRect whole(0, 0, width, std::max(1, static_cast<int>(std::lround(shownHeight * plan.dpi / 72.0))));
    plan.area = crop.isNull() ? whole : crop.intersected(whole);
    if (plan.area.isEmpty())
        return std::nullopt;

    const qint64 pixels = static_cast<qint64>(plan.area.width()) * plan.area.height();
    if (pixels > maxPixels) {
        const double factor = std::sqrt(static_cast<double>(maxPixels) / static_cast<double>(pixels));
        plan.dpi *= factor;
        // Rounded down, so the reduced area stays within the budget.
        const int x = static_cast<int>(std::floor(plan.area.x() * factor));
        const int y = static_cast<int>(std::floor(plan.area.y() * factor));
        const int w = std::max(1, static_cast<int>(std::floor(plan.area.width() * factor)));
        const int h = std::max(1, static_cast<int>(std::floor(plan.area.height() * factor)));
        plan.area = QRect(x, y, w, h);
        plan.reduced = true;
    }
    return plan;
}
