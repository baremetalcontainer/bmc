#!/bin/sh
set -eu

TXT="$1"
OUT="$2"

#ASCIIDOC=asciidoc
#ASCIIDOC=asciidoctor
A2X=a2x
ICONSDIR=$(locate asciidoc | grep 'icons$'| head -1)
OPT="--copy -v -a toc2 -a numbered -a data-uri -a icons -a iconsdir=$ICONSDIR"

case "$OUT" in
*.html) OPT="$OPT -f chunked -d book";;
*.pdf) OPT="$OPT -f pdf -d book";;
*) echo "ERROR: $OUT is not supported."; exit 1;;
esac

$A2X $OPT "$TXT"

exit 0
