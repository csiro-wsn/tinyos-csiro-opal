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
 * @author Philip Levis
 * @author Kevin Klues (adapted to opal)
 */

#include "Timer.h"

configuration ActiveMessageC {
  provides {
    interface SplitControl;

    interface AMSend[am_id_t id];
    interface Receive[am_id_t id];
    interface Receive as Snoop[am_id_t id];

    interface Packet;
    interface AMPacket;
    interface PacketAcknowledgements;
    interface PacketTimeStamp<TRadio, uint32_t> as PacketTimeStampRadio;
    interface PacketTimeStamp<TMilli, uint32_t> as PacketTimeStampMilli;
    interface LowPowerListening;
  }
}
implementation {


  #if defined(OPAL_RADIO_RF212)
    #warning "Using RF212 as default radio"
    components RF212ActiveMessageC as AM;
  #else
    #warning "Using RF230 as default radio"
    #ifndef OPAL_RADIO_RF230
      #define OPAL_RADIO_RF230
    #endif
    components RF230ActiveMessageC as AM;
  #endif

  SplitControl = AM.SplitControl;
  
  AMSend       = AM.AMSend;
  Receive      = AM.Receive;
  Snoop        = AM.Snoop;
  Packet       = AM.Packet;
  AMPacket     = AM.AMPacket;
  PacketAcknowledgements = AM.PacketAcknowledgements;

  PacketTimeStampRadio = AM.PacketTimeStampRadio;
  PacketTimeStampMilli = AM.PacketTimeStampMilli;
  LowPowerListening = AM.LowPowerListening;
}

