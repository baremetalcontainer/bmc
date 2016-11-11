#!/bin/sh
set -eu

unset DISPLAY

opt_toc=false
while [ $# -gt 0 ]; do
	case "$1" in
	-toc) opt_toc=true;;
	-*) echo "ERROR: Invalid option: $1"; exit 1;;
	*) break;;
	esac
	shift
done

TXT="$1"
HTML="$2"

ASCIIDOC=./asciidoc
#ASCIIDOC=asciidoc
#ASCIIDOC=asciidoctor
#ICONSDIR=$(locate asciidoc | grep 'icons$'| head -1)
ICONSDIR=$(echo ./asciidoc-*/images/icons)
OPT="-v -a numbered -a data-uri -a icons -a iconsdir=$ICONSDIR"
#OPT="$OPT -a stylesheet=xhtml11.css -a stylesdir=/usr/share/asciidoc/stylesheets"
if "$opt_toc"; then
	OPT="$OPT -a toc"
fi

$ASCIIDOC $OPT -o "$HTML" "$TXT"

exit 0
