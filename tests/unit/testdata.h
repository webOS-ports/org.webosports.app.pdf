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


#ifndef PDFVIEWERAPP_TESTS_TESTDATA_H
#define PDFVIEWERAPP_TESTS_TESTDATA_H

#include <QtCore/QCoreApplication>
#include <QtCore/QElapsedTimer>
#include <QtCore/QString>

#include <algorithm>
#include <functional>

// The documents in tests/data (see make-test-pdfs.sh), by name.
inline QString testData(const char *name)
{
    return QStringLiteral(TEST_DATA_DIR "/") + QLatin1String(name);
}

// Runs the event loop until done() or the time is up; done() at the end.
// TEST_TIMEOUT_SCALE multiplies the time, for valgrind's slow runs.
inline bool waitFor(const std::function<bool()> &done, int ms = 10000)
{
    ms *= std::max(1, qEnvironmentVariableIntValue("TEST_TIMEOUT_SCALE"));
    QElapsedTimer timer;
    timer.start();
    while (!done() && timer.elapsed() < ms)
        QCoreApplication::processEvents(QEventLoop::AllEvents, 20);
    return done();
}

#endif // PDFVIEWERAPP_TESTS_TESTDATA_H
