#!/bin/bash

# Use custom ramdisk if present
if [ -f /data/android.avd/ramdisk.img ]; then
  RAMDISK="-ramdisk /data/android.avd/ramdisk.img"
fi

# Configure optional screen resolution and density
if [ -n "$SCREEN_RESOLUTION" ]; then
  SCREEN_RESOLUTION_FLAG="-skin $SCREEN_RESOLUTION"
fi
if [ -n "$SCREEN_DENSITY" ]; then
  SCREEN_DENSITY_FLAG="-dpi-device $SCREEN_DENSITY"
fi

# Configure optional screen resolution and density
if [ -n "$SCREEN_RESOLUTION" ]; then
  SCREEN_RESOLUTION_FLAG="-skin $SCREEN_RESOLUTION"
fi
if [ -n "$SCREEN_DENSITY" ]; then
  SCREEN_DENSITY_FLAG="-dpi-device $SCREEN_DENSITY"
fi

# Start the emulator with the appropriate ramdisk.img
/opt/android-sdk/emulator/emulator -avd android -nojni -netfast -writable-system -no-window -no-audio -no-boot-anim -skip-adb-auth -gpu swiftshader_indirect -no-snapshot -no-metrics $SCREEN_RESOLUTION_FLAG $SCREEN_DENSITY_FLAG $RAMDISK -qemu -m ${RAM_SIZE:-4096}
