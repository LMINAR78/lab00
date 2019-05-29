#!/bin/sh
set -e
cd $TRAVIS_BUILD_DIR/packer
packer build webapp.json | tee /tmp/packer.out
AMI=$(awk -F':' '/(eu|us|ap|sa)-(west|central|east|northeast|southeast)-(1|2): ami-/ {print $2}' /tmp/packer.out |  tr -d '[[:space:]]')

cd $TRAVIS_BUILD_DIR/webapp
terraform init -var ami_id=$AMI
terraform plan -var ami_id=$AMI
terraform apply -var ami_id=$AMI
