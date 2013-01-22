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

 
#include "Timer.h"
#include "printf.h"
#include "TestRadio.h"

module TestRadioC {
  uses {
    interface Leds;
    interface Boot;
    interface Receive;
    interface AMSend;
    interface Timer<TMilli> as MilliTimer;
    interface Timer<TMilli> as StartupTimer;
    interface Timer<TMilli> as BlinkTimer;
    interface SplitControl;
    interface Packet;
    interface AMPacket;
    interface Random;

    interface PacketField<uint8_t> as PacketLinkQuality;
    interface PacketField<uint8_t> as PacketRSSI;


  }
}
implementation {



  uint16_t rxCount;
  uint16_t txCount;
  am_addr_t rxSource;


  message_t packet;

  bool locked;
  uint16_t counter = 0;
  

  event void Boot.booted() {

    call SplitControl.start();

    call BlinkTimer.startPeriodic(1000);

  }
  

  event void StartupTimer.fired() {

    call MilliTimer.startPeriodic(5000);
  }

  event void MilliTimer.fired() {

    if (locked) {
      return;
     }
    else {

      radio_test_msg_t* test = (radio_test_msg_t*)call Packet.getPayload(&packet, sizeof(radio_test_msg_t));
      test->seq = counter;
       if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(radio_test_msg_t)) == SUCCESS) {
         call Leds.led0On();
         locked = TRUE;
         counter++;
       }
    }
  }

  event void BlinkTimer.fired() {
    call Leds.led2Toggle();
  }

  event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {

    radio_test_msg_t* test = (radio_test_msg_t*)payload;

    printf("id: %u, seq: %u, rssi: %d, lqi: %u\n", call AMPacket.source(bufPtr), test->seq, (-91 + call PacketRSSI.get(bufPtr)), call PacketLinkQuality.get(bufPtr));
    printfflush();
 
    rxCount++;
    rxSource = call AMPacket.source(bufPtr);

    call Leds.led1Toggle();
 
    return bufPtr;
  }

  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
    if (&packet == bufPtr) {
      locked = FALSE;
      txCount++;
      call Leds.led0Off();
    }
  }

  event void SplitControl.startDone(error_t err) {

    printf("TestRadioC started\n");
    printfflush();

    // start sending with random backoff

    call StartupTimer.startOneShot(call Random.rand16()>>3);

  }

  event void SplitControl.stopDone(error_t err) {
  }

}




