FROM ubuntu:20.04

# Install necessary packages
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        openjdk-11-jdk \
        wget \
        curl \
        unzip \
        supervisor \
        qemu-kvm \
        tzdata \
        git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set up Android SDK
RUN mkdir -p /opt/android-sdk/cmdline-tools && \
    cd /opt/android-sdk/cmdline-tools && \
    wget https://dl.google.com/android/repository/commandlinetools-linux-7583922_latest.zip -O cmdline-tools.zip && \
    unzip cmdline-tools.zip -d latest && \
    rm cmdline-tools.zip && \
    mv latest/cmdline-tools/* latest/ || true && \
    rm -rf latest/cmdline-tools || true

ENV ANDROID_HOME=/opt/android-sdk
ENV ADB_DIR="$ANDROID_HOME/platform-tools"
ENV PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ADB_DIR:$PATH"

# Copy emulator.zip
COPY emulator.zip /root/emulator.zip
COPY emulator/package.xml /root/package.xml


# Detect architecture and set environment variable
RUN if [ "$(uname -m)" = "aarch64" ]; then \
        unzip /root/emulator.zip -d $ANDROID_HOME && \
	mv /root/package.xml $ANDROID_HOME/emulator/package.xml && \
        rm /root/emulator.zip && \
        yes | sdkmanager --sdk_root=$ANDROID_HOME "platform-tools" "platforms;android-29" "system-images;android-29;default;arm64-v8a" && \
        echo "no" | avdmanager create avd -n test -k "system-images;android-29;default;arm64-v8a"; \
    else \
        yes | sdkmanager --sdk_root=$ANDROID_HOME "emulator" "platform-tools" "platforms;android-29" "system-images;android-29;default;x86_64" && \
        echo "no" | avdmanager create avd -n test -k "system-images;android-29;default;x86_64"; \
    fi

# Copy supervisor config
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Clone the rootAVD repository
RUN git clone https://gitlab.com/newbit/rootAVD.git /root/rootAVD

# Copy the first-boot script
COPY first-boot.sh /root/first-boot.sh
RUN chmod +x /root/first-boot.sh

# Expose necessary ports
EXPOSE 5554 5555

# Healthcheck to ensure the emulator is running
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD adb devices | grep emulator-5554 || exit 1

# Start Supervisor to manage the emulator
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# docker build -t dockerify-android .
# docker run -d --name dockerify-android --device /dev/kvm --privileged --network host dockerify-android
# docker run -d --name dockerify-android --device /dev/kvm --privileged --network host shmayro/dockerify-android
# docker exec -it dockerify-android tail -f /var/log/supervisor/emulator.out
