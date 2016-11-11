BMC = /opt/bmc/bin/bmc
DOCKER_IMAGE_NAME = openblas.centos7.bmc
all::
	sudo docker build -t $(DOCKER_IMAGE_NAME) .
	$(BMC) pull --nopull $(DOCKER_IMAGE_NAME)
clean::
	-rm -f *.out *.log *.dat *.gpl *.png *.tar.gz
	-rm -f typescript
