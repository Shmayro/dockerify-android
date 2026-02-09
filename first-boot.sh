#!/bin/bash

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
  wget https://sourceforge.net/projects/opengapps/files/x86_64/20220503/open_gapps-x86_64-11.0-pico-20220503.zip/download -O gapps-11.zip
  unzip gapps-11.zip 'Core/*' -d gapps-11 && rm gapps-11.zip
  rm gapps-11/Core/setup*
  lzip -d gapps-11/Core/*.lz
  for f in gapps-11/Core/*.tar; do
    tar -x --strip-components 2 -f "$f" -C gapps-11
  done
  adb push gapps-11/etc /system
  adb push gapps-11/framework /system
  adb push gapps-11/app /system
  adb push gapps-11/priv-app /system
  rm -r gapps-11
  touch /data/.gapps-done
}

install_root() {
  adb wait-for-device
  echo "Root Script Starting..."
  # Root the AVD by patching the ramdisk.
  git clone https://gitlab.com/newbit/rootAVD.git
  pushd rootAVD
  sed -i 's/read -t 10 choice/choice=1/' rootAVD.sh
  ./rootAVD.sh system-images/android-30/default/x86_64/ramdisk.img
  cp /opt/android-sdk/system-images/android-30/default/x86_64/ramdisk.img /data/android.avd/ramdisk.img
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
echo "no" | avdmanager create avd -n android -k "system-images;android-30;default;x86_64"

[ "$gapps_needed" = true ] && install_gapps && [ "$root_needed" = false ] && adb reboot
[ "$root_needed" = true ] && install_root
apply_settings
copy_extras

touch /data/.first-boot-done
echo "Success !!"
