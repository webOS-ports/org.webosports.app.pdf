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


#include <gtest/gtest.h>

#include "renderplan.h"

TEST(PageRequest, ParsesAWholePage)
{
    const auto r = PageRequest::parse(QStringLiteral("d7/3/800/90/1"));
    ASSERT_TRUE(r);
    EXPECT_EQ(r->documentId, QStringLiteral("d7"));
    EXPECT_EQ(r->page, 3);
    EXPECT_EQ(r->width, 800);
    EXPECT_EQ(r->rotation, 90);
    EXPECT_TRUE(r->night);
    EXPECT_TRUE(r->crop.isNull());
}

TEST(PageRequest, ParsesAPart)
{
    const auto r = PageRequest::parse(QStringLiteral("d1/0/2000/0/0/10,20,300,400"));
    ASSERT_TRUE(r);
    EXPECT_EQ(r->crop, QRect(10, 20, 300, 400));
    EXPECT_FALSE(r->night);
}

TEST(PageRequest, RefusesWhatItCannotDraw)
{
    for (const char *id : { "", "d1", "d1/0/800/0", "/0/800/0/0", "d1/-1/800/0/0", "d1/0/0/0/0",
                            "d1/0/99999/0/0", "d1/0/800/45/0", "d1/0/800/0/2", "d1/x/800/0/0",
                            "d1/0/800/0/0/1,2,3", "d1/0/800/0/0/1,2,0,4", "d1/0/800/0/0/-1,2,3,4",
                            "d1/0/800/0/0/1,2,3,4/extra" }) {
        EXPECT_FALSE(PageRequest::parse(QString::fromLatin1(id))) << id;
    }
}

TEST(RenderPlan, AWholePageAtItsWidth)
{
    // A4 at 595 pixels wide is 72 dpi: 842 high.
    const auto plan = RenderPlan::make(QSizeF(595, 842), 0, 595, QRect(), MaxRenderPixels);
    ASSERT_TRUE(plan);
    EXPECT_DOUBLE_EQ(plan->dpi, 72.0);
    EXPECT_EQ(plan->area, QRect(0, 0, 595, 842));
    EXPECT_FALSE(plan->reduced);
}

TEST(RenderPlan, TurnedPagesSwapSides)
{
    // On its side the 842 point height is the width shown.
    const auto plan = RenderPlan::make(QSizeF(595, 842), 90, 842, QRect(), MaxRenderPixels);
    ASSERT_TRUE(plan);
    EXPECT_DOUBLE_EQ(plan->dpi, 72.0);
    EXPECT_EQ(plan->area, QRect(0, 0, 842, 595));
}

TEST(RenderPlan, APartStaysInsideThePage)
{
    const auto plan = RenderPlan::make(QSizeF(595, 842), 0, 1190, QRect(1000, 1500, 500, 500), MaxRenderPixels);
    ASSERT_TRUE(plan);
    EXPECT_EQ(plan->area, QRect(1000, 1500, 190, 184));
    EXPECT_FALSE(RenderPlan::make(QSizeF(595, 842), 0, 595, QRect(700, 0, 10, 10), MaxRenderPixels));
}

TEST(RenderPlan, OverTheBudgetIsDrawnSmaller)
{
    const qint64 budget = 1000 * 1000;
    const auto plan = RenderPlan::make(QSizeF(595, 842), 0, 5950, QRect(), budget);
    ASSERT_TRUE(plan);
    EXPECT_TRUE(plan->reduced);
    EXPECT_LE(static_cast<qint64>(plan->area.width()) * plan->area.height(), budget);
    // The same page, at a lower resolution.
    EXPECT_NEAR(plan->area.width() / 595.0 * 72.0, plan->dpi, 0.2);
}

TEST(RenderPlan, RefusesNoPage)
{
    EXPECT_FALSE(RenderPlan::make(QSizeF(0, 842), 0, 100, QRect(), MaxRenderPixels));
    EXPECT_FALSE(RenderPlan::make(QSizeF(595, 842), 0, 0, QRect(), MaxRenderPixels));
    EXPECT_FALSE(RenderPlan::make(QSizeF(595, 842), 0, 100, QRect(), 0));
}
