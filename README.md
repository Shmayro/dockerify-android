# Dockerify Android

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker Pulls](https://img.shields.io/docker/pulls/shmayro/dockerify-android)](https://hub.docker.com/r/shmayro/dockerify-android)
[![GitHub Issues](https://img.shields.io/github/issues/shmayro/dockerify-android)](https://github.com/shmayro/dockerify-android/issues)
[![GitHub Stars](https://img.shields.io/github/stars/shmayro/dockerify-android?style=social)](https://github.com/shmayro/dockerify-android/stargazers)

**Dockerify Android** is a Dockerized Android emulator supporting multiple CPU architectures (**x86** and **arm64** in the near future ...) with native performance and seamless ADB access. It allows developers to run Android virtual devices (AVDs) efficiently within Docker containers, facilitating scalable testing and development environments.

## 🏠 **Homepage**

[![GitHub](https://img.shields.io/badge/GitHub-Repo-blue?logo=github)](https://github.com/shmayro/dockerify-android)
[![Docker Hub](https://img.shields.io/badge/Docker%20Hub-Repo-blue?logo=docker)](https://hub.docker.com/r/shmayro/dockerify-android)

## 📜 **Table of Contents**

- [Features](#-features)
- [Prerequisites](#-prerequisites)
- [Installation](#-installation)
- [Usage](#-usage)
- [Roadmap](#-roadmap)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)
- [License](#-license)
- [Contact](#-contact)

## 🔧 **Features**

- **Root and Magisk Preinstalled:** Comes with root access and Magisk preinstalled for advanced modifications.
- **PICO GAPPS Preinstalled:** Includes PICO GAPPS for essential Google services.
- **Seamless ADB Access:** Connect to the emulator via ADB from the host and other networked devices.
- **scrcpy Support:** Mirror the emulator screen using scrcpy for a seamless user experience.
- **Optimized Performance:** Utilizes native CPU capabilities for efficient emulation.
- **Multi-Architecture Support:** Runs natively on both **x86** and **arm64** CPU architectures.
- **Docker Integration:** Easily deploy the Android emulator within a Docker container.
- **Easy Setup:** Simple Docker commands to build and run the emulator.
- **Supervisor Management:** Manages emulator processes with Supervisor for reliability.

## 🛠️ **Prerequisites**

Before you begin, ensure you have met the following requirements:
- **Docker:** Installed on your system. [Installation Guide](https://docs.docker.com/get-docker/)
- **Docker Compose:** For managing multi-container setups. [Installation Guide](https://docs.docker.com/compose/install/)
- **KVM Support:** Ensure your system supports KVM (Kernel-based Virtual Machine) for hardware acceleration.
  - **Check KVM Support:**

    ```bash
    egrep -c '(vmx|svm)' /proc/cpuinfo
    ```

    A non-zero output indicates KVM support.

## 🚀 **Installation**

To simplify the setup process, you can use the provided [docker-compose.yml](https://github.com/Shmayro/dockerify-android/blob/main/docker-compose.yml) file.

1. **Clone the Repository:**

    ```bash
    git clone https://github.com/shmayro/dockerify-android.git
    cd dockerify-android
    ```

2. **Run Docker Compose:**

    ```bash
    docker-compose up -d
    ```

    > **Note:** This command runs the container in detached mode, grants necessary privileges for KVM, and shares the host's network stack for seamless ADB access.

## 📡 **Usage**

1. **Connect via ADB:**

    ```bash
    adb connect localhost:5555
    adb devices
    ```

    **Expected Output:**

    ```
    connected to localhost:5555
    List of devices attached
    localhost:5555	device
    ```

2. **Use scrcpy to Mirror the Emulator Screen:**

    ```bash
    scrcpy -s localhost:5555
    ```

    > **Note:** Ensure `scrcpy` is installed on your host machine. [Installation Guide](https://github.com/Genymobile/scrcpy#installation)

## 🚧 **Roadmap**

- [ ] Support for additional Android versions
- [x] Integration with CI/CD pipelines
- [ ] Support ARM64 CPU architecture
- [x] Preinstall PICO GAPPS
- [x] Support Magisk

## 🐞 **Troubleshooting**

- **ADB Connection Refused:**
  - **Ensure ADB Server is Running:**
    ```bash
    adb start-server -a
    ```
  - **Verify Firewall Settings:** Ensure that port `5555` is open on your server.
  - **Check Emulator Status:** Ensure the emulator has fully booted by checking logs.

    ```bash
    docker logs android-emulator
    ```

- **Emulator Not Starting:**
  - **Check Supervisor Logs:**

    ```bash
    docker exec -it android-emulator bash
    cat /var/log/supervisor/emulator.out.log
    cat /var/log/supervisor/emulator.err.log
    ```

- **KVM Not Accessible:**
  - **Verify KVM Installation:**

    ```bash
    lsmod | grep kvm
    ```
  - **Check Permissions:** Ensure your user has access to `/dev/kvm`.

## 🤝 **Contributing**

Contributions are welcome! To contribute:

1. **Fork the Repository**
2. **Create a Feature Branch:**

    ```bash
    git checkout -b feature/YourFeature
    ```

3. **Commit Your Changes:**

    ```bash
    git commit -m "Add Your Feature"
    ```

4. **Push to the Branch:**

    ```bash
    git push origin feature/YourFeature
    ```

5. **Open a Pull Request**

Please ensure your contributions adhere to the project's coding standards and include relevant tests.

## 📄 **License**

This project is licensed under the [MIT License](LICENSE).

## 📫 **Contact**

- **Haroun EL ALAMI**
- **Email:** haroun.dev@gmail.com
- **GitHub:** [shmayro](https://github.com/shmayro)
- **Twitter:** [@HarounDev](https://twitter.com/HarounDev)
