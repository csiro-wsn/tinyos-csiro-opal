//$Id: HdlcTranslateC.nc,v 1.6 2010-06-29 22:07:50 scipio Exp $

/* Copyright (c) 2000-2005 The Regents of the University of California.
 * Copyright (c) 2010 Stanford University.
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
 * - Neither the name of the copyright holder nor the names of
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
 */

/**
 * This is an implementation of HDLC serial encoding, supporting framing
 * through frame delimiter bytes and escape bytes.
 *
 * @author Philip Levis
 * @author Ben Greenstein
 * @date September 30 2010
 *
 */

#include "Serial.h"

module BufferedHdlcTranslateC {
  provides interface SerialFrameComm;
  uses {
    interface UartStream;
    interface Leds;
    interface SplitControl;
  }
}

implementation {
  typedef struct {
    uint8_t sendEscape:1;
    uint8_t receiveEscape:1;
  } HdlcState;
  
  HdlcState state = {0,0};

  // todo: update buffer sizes
  uint8_t rxBuffer[64];
  uint8_t txBuffer[64];
  uint8_t txPos;

  task void signalTxDone() {
    signal SerialFrameComm.putDone();
  };  


  // TODO: add reset for when SerialP goes no-sync.
  async command void SerialFrameComm.resetReceive(){
    state.receiveEscape = 0;
  }
  async command void SerialFrameComm.resetSend(){
    state.sendEscape = 0;
  }
  async event void UartStream.receivedByte(uint8_t data) {
  }

  async command error_t SerialFrameComm.putDelimiter() {
    txBuffer[txPos++] = HDLC_FLAG_BYTE;
    if (txPos==0) post signalTxDone();
    else call UartStream.send(txBuffer, txPos);
    return SUCCESS;
  }
  
  async command error_t SerialFrameComm.putData(uint8_t data) {
    if (data == HDLC_CTLESC_BYTE || data == HDLC_FLAG_BYTE) {
      txBuffer[txPos++] = HDLC_CTLESC_BYTE;
      txBuffer[txPos++] = data ^ 0x20;
    }
    else {
      txBuffer[txPos++] = data;
    }

    if (txPos==sizeof(txBuffer)) {
      // flush buffer
      call UartStream.send(txBuffer, txPos);
    } else  post signalTxDone();
    return SUCCESS;
  }

  async event void UartStream.sendDone( uint8_t* buf, uint16_t len, error_t error ) {
    txPos = 0;
    post signalTxDone();
  }

  async event void UartStream.receiveDone( uint8_t* buf, uint16_t len, error_t error ) {

    // 7E 41 0E 05 04 03 02 01 00 01 8F 7E
    uint8_t i;
    bool receiveEscape = 0;

    for (i=0; i<len; i++)
    {
      if (buf[i] == HDLC_FLAG_BYTE) {
        signal SerialFrameComm.delimiterReceived();
        continue;
      } else if (buf[i] == HDLC_CTLESC_BYTE) {
        receiveEscape = 1;
        continue;
      } else if (receiveEscape) {
        receiveEscape = 0;
        buf[i] = buf[i] ^ 0x20;
      }
      signal SerialFrameComm.dataReceived(buf[i]);
    } 

    // start receive of next packet
    call UartStream.receive(rxBuffer, sizeof(rxBuffer));
  }

  event void SplitControl.startDone(error_t error)
  {
    // serial port initialized, start receive operation for SerialP
    call UartStream.receive(rxBuffer, sizeof(rxBuffer));
  }

  event void SplitControl.stopDone(error_t error)
  {

  }


}
