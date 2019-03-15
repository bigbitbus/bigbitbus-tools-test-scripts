#!/bin/bash

# Copyright 2018 BigBitBus Inc. https://www.bigbitbus.com Licensed under the Apache
# License, Version 2.0 (the "License"); you may not use this file except in
# compliance with the License. You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0 Unless required by applicable law
# or agreed to in writing, software distributed under the License is distributed
# on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
# express or implied. See the License for the specific language governing
# permissions and limitations under the License.



# Invoke on any Redhat/Centos/Fedora or Debian/Ubuntu or Amazon Linux system as
#./standalone.sh unique_uuid > bigbitbus.log 2>&1, the unique uuid is obtained from the bigbitbus page
# If you are testing a burstable CPU VM and want to burn down the burst credits
#./standalone.sh unique_uuid 3600 > bigbitbus.log 2>&1 # The number 3600 here specifies that the CPU(s)
# keep busy for 3600 seconds - 1 hour - before starting the actual test.

# Some parameters
WORKDIR="/tmp/bigbitbus"
STRESS_VERSION="0.09.23"
STRESS_SOURCE_URL="http://kernel.ubuntu.com/~cking/tarballs/stress-ng/stress-ng-$STRESS_VERSION.tar.xz"
BIGBITBUS_RECEIVER_ENDPOINT="http://127.0.0.1:8000/api/ingest/v1/upload"
EACH_PERCENT_TIME=2  #seconds for each test configuration run

if [ -z "$1" ]
then
    echo "At least 1 CLI parameters separated by space required: MACHINE_ID"
    exit 1
else
    MACHINE_ID=$1
fi

if [ -z "$2" ]
then
    BURN_IN_TIME_SECONDS=1 #since 0 would mean infinite run
else
    BURN_IN_TIME_SECONDS=$3
fi

# Determine OS platform
UNAME=$(uname | tr "[:upper:]" "[:lower:]")
# If Linux, try to determine specific distribution
if [ "$UNAME" == "linux" ]; then
    # If available, use LSB to identify distribution
    if [ -f /etc/lsb-release -o -d /etc/lsb-release.d ]; then
        export DISTRO=$(lsb_release -i | cut -d: -f2 | sed s/'^\t'//)
    # Otherwise, use release info file
    else
        export DISTRO=$(ls -d /etc/[A-Za-z]*[_-][rv]e[lr]* | grep -v "lsb" | cut -d'/' -f3 | cut -d'-' -f1 | cut -d'_' -f1)
    fi
fi
# For everything else (or if above failed), just use generic identifier
[ "$DISTRO" == "" ] && export DISTRO=$UNAME
unset UNAME

# Install pre-requisites
if [[ "$DISTRO" = "Ubuntu" ]]
then
    sudo apt-get update
    sudo apt-get install -y gcc make wget curl wget
else
    sudo yum --assumeyes update
    sudo yum --assumeyes install  gcc make wget curl wget
fi

# Setup workdirectory
mkdir -p $WORKDIR

# Compile and Install stressng from source
cd $WORKDIR
wget $STRESS_SOURCE_URL
tar xf stress-ng-$STRESS_VERSION.tar.xz
cd $WORKDIR/stress-ng-$STRESS_VERSION
make
STRESSBINPATH=$WORKDIR/stress-ng-binary
cp stress-ng $STRESSBINPATH
chmod +x $STRESSBINPATH

# Collect system information
DATADIR=$WORKDIR/data
mkdir -p $DATADIR
date +%s > $DATADIR/epoch_time.txt

echo $MACHINE_ID > $DATADIR/MACHINE_ID.txt

mkdir -p $DATADIR/systeminfo
# OS info
cat /proc/version > $DATADIR/systeminfo/os.txt
# Release info
cat /etc/*-release > $DATADIR/systeminfo/os.txt
# Manufacturer
sudo dmidecode -s system-manufacturer > $DATADIR/systeminfo/manufacturer.txt
# Model
sudo dmidecode -s system-product-name > $DATADIR/systeminfo/model.txt
# Serial number
sudo dmidecode -s system-serial-number > $DATADIR/systeminfo/serial_number.txt
# CPU info
cat /proc/cpuinfo > $DATADIR/systeminfo/cpu.txt
# Memory
cat /proc/meminfo > $DATADIR/systeminfo/memory.txt
# Disk
lsblk -l > $DATADIR/systeminfo/block_devices.txt

# Burn down burst credits
date
echo "Burning down CPU for $BURN_IN_TIME_SECONDS seconds."
cd /tmp
$STRESSBINPATH \
    --timeout $BURN_IN_TIME_SECONDS \
    --cpu 0 \
    --cpu-method all

# Run stress-ng - iterate over different cpu-loads
mkdir -p $DATADIR/stressdata
cd $DATADIR/stressdata
for (( CPUPERCENT=5; CPUPERCENT<=95; CPUPERCENT+=10 )); do
    CURRENTTESTPATH=$DATADIR/stressdata/$CPUPERCENT
    mkdir -p $CURRENTTESTPATH
    cd $CURRENTTESTPATH
    date
    echo "Starting to run CPU at $CPUPERCENT percent."
    # Actual test
    $STRESSBINPATH \
        --yaml $CURRENTTESTPATH/cpupercent-$CPUPERCENT.yaml \
        --verbose \
        --metrics \
        --cpu 0 \
        --cpu-method all \
        --verify \
        --timeout $EACH_PERCENT_TIME \
        --cpu-load $CPUPERCENT \
        > $CURRENTTESTPATH/cmdline.log 2>&1
done

# Create data file for upload
tar -cvzf $WORKDIR/cpu-data-$MACHINE_ID.tar.gz -C $DATADIR .

# Post the file 
curl -X POST $BIGBITBUS_RECEIVER_ENDPOINT/cpu-data-$MACHINE_ID.tar.gz/  \
	-F "file=@$WORKDIR/cpu-data-$MACHINE_ID.tar.gz" \
	-H "Content-Type: multipart/form-data" \
	-H "cache-control: no-cache"

