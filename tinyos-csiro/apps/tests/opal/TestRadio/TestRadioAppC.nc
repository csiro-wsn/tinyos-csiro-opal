/*
 * Copyright (c) 2013 CSIRO
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * @author Philipp Sommer <philipp.sommer@csiro.au>
 */

#include "TestRadio.h"


configuration TestRadioAppC {}
implementation {
  components MainC, TestRadioC as App, LedsC;


  #if defined(OPAL_RADIO_RF230)
    components RF230ActiveMessageC as ActiveMessageC;
  #elif defined(OPAL_RADIO_RF212)
    components RF212ActiveMessageC as ActiveMessageC;
  #endif

  components new TimerMilliC() as SendTimer, new TimerMilliC() as StartupTimer, new TimerMilliC() as BlinkTimer;
    
  App.Boot -> MainC.Boot;

  App.Receive -> ActiveMessageC.Receive[AM_RADIO_TEST_MSG];
  App.AMSend -> ActiveMessageC.AMSend[AM_RADIO_TEST_MSG];
  App.SplitControl -> ActiveMessageC;
  App.Packet -> ActiveMessageC;
  App.AMPacket -> ActiveMessageC;

  App.Leds -> LedsC;
  App.MilliTimer -> SendTimer;
  App.StartupTimer -> StartupTimer;
  App.BlinkTimer -> BlinkTimer;

  components SerialPrintfC, SerialStartC;


  App.PacketRSSI -> ActiveMessageC.PacketRSSI;
  App.PacketLinkQuality -> ActiveMessageC.PacketLinkQuality;

  components RandomC;
  App.Random -> RandomC;

}


