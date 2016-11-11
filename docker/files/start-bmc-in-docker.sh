#!/bin/sh
echo "INFO: Generating SSH key.."
ssh-keygen -f $HOME/.ssh/id_rsa -N ""
service apache2 start
echo "INFO: BMC ready"
echo "INFO: Type 'bmc help'"
bash --login -i
