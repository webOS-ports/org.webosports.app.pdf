#!/bin/sh
# (c) 2026 Herman van Hazendonk <github.com@herrie.org>
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License version 3, as published
# by the Free Software Foundation.
#
# static-analysis.sh - static-analysis gate for the app's own C++
# (PdfViewerApp/*.cpp), as Camera's and Sound Recorder's:
#
#   gcc -fanalyzer    at -O0 and -O2
#   clang analyzer    with the alpha checkers for unix, security and core
#   clang-tidy        clang-analyzer-*, bugprone-*, cert-*, concurrency-*,
#                     performance-*
#   cppcheck          all checks, exhaustive, inconclusive included
#   flawfinder        level 1 and up
#
#   Coccinelle        its stock C++ semantic patches, where it gets through
#
# sparse parses C only, so it is not run.
#
# Needs a sysroot with Qt 6 headers (a recipe sysroot, or the one from
# tests/host-sysroot.sh):
#   APP_SYSROOT=<sysroot> tests/static-analysis.sh
set -u

DIR=$(cd "$(dirname "$0")/../PdfViewerApp" && pwd)
SYSROOT=${APP_SYSROOT:?set APP_SYSROOT to a recipe-sysroot}
U=$SYSROOT/usr/include
CXXV=$(ls "$U/c++" | head -1)
TRIPLE=$(ls "$U/c++/$CXXV" | grep -- -linux | head -1)

FLAGS="-std=c++17 -fPIC -nostdinc++ -isystem $U/c++/$CXXV -isystem $U/c++/$CXXV/$TRIPLE --sysroot=$SYSROOT
 -isystem $U -isystem $U/QtCore -isystem $U/QtGui -isystem $U/QtQml -isystem $U/QtQuick -isystem $U/QtConcurrent
 -isystem $U/poppler/qt6 -I$DIR"
SOURCES="documentregistry.cpp documentsearch.cpp filescanner.cpp pageimageprovider.cpp pdfdocument.cpp renderplan.cpp plugin.cpp"
HEADERS="documentregistry.h documentsearch.h filescanner.h pageimageprovider.h pdfdocument.h renderplan.h plugin.h"
OURS='(documentregistry|documentsearch|filescanner|pageimageprovider|pdfdocument|renderplan|plugin)[.](cpp|h)'
fail=0

report() {
	hits=$(printf '%s\n' "$2" | grep -E "$OURS" | grep -Ei 'warning|error|style|portability|performance|hit' || true)
	if [ -n "$hits" ]; then
		echo "== $1: FINDINGS"; printf '%s\n' "$hits"; fail=1
	else
		echo "== $1: clean"
	fi
}
have() { command -v "$1" >/dev/null 2>&1 || { echo "== $1: not installed, skipped"; return 1; }; }

cd "$DIR"
if have g++; then
	for opt in -O0 -O2; do
		out=""
		for f in $SOURCES; do
			out="$out$(g++ $opt -fanalyzer -fsyntax-only -Wall -Wextra $FLAGS "$f" 2>&1)
"
		done
		report "gcc -fanalyzer $opt" "$out"
	done
fi
if have clang++; then
	out=""
	for f in $SOURCES; do
		out="$out$(clang++ --analyze -Xclang -analyzer-checker=core,unix,security,alpha.core,alpha.unix,alpha.security,cplusplus \
			$FLAGS "$f" -o /dev/null 2>&1)
"
	done
	report "clang --analyze" "$out"
fi
if have clang-tidy; then
	out=$(clang-tidy -quiet --checks='-*,clang-analyzer-*,bugprone-*,cert-*,concurrency-*,performance-*,-bugprone-easily-swappable-parameters,-cert-err58-cpp' \
		$SOURCES -- $FLAGS 2>&1)
	report clang-tidy "$out"
fi
if have cppcheck; then
	out=$(cppcheck --enable=all --check-level=exhaustive --inconclusive --std=c++17 --quiet \
		--suppress=missingIncludeSystem --suppress=unusedFunction --suppress=checkersReport \
		-DQ_OBJECT= -DQ_SIGNALS=public -DQ_EMIT= -DQ_INVOKABLE= '-DQ_PROPERTY(x)=' '-DQ_PLUGIN_METADATA(x)=' '-DQ_ENUM(x)=' $SOURCES 2>&1)
	report cppcheck "$out"
fi
if have flawfinder; then
	out=$(flawfinder --minlevel=1 --columns --quiet --dataonly $SOURCES $HEADERS 2>&1)
	report flawfinder "$out"
fi
if have spatch; then
	out=""
	for f in $SOURCES; do
		# A null check after a dereference, and a free/delete pair.
		out="$out$(spatch --very-quiet --c++=17 --sp-file "$(dirname "$0")/cocci/deref-then-check.cocci" "$f" 2>&1)
"
	done
	report coccinelle "$out"
fi
exit $fail
