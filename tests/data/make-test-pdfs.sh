#!/bin/sh
# Makes the generated test documents with Ghostscript's pdfwrite:
#
#   guide.pdf   12 pages, the first two labelled i and ii, page 7 landscape;
#               a nested outline, links to pages and to a web address (page
#               i), a link into another file (page ii, not followed), and
#               words to find ("lunar" on pages 3, 5 and 9, twice on 5).
#   locked.pdf  guide.pdf with the user password "secret".
#
#   tests/data/make-test-pdfs.sh
set -e
cd "$(dirname "$0")"
PS=$(mktemp)
trap 'rm -f "$PS"' EXIT
cat > "$PS" <<'PS'
%!PS
/Helvetica findfont 18 scalefont setfont
/page {  % n landscape? -> -
    /land exch def /n exch def
    land { << /PageSize [842 595] >> } { << /PageSize [595 842] >> } ifelse setpagedevice
    /top land { 540 } { 780 } ifelse def
    60 top moveto (Chapter ) show n 20 string cvs show
    /Helvetica findfont 12 scalefont setfont
    60 top 40 sub moveto (This is page ) show n 20 string cvs show (. Plain text for the viewer's tests.) show
    n 3 eq n 5 eq or n 9 eq or { 60 top 70 sub moveto (The lunar module landed here.) show } if
    n 5 eq { 60 top 90 sub moveto (Another lunar mention on the same page.) show } if
    n 1 eq {
        60 top 120 sub moveto (Go to chapter 9) show
        [/Rect [55 top 125 sub 170 top 105 sub] /Page 9 /View [/XYZ null null null] /Subtype /Link /ANN pdfmark
        60 top 150 sub moveto (Visit webos-ports.org) show
        [/Rect [55 top 155 sub 200 top 135 sub] /Action << /Subtype /URI /URI (https://webos-ports.org/) >>
         /Subtype /Link /ANN pdfmark
    } if
    n 2 eq {
        60 top 120 sub moveto (See the other manual) show
        [/Rect [55 top 125 sub 200 top 105 sub] /Action /GoToR /File (other.pdf) /Page 1
         /Subtype /Link /ANN pdfmark
    } if
    % Labels i, ii, then 1 from the third page on.
    [/Label n 3 lt { n 1 eq { (i) } { (ii) } ifelse } { n 2 sub 20 string cvs } ifelse /PAGELABEL pdfmark
    /Helvetica findfont 18 scalefont setfont
    showpage
} def
[/Title (Viewer Test Guide) /Author (webOS Ports) /Subject (Test document) /Keywords (test, pdf) /DOCINFO pdfmark
1 1 12 { dup 7 eq page } for
[/Count 2 /Title (Front matter) /Page 1 /OUT pdfmark
  [/Title (Contents) /Page 1 /OUT pdfmark
  [/Title (Preface) /Page 2 /OUT pdfmark
[/Count -2 /Title (Part One) /Page 3 /OUT pdfmark
  [/Title (Landing) /Page 5 /OUT pdfmark
  [/Title (Wide page) /Page 7 /OUT pdfmark
[/Title (Part Two) /Page 9 /OUT pdfmark
PS
gs -q -dNOPAUSE -dBATCH -dSAFER -sDEVICE=pdfwrite -o guide.pdf "$PS"
gs -q -dNOPAUSE -dBATCH -dSAFER -sDEVICE=pdfwrite -sOwnerPassword=owner -sUserPassword=secret \
    -o locked.pdf guide.pdf
