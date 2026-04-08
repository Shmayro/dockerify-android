FROM ubuntu:20.04
ARG ANDROID_VERSION=30
ENV ANDROID_VERSION=${ANDROID_VERSION}

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        libegl1 \
        openjdk-17-jdk-headless \
        wget \
        curl \
        git \
        xz-utils \
        unzip \
        supervisor \
        qemu-kvm \
        iproute2 \
        socat \
        tzdata \
        squashfs-tools \
        procps && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN curl -s "https://dl.google.com/android/repository/repository2-1.xml" | \
    grep -oP 'emulator-linux_x64-\d+\.zip' | head -1 | \
    awk '{print "https://dl.google.com/android/repository/" $0}' | \
    wget -q -O /tmp/emulator.zip - || true && \
    if [ -s /tmp/emulator.zip ] && [ -f /tmp/emulator.zip ]; then \
        unzip -q /tmp/emulator.zip -d /opt/android-sdk && rm /tmp/emulator.zip; \
    fi

RUN mkdir -p /opt/android-sdk/cmdline-tools && \
    cd /opt/android-sdk/cmdline-tools && \
    wget https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip -O cmdline-tools.zip && \
    unzip cmdline-tools.zip -d latest && \
    rm cmdline-tools.zip && \
    mv latest/cmdline-tools/* latest/ || true && \
    rm -rf latest/cmdline-tools || true

ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_AVD_HOME=/data
ENV PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$PATH:$ANDROID_HOME/platform-tools"

RUN mkdir /root/.android/ && \
 	touch /root/.android/repositories.cfg && \
 	mkdir /data && \
    mkdir /extras

RUN export ANDROID_VERSION=$ANDROID_VERSION && \
    yes | sdkmanager --sdk_root=$ANDROID_HOME "platform-tools" && \
    if [ "$ANDROID_VERSION" -ge 35 ]; then \
        yes | sdkmanager --sdk_root=$ANDROID_HOME "platforms;android-${ANDROID_VERSION}" "system-images;android-${ANDROID_VERSION};google_apis;x86_64" || true; \
    else \
        yes | sdkmanager --sdk_root=$ANDROID_HOME "emulator" "platforms;android-${ANDROID_VERSION}" "system-images;android-${ANDROID_VERSION};default;x86_64"; \
    fi && \
    yes | sdkmanager --sdk_root=$ANDROID_HOME "emulator" || true

RUN if [ ! -f "$ANDROID_HOME/platform-tools/adb" ]; then \
        echo "ERROR: adb not found at $ANDROID_HOME/platform-tools/adb"; \
        ls -la $ANDROID_HOME/; \
        exit 1; \
    fi

RUN rm -f /opt/android-sdk/emulator/crashpad_handler

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

COPY first-boot.sh /root/first-boot.sh
RUN chmod +x /root/first-boot.sh

COPY start-emulator.sh /root/start-emulator.sh
RUN chmod +x /root/start-emulator.sh

EXPOSE 5554 5555

HEALTHCHECK --interval=30s --timeout=10s --retries=60 \
  CMD ps aux | grep -v grep | grep -q emulator || test -f /data/.first-boot-done

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
