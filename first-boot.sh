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
  adb shell settings put global window_animation_scale 0
  adb shell settings put global transition_animation_scale 0
  adb shell settings put global animator_duration_scale 0
  adb shell settings put global stay_on_while_plugged_in 0
  adb shell settings put system screen_off_timeout 15000
  adb shell settings put global private_dns_mode hostname
  adb shell settings put global private_dns_specifier dns2024.haroun.dev
  adb shell svc wifi disable
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

echo "no" | avdmanager create avd -n test -k "system-images;android-29;default;x86_64"

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

wget https://deac-fra.dl.sourceforge.net/project/opengapps/x86_64/20220503/open_gapps-x86_64-10.0-pico-20220503.zip?viasf=1 -O gapps-10.zip
unzip gapps-10.zip 'Core/*' -d gapps-10  && rm gapps-10.zip
rm gapps-10/Core/setup*
lzip -d gapps-10/Core/*.lz
for f in $(ls gapps-10/Core/*.tar); do
  tar -x --strip-components 2 -f $f -C gapps-10
done

adb push gapps-10/etc /system
adb push gapps-10/framework /system
adb push gapps-10/app /system
adb push gapps-10/priv-app /system

echo "Root Script Starting..."

# Root the VM
git clone https://gitlab.com/newbit/rootAVD.git
pushd rootAVD
sed -i 's/read -t 10 choice/choice=2/' rootAVD.sh
./rootAVD.sh system-images/android-29/default/x86_64/ramdisk.img
popd
echo "Root Done"
sleep 15
echo "Cleanup ..."
# done
rm -r gapps-10
rm -r rootAVD
apply_settings
touch /data/.first-boot-done
echo "Sucess !!"