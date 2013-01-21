README for TestSerial
Author/Contact: philipp.sommer@csiro.au

Description:

TestSerial is a simple application that may be used to test that the
Python toolchain can communicate with an opal node over the serial
port. The python application sends packets containing a counter to
the serial port. When the mote application receives a counter
packet, it immediately replies with a copy of the packet.

Python Usage:
  ./test-serial.py serial@/dev/ttyUSB0:115200

Tools:

Known bugs/limitations:

None.

