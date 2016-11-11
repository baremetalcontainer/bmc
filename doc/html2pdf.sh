#!/bin/sh
set -eu

HTML="$1"
PDF="$2"

WKHTMLTOPDF=wkhtmltopdf 
if ! type "$WKHTMLTOPDF" >/dev/null 2>&1; then
	WKHTMLTOPDF=wkhtmltox/bin/wkhtmltopdf 
fi

#{
#grep -i "^<meta" "$HTML"
#grep -i '^<title>' "$HTML" | sed 's/title>/h1>/g'
#} >cover.html

"$WKHTMLTOPDF" \
	--orientation Portrait \
	--page-size A4 \
	--footer-line --footer-right '[page]/[toPage]' \
	toc \
	"$HTML" "$PDF"

exit 0
