#REV = release-20160531
REV = tip

DOCKER = docker
#DOCKER = sudo docker

all:: build

run::
	./run-bmc --rm

build:: tmp/bmc.tar.gz
	$(DOCKER) build --tag=bmc .

tmp/bmc.tar.gz::
	mkdir -p tmp
	hg archive --type tgz -r $(REV) --prefix=bmc tmp/bmc.tar.gz || test -f tmp/bmc.tar.gz
clean::
distclean::
	-rm -rf tmp

doc::
	asciidoc README
clean::
	-rm -f README.html

distclean::clean
