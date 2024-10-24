#!/bin/bash

# Check if the .first-boot-done file exists
if [ -f /data/.first-boot-done ]; then
  RAMDISK_PATH="-ramdisk /data/android.avd/ramdisk.img"
fi

# Start the emulator with the appropriate ramdisk.img
/opt/android-sdk/emulator/emulator -avd android -writable-system -no-window -no-audio -no-boot-anim -skip-adb-auth -gpu swiftshader_indirect -no-snapshot $RAMDISK_PATH -qemu -m ${RAM_SIZE:-4096}