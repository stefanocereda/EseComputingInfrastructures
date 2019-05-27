#!/bin/bash
# I changed the AMI in ec2-spot-request.yml to use an ARM instance
# and also the node exporter

ENV_NAME=${ENV_NAME:-env}
ANSIBLE_CONFIG=ansible.cfg
export AWS_DEFAULT_REGION=eu-west-1
ansible-playbook -v ec2-spot-request.yml --extra-vars "instance_type=a1.medium volume_size=20 spot_price=0.2 Name=$ENV_NAME"
echo Updating EC2 host cache
./hosts/ec2.py --refresh-cache
./hosts/ec2.py --list
echo Please give me the IP:
read host
ansible-playbook -v minimal.yml --extra-vars "variable_host=$host"
ansible-playbook -v common.yml --extra-vars "variable_host=$host"
ansible-playbook -v monitoring.yml --extra-vars "variable_host=$host"
