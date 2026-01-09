#!/bin/bash

# Adjust the config variables here as needed.
KUBE_CIDR="10.236.0.0/16"
KUBE_USER="kube"
KUBE_UID=2000
KUBE_GID=2000
KUBE_HOME="/home/kube"

kube_do() {
  sudo -u ${KUBE_USER} -i "${@}"
}
