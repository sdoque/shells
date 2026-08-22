#!/bin/bash

# Copies the rpiExec staging directory to the Raspberry Pi.
# Prerequisite: SSH key must be installed on the Pi.
#   ssh-keygen -t ed25519 -C "mac-to-rpi"   # once on the Mac
#   ssh-copy-id jan@192.168.1.109            # once per Pi

RPI_USER="jan"
RPI_HOST="192.168.1.109"
STAGING="$HOME/go/src/github.com/sdoque/rpiExec/"

rsync -avz --progress "$STAGING" "$RPI_USER@$RPI_HOST:rpiExec/"
