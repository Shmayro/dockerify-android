#!/bin/bash

# Wait until the emulator is listed in adb devices
RETRY_COUNT=0
MAX_RETRIES=10
SLEEP_INTERVAL=5

while ! adb devices | grep emulator-5554; do
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "Emulator did not become healthy after $MAX_RETRIES attempts. Exiting."
        exit 1
    fi
    echo "Waiting for emulator to be healthy..."
    RETRY_COUNT=$((RETRY_COUNT + 1))
    sleep $SLEEP_INTERVAL
done

echo "Emulator is healthy. Proceeding..."

# Check if the script has already run
if [ -f /root/.first-boot-done ]; then
    exit 0
fi

# Create a marker file to indicate the script has run
touch /root/.first-boot-done
sleep $MAX_RETRIES
echo "Root Script Starting..."

# Root the VM
cd /root/rootAVD
./rootAVD.sh system-images/android-29/default/x86_64/ramdisk.img