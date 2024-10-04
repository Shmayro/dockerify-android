FROM ubuntu:20.04 AS builder

# Install necessary packages
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        openjdk-11-jdk wget curl unzip bash supervisor xvfb x11vnc qemu-kvm websockify && \
    rm -rf /var/lib/apt/lists/*

# Set up Android SDK
RUN mkdir -p /opt/android-sdk/cmdline-tools && \
    cd /opt/android-sdk/cmdline-tools && \
    wget https://dl.google.com/android/repository/commandlinetools-linux-7583922_latest.zip -O cmdline-tools.zip && \
    unzip cmdline-tools.zip -d latest && \
    rm cmdline-tools.zip && \
    mv latest/cmdline-tools/* latest/ || true && \
    rm -rf latest/cmdline-tools || true

ENV ANDROID_HOME /opt/android-sdk
ENV PATH "$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

# Install Android SDK components
RUN yes | sdkmanager --sdk_root=$ANDROID_HOME "platform-tools" "platforms;android-28" "system-images;android-28;default;x86_64" "emulator" && \
    echo "no" | avdmanager create avd -n test -k "system-images;android-28;default;x86_64"

FROM ubuntu:20.04

# Copy necessary files from builder
COPY --from=builder /opt/android-sdk /opt/android-sdk
COPY --from=builder /etc/supervisor/conf.d/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

ENV ANDROID_HOME /opt/android-sdk
ENV PATH "$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

# Expose necessary ports
EXPOSE 5554 5555

# Start Supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]