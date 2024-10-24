#!/bin/bash

# Check if the .first-boot-done file exists
if [ -f /data/.first-boot-done ]; then
  RAMDISK="-ramdisk /data/android.avd/ramdisk.img"
fi

# Define the SD card path
SDCARD_PATH="/data/android.avd/sdcard.img"
SDCARD="-sdcard $SDCARD_PATH"
# Initialize the SDCARD_PATH only if CREATE_SDCARD is true and the sdcard doesn't exist
if [ -n "$SDCARD_SIZE" ] && [ ! -f /data/android.avd/sdcard.img ]; then
  echo "Creating SD card..."
  # Create the SD card using the specified size
  /opt/android-sdk/emulator/mksdcard $SDCARD_SIZE $SDCARD_PATH
  echo "SD card created with size: $SDCARD_SIZE"
fi

chmod -x /opt/android-sdk/emulator/crashpad_handler
# Start the emulator with the appropriate ramdisk.img
/opt/android-sdk/emulator/emulator -avd android -writable-system -no-window -no-audio -no-boot-anim -skip-adb-auth -gpu swiftshader_indirect -no-snapshot -no-metrics $RAMDISK ${SDCARD_SIZE:+$SDCARD} -qemu -m ${RAM_SIZE:-4096}