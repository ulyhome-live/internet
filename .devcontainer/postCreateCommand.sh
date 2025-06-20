#!/bin/bash

sudo apt-get update
sudo apt-get install -y qrencode zbar-tools openssl zenity
echo "All dependencies are installed!"
chmod +x /workspaces/$(basename $(pwd))/qr-tool-unified.sh || true
