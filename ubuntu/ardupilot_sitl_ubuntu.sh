#!/bin/bash

set -e  # Exit on error

echo "🟢 Starting ArduPilot SITL setup script..."

sudo apt-get update
sudo apt-get upgrade -y

cd ~
git clone --recurse-submodules https://github.com/ArduPilot/ardupilot.git
cd ardupilot
Tools/environment_install/install-prereqs-ubuntu.sh -y
. ~/.profile
./waf configure --board CubeOrange
./waf plane

echo "🎉 Setup complete for ArduPilot SITL!"
