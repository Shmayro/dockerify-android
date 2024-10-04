# Dockerify Android

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Docker](https://img.shields.io/badge/Docker-%230db7ed.svg?logo=docker&logoColor=white)
![GitHub Issues](https://img.shields.io/github/issues/shmayro/dockerify-android)
![GitHub Stars](https://img.shields.io/github/stars/shmayro/dockerify-android?style=social)

**Dockerify Android** is a Dockerized Android emulator supporting multiple CPU architectures (**x86** and **arm64**) with native performance and seamless ADB access. It allows developers to run Android virtual devices (AVDs) efficiently within Docker containers, facilitating scalable testing and development environments.

## 🏠 **Homepage**

[Project Homepage URL if available]

## 📜 **Table of Contents**

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
  - [Using Pre-built Docker Images](#using-pre-built-docker-images)
  - [Build the Docker Image](#build-the-docker-image)
  - [Run the Docker Container](#run-the-docker-container)
- [Usage](#usage)
  - [Connect to Android VM from the Host](#connect-to-android-vm-from-the-host)
  - [Connect to Android VM from a Remote Machine](#connect-to-android-vm-from-a-remote-machine)*
- [Roadmap](#roadmap)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)
- [Contact](#contact)

## 🔧 **Features**

- **Docker Integration:** Easily deploy the Android emulator within a Docker container.
- **Multi-Architecture Support:** Runs natively on both **x86** and **arm64** CPU architectures.
- **Seamless ADB Access:** Connect to the emulator via ADB from the host and other networked devices.
- **scrcpy Support:** Mirror the emulator screen using scrcpy for a seamless user experience.
- **Optimized Performance:** Utilizes native CPU capabilities for efficient emulation.
- **Easy Setup:** Simple Docker commands to build and run the emulator.
- **Supervisor Management:** Manages emulator processes with Supervisor for reliability.

## 🛠️ **Prerequisites**

Before you begin, ensure you have met the following requirements:
- **Docker:** Installed on your system. [Installation Guide](https://docs.docker.com/get-docker/)
- **Docker Compose:** (Optional) For managing multi-container setups. [Installation Guide](https://docs.docker.com/compose/install/)
- **SSH Access:** To establish SSH tunnels from remote machines.
- **KVM Support:** Ensure your system supports KVM (Kernel-based Virtual Machine) for hardware acceleration.
  - **Check KVM Support:**

    ```bash
    egrep -c '(vmx|svm)' /proc/cpuinfo
    ```

    A non-zero output indicates KVM support.

## 🚀 **Installation**

### 🥇 **Using Pre-built Docker Images**

To simplify the setup process, you can use the pre-built Docker image hosted on Docker Hub.

1. **Pull the Pre-built Image:**

    ```bash
    docker pull shmayro/dockerify-android:latest
    ```

2. **Run the Pre-built Image:**

    ```bash
    docker run -d \
      --name dockerify-android \
      --device /dev/kvm \
      --privileged \
      --network host \
      shmayro/dockerify-android:latest
    ```

    > **Note:** This command runs the container in detached mode, grants necessary privileges for KVM, and shares the host's network stack for seamless ADB access.

### 1. **Build the Docker Image**

Clone the repository and navigate to its directory:

    ```bash
    git clone https://github.com/shmayro/dockerify-android.git
    cd dockerify-android
    ```

Build the Docker image using the provided `Dockerfile`:

    ```bash
    docker build -t android-ubuntu .
    ```

    > **Note:** This step may take several minutes as it installs necessary packages and sets up the Android SDK.

### 2. **Run the Docker Container**

Run the Docker container in **host network mode** to allow seamless ADB access:

    ```bash
    docker run -d \
      --name android-emulator \
      --device /dev/kvm \
      --privileged \
      --network host \
      android-ubuntu
    ```

    > **Flags Explanation:**
    > - `-d`: Runs the container in detached mode.
    > - `--name android-emulator`: Names the container "android-emulator".
    > - `--device /dev/kvm`: Grants the container access to KVM for hardware acceleration.
    > - `--privileged`: Provides extended privileges necessary for KVM.
    > - `--network host`: Shares the host's network stack, eliminating the need for explicit port mappings.

## 📡 **Usage**

### **A. Connect to Android VM from the Host**

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

### **B. Connect to Android VM from a Remote Machine**

1. **Establish an SSH Tunnel:**

    From your remote machine, set up an SSH tunnel to forward port `5555` to a local port (e.g., `4444`):

    ```bash
    ssh -L 4444:localhost:5555 -C -N -l haroun 192.168.1.18
    ```

    **Flags Explanation:**
    - `-L 4444:localhost:5555`: Forwards local port `4444` to `localhost:5555` on the server.
    - `-C`: Enables compression.
    - `-N`: No remote commands; just forwarding.
    - `-l haroun`: Specifies the SSH username.
    - `192.168.1.18`: Replace with your server's IP address.

2. **Connect via ADB Using the Tunnel:**

    ```bash
    adb connect localhost:4444
    adb devices
    ```

    **Expected Output:**

    ```
    connected to localhost:4444
    List of devices attached
    localhost:4444	device
    ```

3. **Use scrcpy to Mirror the Emulator Screen:**

    ```bash
    scrcpy -s localhost:4444
    ```

## 🚧 **Roadmap**

- [ ] Support for additional Android versions
- [ ] Integration with CI/CD pipelines
- [ ] Support ARM64 CPU architecture
- [ ] Support Magisk

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
