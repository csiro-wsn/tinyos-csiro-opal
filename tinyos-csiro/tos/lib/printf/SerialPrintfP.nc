/*
 * Copyright (c) 2005-2006 Rincon Research Corporation
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
 * - Neither the name of the Rincon Research Corporation nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE
 * RINCON RESEARCH OR ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE
 */
 
/** 
 * @author David Moss
 * @author Kevin Klues
 */
module SerialPrintfP {
  uses {
    interface StdControl as UartControl;
    interface UartStream;
  }
  provides {
    interface StdControl;
    interface Init;
    interface Putchar;
  }
  uses interface PrintfQueue<uint8_t> as Queue;
}

implementation {

  enum {
    S_STARTED,
    S_FLUSHING,
  };

  uint8_t state = S_STARTED;
  uint8_t buffer[PRINTF_BUFFER_SIZE];
  
  task void flushBuffer() {
    int i;
    uint16_t length = call Queue.size();
    for(i=0; i<length; i++)
      buffer[i] = call Queue.dequeue();
     if (call UartStream.send(buffer, length)!=SUCCESS) {
       state = S_STARTED;
     }    
  }

  command error_t Init.init () {
    atomic state = S_STARTED;
    return SUCCESS;
  }

  command error_t StdControl.start ()
  {
    return call UartControl.start();
  }

  command error_t StdControl.stop ()
  {
    return call UartControl.stop();
  }

  int printfflush() @C() @spontaneous() {
    if (state == S_STARTED) {
       state = S_FLUSHING;
       post flushBuffer();
    }
    return SUCCESS;
  }

#undef putchar
  command int Putchar.putchar (int c)
  {
    if((state == S_STARTED) && (call Queue.size() >= ((PRINTF_BUFFER_SIZE)/2))) {
      state = S_FLUSHING;
      post flushBuffer();
    }
    atomic {
      if(call Queue.enqueue(c) == SUCCESS)
        return 0;
      else return -1;
    }
  }


  async event void UartStream.sendDone( uint8_t* buf, uint16_t len, error_t error ) {
    if(call Queue.size() > 0)
      post flushBuffer();
    state = S_STARTED;
  }

  async event void UartStream.receiveDone( uint8_t* buf, uint16_t len, error_t error ) {};
  async event void UartStream.receivedByte( uint8_t byte ) {};



}
