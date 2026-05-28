#!/bin/bash

# Android version and GAPPS version handling (defaults kept backward compatible)
ANDROID_VERSION=${ANDROID_VERSION:-30}
GAPPS_VERSION=${GAPPS_VERSION:-11}

bool_true() {
  case "${1,,}" in
    1|true|yes) return 0 ;;
    *) return 1 ;;
  esac
}

apply_settings() {
  adb wait-for-device
  # Waiting for the boot sequence to be completed.
  COMPLETED=$(adb shell getprop sys.boot_completed | tr -d '\r')
  while [ "$COMPLETED" != "1" ]; do
    COMPLETED=$(adb shell getprop sys.boot_completed | tr -d '\r')
    sleep 5
  done
  adb root
  adb shell settings put global window_animation_scale 0
  adb shell settings put global transition_animation_scale 0
  adb shell settings put global animator_duration_scale 0
  adb shell settings put global stay_on_while_plugged_in 0
  adb shell settings put system screen_off_timeout 15000
  adb shell settings put system accelerometer_rotation 0
  adb shell settings put global private_dns_mode hostname
  adb shell settings put global private_dns_specifier ${DNS:-one.one.one.one}
  adb shell settings put global airplane_mode_on 1
  adb shell am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true
  adb shell svc data disable
  adb shell svc wifi enable
}

prepare_system() {
  adb wait-for-device
  adb root
  adb shell avbctl disable-verification
  adb disable-verity
  adb reboot
  adb wait-for-device
  adb root
  adb remount
}

install_gapps() {
  prepare_system
  echo "Installing GAPPS ..."
  # Determine GAPPS date and API tag based on Android version.
  case "$ANDROID_VERSION" in
    30)
      GAPPS_DATE_FROM_VER="20220503"; GAPPS_API_TAG="11.0"; GAPPS_DIR="gapps-11" ;;
    31)
      GAPPS_DATE_FROM_VER="20230105"; GAPPS_API_TAG="12.0"; GAPPS_DIR="gapps-12" ;;
    33)
      GAPPS_DATE_FROM_VER="20220824"; GAPPS_API_TAG="13.0"; GAPPS_DIR="gapps-13" ;;
    34)
      GAPPS_DATE_FROM_VER="20230601"; GAPPS_API_TAG="14.0"; GAPPS_DIR="gapps-14" ;;
    35)
      GAPPS_DATE_FROM_VER="20240415"; GAPPS_API_TAG="15.0"; GAPPS_DIR="gapps-15" ;;
    36)
      GAPPS_DATE_FROM_VER="20250105"; GAPPS_API_TAG="16.0"; GAPPS_DIR="gapps-16" ;;
    *)
      GAPPS_DATE_FROM_VER="20220503"; GAPPS_API_TAG="11.0"; GAPPS_DIR="gapps-11" ;;
  esac

  # Allow override via GAPPS_VERSION, but keep defaults aligned with ANDROID_VERSION.
  if [[ "$GAPPS_VERSION" =~ ^[0-9]+$ ]]; then
    if [ "$GAPPS_VERSION" -ge 12 ]; then
      GAPPS_API_TAG="12.0"; GAPPS_DATE_FROM_VER="20230105"; GAPPS_DIR="gapps-12"
    fi
  fi

  OPEN_GAPPS_ARCHIVE="open_gapps-x86_64-${GAPPS_API_TAG}-pico-${GAPPS_DATE_FROM_VER}.zip"
  GAPPS_URL="https://sourceforge.net/projects/opengapps/files/x86_64/${GAPPS_DATE_FROM_VER}/${OPEN_GAPPS_ARCHIVE}/download"
  ZIP_FILE="gapps-${GAPPS_API_TAG%%.*}.zip"

  wget "$GAPPS_URL" -O "$ZIP_FILE"
  unzip "$ZIP_FILE" 'Core/*' -d "$GAPPS_DIR" && rm "$ZIP_FILE"
  rm -f "$GAPPS_DIR/Core/setup*" || true
  lzip -d "$GAPPS_DIR/Core/*.lz" || true
  for f in "$GAPPS_DIR/Core/*.tar"; do
    tar -x --strip-components 2 -f "$f" -C "$GAPPS_DIR"
  done
  adb push "$GAPPS_DIR/etc" /system
  adb push "$GAPPS_DIR/framework" /system
  adb push "$GAPPS_DIR/app" /system
  adb push "$GAPPS_DIR/priv-app" /system
  rm -r "$GAPPS_DIR" || true
  touch /data/.gapps-done
}

install_root() {
  adb wait-for-device
  echo "Root Script Starting..."
  # Root the AVD by patching the ramdisk for the configured Android version.
  git clone https://gitlab.com/newbit/rootAVD.git
  pushd rootAVD
  sed -i 's/read -t 10 choice/choice=1/' rootAVD.sh
  # Use the dynamic Android version for ramdisk patching
  ./rootAVD.sh system-images/android-${ANDROID_VERSION}/default/x86_64/ramdisk.img
  cp /opt/android-sdk/system-images/android-${ANDROID_VERSION}/default/x86_64/ramdisk.img /data/android.avd/ramdisk.img
  popd
  echo "Root Done"
  sleep 10
  rm -r rootAVD
  touch /data/.root-done
}

copy_extras() {
  adb wait-for-device
  # Push any Magisk modules for manual installation later
  for f in $(ls /extras/*); do
    adb push $f /sdcard/Download/
  done
}

# Detect the container's IP and forward ADB to localhost.
LOCAL_IP=$(ip addr list eth0 | grep "inet " | cut -d' ' -f6 | cut -d/ -f1)
socat tcp-listen:"5555",bind="$LOCAL_IP",fork tcp:127.0.0.1:"5555" &

if [ -n "$PORT_FORWARD" ]; then
  for port_pair in $(echo "$PORT_FORWARD" | tr ',' ' '); do
    HOST_PORT=$(echo "$port_pair" | cut -d: -f1)
    ANDROID_PORT=$(echo "$port_pair" | cut -d: -f2)
    if [ -n "$HOST_PORT" ] && [ -n "$ANDROID_PORT" ]; then
      socat tcp-listen:"$HOST_PORT",bind="$LOCAL_IP",fork tcp:127.0.0.1:"$ANDROID_PORT" &
    fi
  done
fi

gapps_needed=false
root_needed=false
if bool_true "$GAPPS_SETUP" && [ ! -f /data/.gapps-done ]; then gapps_needed=true; fi
if bool_true "$ROOT_SETUP" && [ ! -f /data/.root-done ]; then root_needed=true; fi

# Skip initialization if first boot already completed.
if [ -f /data/.first-boot-done ]; then
  [ "$gapps_needed" = true ] && install_gapps && [ "$root_needed" = false ] && adb reboot
  [ "$root_needed" = true ] && install_root
  apply_settings
  copy_extras
  exit 0
fi

echo "Init AVD ..."
echo "no" | avdmanager create avd -n android -k "system-images;android-${ANDROID_VERSION};default;x86_64"

[ "$gapps_needed" = true ] && install_gapps && [ "$root_needed" = false ] && adb reboot
[ "$root_needed" = true ] && install_root
apply_settings
copy_extras

touch /data/.first-boot-done
echo "Success !!"
