#!/bin/bash
set -e

sudo apt-get update
sudo apt-get install -y qrencode zbar-tools openssl zenity
chmod +x .devcontainer/post-create.sh
