BMC=/opt/bmc/bin/bmc

all: bmc.html #bmc.pdf

bmc.pdf: bmc-notoc.html ./html2pdf.sh
	sh ./html2pdf.sh bmc-notoc.html bmc.pdf

bmc-notoc.html: bmc.txt usage/tstamp.tmp ./txt2html.sh setup
	sh ./txt2html.sh bmc.txt bmc-notoc.html

bmc.html: bmc.txt usage/tstamp.tmp ./txt2html.sh setup
	sh ./txt2html.sh -toc bmc.txt bmc.html

usage/tstamp.tmp: ./mkbmcusage.sh
	if [ -x $(BMC) ]; then \
		BMC=$(BMC) sh ./mkbmcusage.sh ./usage; \
	else \
		mkdir usage; \
	fi
	touch $@

clean::
	-rm -f *.html *.pdf *__*.png
	-rm -rf usage
distclean:: clean

setup:: ./asciidoc
ASCIIDOC_VER=8.6.9
ASCIIDOC=asciidoc-$(ASCIIDOC_VER)
./asciidoc: $(ASCIIDOC)
	ln -s $(ASCIIDOC)/asciidoc.py ./asciidoc
	touch $@
$(ASCIIDOC): $(ASCIIDOC).tar.gz
	tar xf $(ASCIIDOC).tar.gz
$(ASCIIDOC).tar.gz:
	wget http://downloads.sourceforge.net/project/asciidoc/asciidoc/$(ASCIIDOC_VER)/$(ASCIIDOC).tar.gz
distclean::
	-rm -rf $(ASCIIDOC) $(ASCIIDOC).tar.gz asciidoc

setup:: ./asciidoc
	./asciidoc --filter list | grep ditaa || { $(MAKE) ditaa.zip && ./asciidoc --filter install ditaa.zip && rm -f ditaa.zip; }
ditaa.zip: asciidoc-ditaa-filter-master.zip
	rm -rf asciidoc-ditaa-filter-master
	unzip -x asciidoc-ditaa-filter-master.zip
	cd asciidoc-ditaa-filter-master && sed -i.bak "/^ditaa-style=/{s| -'| --no-separation -'|}" ditaa-filter.conf	# workaround for no-separation
	cd asciidoc-ditaa-filter-master && zip -u -r ../ditaa.zip .
	rm -rf asciidoc-ditaa-filter-master
asciidoc-ditaa-filter-master.zip:
	wget -O $@ https://github.com/hwmaier/asciidoc-ditaa-filter/archive/master.zip
distclean::
	-rm -f asciidoc-ditaa-filter-master.zip
	-rm -rf asciidoc-ditaa-filter-master
	-rm -f ditaa.zip
	-asciidoc --filter remove ditaa
