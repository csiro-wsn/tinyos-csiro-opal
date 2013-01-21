/* Copyright (c) 2011 People Power Co.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the People Power Corporation nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE
 * PEOPLE POWER CO. OR ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE
 *
 * @author Philipp Sommer <philipp.sommer@csiro.au> (Opal port)
 */

module PlatformHdlcUartP {
  provides {
    interface StdControl;
    interface HdlcUart;
  }
  uses {
    interface StdControl as SerialControl;
    interface UartStream;
  }
} implementation {

#ifndef PLATFORM_SERIAL_RX_BUFFER_SIZE
/** Number of bytes in the ring buffer of received but unprocessed
 * characters. */
#define PLATFORM_SERIAL_RX_BUFFER_SIZE 256
#endif /* PLATFORM_SERIAL_RX_BUFFER_SIZE */

  /** Circular buffer holding received data not yet processed.*/
  uint8_t buffer[PLATFORM_SERIAL_RX_BUFFER_SIZE];


  task void startReceive() {
    if (call UartStream.receive(buffer, PLATFORM_SERIAL_RX_BUFFER_SIZE)!=SUCCESS) post startReceive();
  }

  command error_t StdControl.start ()
  {
    call SerialControl.start();
    return SUCCESS;
  }

  command error_t StdControl.stop ()
  {
    return call SerialControl.stop();
  }

  command error_t HdlcUart.send (uint8_t* buf,uint16_t len)
  {
    return call UartStream.send(buf, len);
  }
  
  async event void UartStream.sendDone( uint8_t* buf, uint16_t len, error_t error )
  {
    signal HdlcUart.sendDone(error);
  }

 
  async event void UartStream.receivedByte (uint8_t rx_byte)
  {
    signal HdlcUart.receivedByte(rx_byte);
  }

  async event void UartStream.receiveDone( uint8_t* buf, uint16_t len, error_t error ) {
    // start new receive
    post startReceive();
  }

  event void SerialControl.startDone(error_t error) {
    post startReceive();
  }

  event void SerialControl.stopDone(error_t error) {

  }



  default async event void HdlcUart.uartError (error_t error) { }

}
