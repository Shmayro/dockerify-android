FROM ubuntu:20.04

# Install necessary packages
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        libegl1 \
        openjdk-17-jdk-headless \
        wget \
        curl \
        git \
        lzip \
        unzip \
        supervisor \
        qemu-kvm \
        iproute2 \
        socat \
        tzdata \
        squashfs-tools && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set up Android SDK
RUN mkdir -p /opt/android-sdk/cmdline-tools && \
    cd /opt/android-sdk/cmdline-tools && \
    wget https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip -O cmdline-tools.zip && \
    unzip cmdline-tools.zip -d latest && \
    rm cmdline-tools.zip && \
    mv latest/cmdline-tools/* latest/ || true && \
    rm -rf latest/cmdline-tools || true

ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_AVD_HOME=/data
ENV ADB_DIR="$ANDROID_HOME/platform-tools"
ENV PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ADB_DIR:$PATH"

# Initializing the required directories.
RUN mkdir /root/.android/ && \
	touch /root/.android/repositories.cfg && \
	mkdir /data && \
    mkdir /extras

# Copy emulator.zip
#COPY emulator.zip /root/emulator.zip
#COPY emulator/package.xml /root/package.xml


# Detect architecture and set environment variable
RUN yes | sdkmanager --sdk_root=$ANDROID_HOME "emulator" "platform-tools" "platforms;android-30" "system-images;android-30;default;x86_64"
# remove /opt/android-sdk/emulator/crashpad_handler
RUN rm -f /opt/android-sdk/emulator/crashpad_handler
# RUN if [ "$(uname -m)" = "aarch64" ]; then \
#         unzip /root/emulator.zip -d $ANDROID_HOME && \
# 	mv /root/package.xml $ANDROID_HOME/emulator/package.xml && \
#         rm /root/emulator.zip && \
#         yes | sdkmanager --sdk_root=$ANDROID_HOME "platform-tools" "platforms;android-29" "system-images;android-29;default;arm64-v8a" && \
#         echo "no" | avdmanager create avd -n test -k "system-images;android-29;default;arm64-v8a"; \
#     else \
#         yes | sdkmanager --sdk_root=$ANDROID_HOME "emulator" "platform-tools" "platforms;android-29" "system-images;android-29;default;x86_64" && \
#         echo "no" | avdmanager create avd -n test -k "system-images;android-29;default;x86_64"; \
#     fi

# Copy supervisor config
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy the rootAVD repository
#COPY rootAVD /root/rootAVD

# Copy the first-boot script
COPY first-boot.sh /root/first-boot.sh
RUN chmod +x /root/first-boot.sh

# Copy the start-emulator script
COPY start-emulator.sh /root/start-emulator.sh
RUN chmod +x /root/start-emulator.sh

# Expose necessary ports
EXPOSE 5554 5555

# Healthcheck to ensure the emulator is running
HEALTHCHECK --interval=10s --timeout=10s --retries=600 \
  CMD adb devices | grep emulator-5554 && test -f /data/.first-boot-done || exit 1

# Start Supervisor to manage the emulator
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# docker build -t dockerify-android .
# docker run -d --name dockerify-android --device /dev/kvm --privileged -p 5555:5555 dockerify-android
# docker run -d --name dockerify-android --device /dev/kvm --privileged -p 5555:5555 shmayro/dockerify-android
# docker exec -it dockerify-android tail -f /var/log/supervisor/emulator.out
# docker exec -it dockerify-android tail -f /var/log/supervisor/first-boot.out.log
