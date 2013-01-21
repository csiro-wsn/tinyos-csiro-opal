#!/usr/bin/env python

import sys
import tos
import time

AM_TEST_SERIAL_MSG = 0x89

class TestSerialMsg(tos.Packet):
    def __init__(self, packet = None):
        tos.Packet.__init__(self,
                            [('counter',  'int', 2)],
                            packet)
if '-h' in sys.argv:
    print "Usage:", sys.argv[0], "serial@/dev/ttyUSB0:115200"
    sys.exit()

am = tos.AM()

stats_sent = 0
stats_ack = 0
stats_noack = 0

for counter in range(1000):
    msg = TestSerialMsg()
    msg.counter = counter
    print "Send:", msg.counter
    #print msg

    am.write(msg, AM_TEST_SERIAL_MSG)
    stats_sent += 1

    p = am.read(1)
    if (p is not None):
      msg = TestSerialMsg(p.data)
      print "Reply: ", msg.counter, "Expected:", counter
      if (msg.counter == counter):
        stats_ack += 1
      else:
        stats_noack += 1

    else:
      print "No Reply"

print "Sent:", stats_sent, "Ack:", stats_ack, "NoAck:", stats_noack 
