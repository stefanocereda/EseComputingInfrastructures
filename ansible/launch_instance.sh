#!/bin/bash

ENV_NAME=${ENV_NAME:-env}
ANSIBLE_CONFIG=ansible.cfg
export AWS_DEFAULT_REGION=eu-west-1
ansible-playbook -v ec2-spot-request.yml --extra-vars "instance_type=c4.large volume_size=20 spot_price=0.2 Name=$ENV_NAME"
