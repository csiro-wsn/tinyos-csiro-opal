TinyOS 2.x Support for Opal
=================

This repository contains the TinyOS 2.x port for CSIRO's Opal sensor node platform.

## Background

More information about the Opal platform is available here:

* "Opal: A Multiradio Platform for High Throughput Wireless Sensor Networks", Raja Jurdak, Kevin Klues, Brano Kusy, Christian Richter, Koen Langendoen, Michael Bruenig, IEEE Embedded Systems Letters, Volume: 3, Issue: 4, Dec. 2011 
[[PDF]](http://jurdak.com/es11.pdf)

* "Low Power or High Performance? A Tradeoff Whose Time Has Come (and Nearly Gone)", JeongGil Ko, Kevin Klues, Christian Richter, Wanja Hofer, Branislav Kusy, Michael Bruenig, Thomas Schmid, Qiang Wang, Prabal Dutta, and Andreas Terzis, 9th European Conference on Wireless Sensor Networks
(EWSN), February 2012 [[PDF]](http://web.eecs.umich.edu/~prabal/pubs/papers/ko12tradeoff.pdf)

## Installation

This guide explains the steps required to add support for the Opal platform to an existing installation of TinyOS 2.x.

### Prerequisites
__Important__: You need to have a working TinyOS installation on your system. This repository does NOT contain a full copy of the TinyOS source tree, it contains only the Opal-specific bits and pieces. Please refer to the [TinyOS website](http://www.tinyos.net/) for further information.

### Step 1: Installation of the ARM-Cortex toolchain
The Opal platform features an Atmel SAM3U microcontroller which implements the ARM Cortex-M3 architecture. TinyOS does not come with a toolchain (compiler, linker, etc..) for the ARM Cortex-M3 yet. Therefore, it is required to install a separate toolchain supporting the ARM Cortex-M3 architecture. More information how to build a toolchain for the ARM Cortex-M3 can be found [here](https://github.com/csiro-wsn/csiro-cortex-tools/).

**UPDATE:** Pre-built versions of a bare-metal ARM Cortex-M toolchain are available [here](https://launchpad.net/gcc-arm-embedded).

### Step 2: Installation of Opal-specific platform files for TinyOS

1. Clone the "tinyos-csiro-opal" git repository to your local machine.
```
git clone git://github.com/csiro-wsn/tinyos-csiro-opal.git
```
2. Change into the new directory "tinyos-csiro-opal".
```
cd tinyos-csiro-opal
```

3. The "tinyos-csiro-env.sh" shell script can be used to setup the corresponding environment variables required to link the Opal-specific directories and files to your existing TinyOS installation.
```
source ./tinyos-csiro-env.sh
```

4. Verify that you can compile TinyOS applications for the "opal" platform.
```
cd $TOSROOT/apps/Blink
make opal
```

### Step 3: Installation of the programming tools for Opal
1. In order to write a TinyOS binary to the flash memory of the Opal platform, you need to install the Opal programming tools first.
Installation instructions can be found [here](http://github.com/csiro-wsn/csiro-cortex-programming-tools).

2. Reboot the microcontroller node into bootloader mode by pressing the ERASE button first and then the RESET button on the Opal.

3. Compile and install a TinyOS application to the Opal node.
```
cd $TOSROOT/apps/Blink
make opal install,1
```

In case you have multiple Opal nodes connected to your machine, you can specify the corresponding USB device (e.g. /dev/ttyACM0) as follows:
```
make opal install,1 bossa,ttyACM0
```

## Support
Please use [GitHub Issues for this project](https://github.com/csiro-wsn/tinyos-csiro-opal/issues) to report any bugs and problems.


