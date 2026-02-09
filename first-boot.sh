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

install_arm_translation() {
  prepare_system
  echo "Installing ARM Translation (libhoudini) ..."
  
  # Download libhoudini for both ARM32 and ARM64 support
  mkdir -p /tmp/houdini
  cd /tmp/houdini
  
  # Download houdini_9_y for ARM32 (armeabi-v7a) support
  echo "Downloading houdini_9_y for ARM32 support..."
  wget -O houdini9_y.sfs http://dl.android-x86.org/houdini/9_y/houdini.sfs
  
  # Download houdini_9_z for ARM64 (arm64-v8a) support
  echo "Downloading houdini_9_z for ARM64 support..."
  wget -O houdini9_z.sfs http://dl.android-x86.org/houdini/9_z/houdini.sfs
  
  # Create directories on device
  adb shell mkdir -p /system/lib/arm /system/lib64/arm64 /system/etc/binfmt_misc
  
  # Extract and push houdini_9_y (ARM32)
  echo "Extracting houdini_9_y..."
  unsquashfs -f -d houdini9_y houdini9_y.sfs
  
  # Push ARM32 translation files
  adb push houdini9_y/system/lib/libhoudini.so /system/lib/
  adb push houdini9_y/system/lib/arm/* /system/lib/arm/
  adb push houdini9_y/system/bin/houdini /system/bin/
  
  # Extract and push houdini_9_z (ARM64)
  echo "Extracting houdini_9_z..."
  unsquashfs -f -d houdini9_z houdini9_z.sfs
  
  # Push ARM64 translation files
  adb push houdini9_z/system/lib64/libhoudini.so /system/lib64/
  adb push houdini9_z/system/lib64/arm64/* /system/lib64/arm64/
  adb push houdini9_z/system/bin/houdini64 /system/bin/
  
  # Set proper permissions
  adb shell chmod 755 /system/bin/houdini /system/bin/houdini64
  adb shell chmod 644 /system/lib/libhoudini.so /system/lib64/libhoudini.so
  adb shell chmod -R 755 /system/lib/arm /system/lib64/arm64
  
  # Update build.prop to enable ARM ABIs
  echo "Updating build.prop to enable ARM support..."
  adb shell "echo 'ro.product.cpu.abilist=x86_64,x86,arm64-v8a,armeabi-v7a,armeabi' >> /system/build.prop"
  adb shell "echo 'ro.product.cpu.abilist32=x86,armeabi-v7a,armeabi' >> /system/build.prop"
  adb shell "echo 'ro.product.cpu.abilist64=x86_64,arm64-v8a' >> /system/build.prop"
  adb shell "echo 'ro.dalvik.vm.native.bridge=libhoudini.so' >> /system/build.prop"
  adb shell "echo 'ro.enable.native.bridge.exec=1' >> /system/build.prop"
  adb shell "echo 'ro.enable.native.bridge.exec64=1' >> /system/build.prop"
  adb shell "echo 'ro.dalvik.vm.isa.arm=x86' >> /system/build.prop"
  adb shell "echo 'ro.dalvik.vm.isa.arm64=x86_64' >> /system/build.prop"
  
  # Create binfmt_misc entries for ARM support
  adb shell "echo ':arm_exe:M::\\x7f\\x45\\x4c\\x46\\x01\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x28::/system/bin/houdini:P' > /system/etc/binfmt_misc/arm_exe"
  adb shell "echo ':arm_dyn:M::\\x7f\\x45\\x4c\\x46\\x01\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x03\\x00\\x28::/system/bin/houdini:P' > /system/etc/binfmt_misc/arm_dyn"
  adb shell "echo ':arm64_exe:M::\\x7f\\x45\\x4c\\x46\\x02\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\xb7::/system/bin/houdini64:P' > /system/etc/binfmt_misc/arm64_exe"
  adb shell "echo ':arm64_dyn:M::\\x7f\\x45\\x4c\\x46\\x02\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x03\\x00\\xb7::/system/bin/houdini64:P' > /system/etc/binfmt_misc/arm64_dyn"
  
  # Clean up
  cd /root
  rm -rf /tmp/houdini
  
  echo "ARM Translation installed successfully"
  touch /data/.arm-translation-done
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
arm_translation_needed=false
if bool_true "$GAPPS_SETUP" && [ ! -f /data/.gapps-done ]; then gapps_needed=true; fi
if bool_true "$ROOT_SETUP" && [ ! -f /data/.root-done ]; then root_needed=true; fi
if bool_true "$ARM_TRANSLATION" && [ ! -f /data/.arm-translation-done ]; then arm_translation_needed=true; fi

# Skip initialization if first boot already completed.
if [ -f /data/.first-boot-done ]; then
  [ "$gapps_needed" = true ] && install_gapps && [ "$root_needed" = false ] && [ "$arm_translation_needed" = false ] && adb reboot
  [ "$root_needed" = true ] && install_root
  [ "$arm_translation_needed" = true ] && install_arm_translation
  apply_settings
  copy_extras
  exit 0
fi

echo "Init AVD ..."
echo "no" | avdmanager create avd -n android -k "system-images;android-30;default;x86_64"

[ "$gapps_needed" = true ] && install_gapps && [ "$root_needed" = false ] && [ "$arm_translation_needed" = false ] && adb reboot
[ "$root_needed" = true ] && install_root
[ "$arm_translation_needed" = true ] && install_arm_translation
apply_settings
copy_extras

touch /data/.first-boot-done
echo "Success !!"
