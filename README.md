[BMC (Bare-Metal Container)](http://www.itri.aist.go.jp/cpc/research/bmc/) offers an environment to run a container (Docker) image with a suitable Linux kernel on a remote physical machine.
BMC allows to change the kernel and its settings for the container (Docker) image.
As a result, the application extracts the full performance of the physical machine.

The following figure shows the difference in application invocation between traditional style and BMC.
The traditional style is a system-centric architecture as it assumes the system software is fixed, running all the time, and unalterable by users.
In contrast, BMC allows users to change the kernel and the machine for each application, which we describe as an application-centric architecture.

![BMC arch](http://www.itri.aist.go.jp/cpc/research/bmc/img/bmc.png)

A pre-built BMC image using DIND (Docker in Docker) technique is offered.
Users can avid burdensome setting up (ex. Apache CGI, etc).
We recommend new users to try this pre-built version.

https://hub.docker.com/r/baremetalcontainer/bmc/

# Paper
* [1] K.Suzaki, H.Koie, and R.Takano, "Bare-Metal Container", IEEE High Performance Computing and Communications (HPCC) Dec.2016. http://www.swinflow.org/confs/2016/hpcc/ [Ppaer PDF](https://www.researchgate.net/profile/Kuniyasu_Suzaki/publication/311716297_Bare-Metal_Container_---_Direct_execution_of_a_container_image_on_a_remote_machine_with_an_optimized_kernel_---/links/58579ed508ae77ec370a824a.pdf?origin=publication_detail&ev=pub_int_prw_xdl&msrp=SO2YfYKNZvcGeCUGx4SaB-86NvgO39wgRTrI-XPjzcVhMlrU4DVMuUPdgjvIKkvTaHcru-NEuA1hx78YoXbF8XfP5EUc0_hbZv1wdjPkNuI.YewcWchFqz5N0SCFw41VDGE98RHGohomAv-mYnCSaO4rMGq7KDbW74DHw3KWTj9az4S4RKatGQNuTfRncuyyDw.9tAC6ocUUgqQxKOXvipyty6Y0miNCbYDqoS2tsPJ8mP88-_lwDIE64Xu2epD1YQd0dqnyMDUNR3l_-v19VYvOQ) / [Slide PDF](http://www.slideshare.net/suzaki/baremetal-container-presented-at-hpcc2016)

# Exhibition
* [1] SuperComuting16 (SC16) [AIST booth 1709](http://iebms.heiexpo.com/iebms/oep/oep_p2_details.aspx?sessionid=fbkfe0fe8ff6ej4ff8ein&like=A&OrderNbr=8255) Nov.2016 http://sc16.supercomputing.org/
