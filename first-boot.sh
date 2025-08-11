#!/bin/bash

# apply settings
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

# Detect ip and forward ADB ports from the container's network
# interface to localhost.
LOCAL_IP=$(ip addr list eth0 | grep "inet " | cut -d' ' -f6 | cut -d/ -f1)
socat tcp-listen:"5555",bind="$LOCAL_IP",fork tcp:127.0.0.1:"5555" &

echo "Emulator is healthy. Proceeding..."

# Check if the script has already run
if [ -f /data/.first-boot-done ]; then
  apply_settings
  exit 0
fi

echo "Init ADV ..."

echo "no" | avdmanager create avd -n android -k "system-images;android-30;default;x86_64"

echo "Preparation ..."

adb wait-for-device
adb root
adb shell avbctl disable-verification
adb disable-verity
adb reboot
adb wait-for-device
adb root
adb remount
for f in $(ls /extras/*); do
  adb push $f /sdcard/Download/
done

echo "Installing GAPPS ..."

wget https://netcologne.dl.sourceforge.net/project/opengapps/x86_64/20220503/open_gapps-x86_64-11.0-pico-20220503.zip?viasf=1 -O gapps-11.zip
unzip gapps-11.zip 'Core/*' -d gapps-11  && rm gapps-11.zip
rm gapps-11/Core/setup*
lzip -d gapps-11/Core/*.lz
for f in $(ls gapps-11/Core/*.tar); do
  tar -x --strip-components 2 -f $f -C gapps-11
done

adb push gapps-11/etc /system
adb push gapps-11/framework /system
adb push gapps-11/app /system
adb push gapps-11/priv-app /system

# Install native bridge libraries for ARM compatibility
echo "Installing native bridge ..."
curl -L -o ndk-translation.tar.gz https://github.com/iwei20/libndk_extracted/archive/refs/heads/main.tar.gz
mkdir ndk-translation
tar -xf ndk-translation.tar.gz -C ndk-translation --strip-components=1
for dir in bin etc lib lib64; do
  if [ -d ndk-translation/system/$dir ]; then
    adb push ndk-translation/system/$dir /system/
  fi
done
adb shell 'cat >> /system/build.prop <<"EOF"
ro.dalvik.vm.native.bridge=libndk_translation.so
ro.enable.native.bridge.exec=1
ro.enable.native.bridge.exec64=1
ro.vendor.enable.native.bridge.exec=1
ro.vendor.enable.native.bridge.exec64=1
ro.ndk_translation.version=0.2.3
ro.dalvik.vm.isa.arm=x86
ro.dalvik.vm.isa.arm64=x86_64
ro.product.cpu.abilist=x86_64,x86,armeabi-v7a,armeabi,arm64-v8a
ro.product.cpu.abilist32=x86,armeabi-v7a,armeabi
ro.product.cpu.abilist64=x86_64,arm64-v8a
EOF'
rm -rf ndk-translation ndk-translation.tar.gz

echo "Root Script Starting..."

# Root the VM
git clone https://gitlab.com/newbit/rootAVD.git
pushd rootAVD
sed -i 's/read -t 10 choice/choice=1/' rootAVD.sh
./rootAVD.sh system-images/android-30/default/x86_64/ramdisk.img
cp /opt/android-sdk/system-images/android-30/default/x86_64/ramdisk.img /data/android.avd/ramdisk.img
popd
echo "Root Done"
sleep 15
echo "Cleanup ..."
# done
rm -r gapps-11
rm -r rootAVD
apply_settings
touch /data/.first-boot-done
echo "Sucess !!"