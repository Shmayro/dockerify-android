# Stage 1: Builder
FROM ubuntu:20.04 AS builder

# Install necessary packages with minimal dependencies
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        openjdk-11-jdk \
        wget \
        curl \
        unzip \
        supervisor \
        qemu-kvm && \
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

# Environment variables
ENV ANDROID_HOME=/opt/android-sdk
ENV PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

# Install Android SDK components
RUN yes | sdkmanager --sdk_root=$ANDROID_HOME "platform-tools" "platforms;android-28" "system-images;android-28;default;x86_64" "emulator" && \
    echo "no" | avdmanager create avd -n test -k "system-images;android-28;default;x86_64"

# Stage 2: Final Image
FROM ubuntu:20.04

# Install runtime dependencies with minimal dependencies
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        openjdk-11-jdk \
        supervisor \
        qemu-kvm && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Environment variables
ENV ANDROID_HOME=/opt/android-sdk
ENV PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

# Copy Android SDK from builder stage
COPY --from=builder /opt/android-sdk /opt/android-sdk

# Copy supervisor configuration
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Expose necessary ports
EXPOSE 5554 5555

# Healthcheck to ensure the emulator is running
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD adb devices | grep emulator-5554 || exit 1

# Start Supervisor to manage emulator
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]