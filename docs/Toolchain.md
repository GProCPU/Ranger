# Toolchain and Workflow Guide

The compiler used is the [RISC-V GNU toolchain](https://github.com/riscv-collab/riscv-gnu-toolchain) with gcc.
This must be compiled from source, but the process is straightforward.

## Toolchain Installation

The following is a condensed installation guide for the toolchain.
The complete guide can be found at https://github.com/riscv-collab/riscv-gnu-toolchain

**Note: compiling the RISC-V GNU toolchain may take over an hour**

**Warning: installation takes around 6.65 GB of disk and download size**

### Getting the source

This repository uses submodules, but submodules will fetch automatically on demand and do not need to be downloaded/initialized by the user.

```bash
git clone https://github.com/riscv/riscv-gnu-toolchain
cd riscv-gnu-toolchain
```

### Prerequisites

Several standard packages are needed to build the toolchain.

**Ubuntu**
```bash
sudo apt-get install autoconf automake autotools-dev curl python3 python3-pip libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev ninja-build git cmake libglib2.0-dev
```

**Fedora/CentOS/Rocky/RHEL**
```bash
sudo yum install autoconf automake python3 libmpc-devel mpfr-devel gmp-devel gawk  bison flex texinfo patchutils gcc gcc-c++ zlib-devel expat-devel
```

**Arch**
```bash
sudo pacman -Syyu autoconf automake curl python3 libmpc mpfr gmp gawk base-devel bison flex texinfo gperf libtool patchutils bc zlib expat
```

**OS X** using [Homebrew](https://brew.sh/)
```bash
brew install python3 gawk gnu-sed gmp mpfr libmpc isl zlib expat texinfo flock
```
To build the glibc (Linux) on OS X, you will need to build within a case-sensitive file system. The simplest approach is to create and mount a new disk image with a case sensitive format. Make sure that the mount point does not contain spaces. This is not necessary to build newlib or gcc itself on OS X.

### Build and Install (Newlib multilib)

To build the Newlib cross-compiler with support for both 32-bit and 64-bit, pick an install path (that is writeable).
If you choose, say, `/opt/riscv`, then add `/opt/riscv/bin` to your PATH.
Then, simply run the following command:

```bash
mkdir build
cd build
sudo mkdir /opt/riscv
../configure --prefix=/opt/riscv --with-arch=rv32i_zicsr --with-abi=ilp32
sudo make
```

The installation can be completed without root privilege by choosing an installation directory other than `/opt/riscv/`.

The `--with-arch` and `--with-abi` options must be used when targeting the `zicsr` extension.

### Add to PATH

You can add the RISC-V GNU toolchain to all user's PATH in either the `/etc/profile` or `/etc/environment` file, depending on you platform.
If neither file exists, search for how to add to all user's PATH for you OS or distribution.

If you do not have root access, or only want to add the toolchain to your user's path, you can add the following line to your `.bashrc` file.

```bash
export PATH="/opt/riscv/bin:$PATH"
```

You can check if the installation succeeded and was added to you path by *restarting you terminal* then running `which riscv64-unknown-elf-gcc`.
It will print something like `/opt/riscv/bin/riscv64-unknown-elf-gcc` if it was successful.

<br><br>

## Building a Project

Compiling for the GPro 2 (Ranger) requires the either a new version of gcc with support for RISC-V or the previous installation step to be completed.
After the toolchain has been installed, projects can be compiled using a Makefile.

### Platform Files

The compile process relies on several key files platform files.
These files are located in the `sw/common` directory.

- `startup_ranger.S` This assembly files contains startup code for Ranger.
- `ranger.ld` This is the linker script that tells the compiler how to organize machine code and data for Ranger's memory layout.
- `ranger.mk` This is the base Makefile required to be included in all Ranger project Makefile's.

### Makefile

Example projects with Makefile's can be in the `sw/examples` directory.
These each include a minimal Makefile.

```makefile
RANGER_HOME = ../../..

include $(RANGER_HOME)/sw/common/ranger.mk
```

The first line sets the `RANGER_HOME` variable to three directories above the current directory.
The next line includes the ranger platform Makefile required by all projects.

The project is build by running the following command in the project directory.

```bash
make build
```


## Upload

# TODO
