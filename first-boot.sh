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

echo "Root Script Starting..."

# Root the VM
git clone https://gitlab.com/newbit/rootAVD.git
pushd rootAVD
sed -i 's/read -t 10 choice/choice=2/' rootAVD.sh
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