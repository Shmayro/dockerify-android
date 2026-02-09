# Testing ARM Translation Support

This document describes how to test the ARM translation feature for running ARM/ARM64 apps on the x86_64 emulator.

## Prerequisites

- Docker and Docker Compose installed
- ADB installed on host machine
- An ARM-only APK for testing (e.g., an app that only includes arm64-v8a libraries)

## Test Setup

1. **Start the container with ARM translation enabled:**

```bash
# Make sure ARM_TRANSLATION=1 in docker-compose.yml or use environment variable
export ARM_TRANSLATION=1
docker compose up -d
```

2. **Monitor the first boot process:**

```bash
docker logs -f dockerify-android
```

Wait for the following log messages:
- "Installing ARM Translation (libhoudini) ..."
- "Downloading houdini_9_y for ARM32 support..."
- "Downloading houdini_9_z for ARM64 support..."
- "Extracting houdini_9_y..."
- "Extracting houdini_9_z..."
- "Updating build.prop to enable ARM support..."
- "ARM Translation installed successfully"
- "Success !!"

The first boot with ARM translation can take 15-20 minutes depending on download speed and system performance.

## Verification Steps

### 1. Verify ARM ABIs are advertised

```bash
adb connect localhost:5555
adb shell getprop ro.product.cpu.abilist
```

**Expected output:**
```
x86_64,x86,arm64-v8a,armeabi-v7a,armeabi
```

### 2. Check ARM32 ABI list

```bash
adb shell getprop ro.product.cpu.abilist32
```

**Expected output:**
```
x86,armeabi-v7a,armeabi
```

### 3. Check ARM64 ABI list

```bash
adb shell getprop ro.product.cpu.abilist64
```

**Expected output:**
```
x86_64,arm64-v8a
```

### 4. Verify native bridge is configured

```bash
adb shell getprop ro.dalvik.vm.native.bridge
```

**Expected output:**
```
libhoudini.so
```

### 5. Check libhoudini files are present

```bash
adb shell ls -la /system/lib/libhoudini.so
adb shell ls -la /system/lib64/libhoudini.so
adb shell ls -la /system/bin/houdini
adb shell ls -la /system/bin/houdini64
adb shell ls /system/lib/arm/
adb shell ls /system/lib64/arm64/
```

All commands should show the files exist with proper permissions.

## Testing ARM Apps

### Test with an ARM-only APK

1. **Download an ARM-only test APK** (or use an app from Play Store that only has ARM libraries)

2. **Install the APK:**

```bash
adb install path/to/arm-only-app.apk
```

**Before ARM translation was enabled, you would see:**
```
INSTALL_FAILED_NO_MATCHING_ABIS: Failed to extract native libraries, res=-113
```

**After ARM translation is enabled, you should see:**
```
Success
```

3. **Launch the app** from the emulator UI or via adb:

```bash
adb shell monkey -p com.example.package -c android.intent.category.LAUNCHER 1
```

4. **Verify the app runs** - The app should launch and function normally. ARM native libraries will be transparently translated to x86 at runtime.

## Common Test Scenarios

### Scenario 1: Fresh installation with ARM translation enabled

```bash
# Remove old data
docker compose down -v
rm -rf ./data

# Start with ARM_TRANSLATION=1
docker compose up -d

# Wait for first boot to complete
docker logs -f dockerify-android

# Verify ARM support
adb connect localhost:5555
adb shell getprop ro.product.cpu.abilist
```

### Scenario 2: Enable ARM translation after initial setup

```bash
# Start container normally without ARM translation
ARM_TRANSLATION=0 docker compose up -d

# Wait for first boot to complete
# ...

# Stop container and enable ARM translation
docker compose down
# Edit docker-compose.yml: Set ARM_TRANSLATION: 1
docker compose up -d

# ARM translation will be installed on next boot
docker logs -f dockerify-android
```

### Scenario 3: Test with Google Play Store apps

If GAPPS are installed, you can test with real Play Store apps:

1. Open Play Store in the emulator
2. Search for an app known to have ARM-only libraries (e.g., some games)
3. Try to install the app
4. Verify it installs and runs successfully

## Troubleshooting

### ARM apps still fail to install

1. Check if ARM translation was actually installed:
```bash
docker logs dockerify-android | grep "ARM Translation"
```

2. Verify the marker file exists:
```bash
docker exec dockerify-android ls -la /data/.arm-translation-done
```

3. Check build.prop for ARM entries:
```bash
adb shell cat /system/build.prop | grep arm
```

### Downloads fail during installation

The script includes fallback download sources. Check the logs to see if both primary and fallback sources failed:

```bash
docker logs dockerify-android | grep -A5 "Downloading houdini"
```

### App crashes after installation

1. Check logcat for ARM translation errors:
```bash
adb logcat | grep -i houdini
```

2. Verify the app's native libraries:
```bash
adb shell dumpsys package com.example.package | grep -A5 "primaryCpuAbi"
```

## Performance Notes

- ARM translation adds runtime overhead for ARM code execution
- Performance depends on the complexity of native code
- Simple apps should run smoothly
- Heavy games or compute-intensive apps may show reduced performance
- x86 native apps will run at full speed (no translation needed)

## Cleanup

To completely reset and test again:

```bash
docker compose down -v
rm -rf ./data
docker compose up -d
```
