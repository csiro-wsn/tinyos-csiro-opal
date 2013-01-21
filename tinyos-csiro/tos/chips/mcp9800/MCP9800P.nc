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
 *
 * Implementation of a simple read interface for the MCP9800 temperature
 * sensor.
 *
 * @author: Philipp Sommer <philipp.sommer@csiro.au>
 */


#include "MCP9800.h"

module MCP9800P {
   provides interface Read<uint16_t>;
   provides interface Init;
   uses {
    interface Timer<TMilli> as TimerSensor;
    interface Resource;
    interface ResourceRequested;
    interface ResourceConfigure;
    interface I2CPacket<TI2CBasicAddr> as I2CBasicAddr;
      
  }
}

implementation {

  enum {STATE_IDLE, STATE_SETUP, STATE_SAMPLE};
  
  norace uint16_t temp;
  uint8_t buf[2];
  norace uint8_t state = STATE_IDLE;


  task void startTimer() {
    call TimerSensor.startOneShot(30); // 30ms
  }

  task void signalDone() {
    call Resource.release();
    signal Read.readDone(SUCCESS, temp);
    state = STATE_IDLE;
  } 

  task void signalError() {
    call Resource.release();
    signal Read.readDone(FAIL, 0);
    state = STATE_IDLE;
  } 

  command error_t Init.init() {
    state = STATE_IDLE;
    call ResourceConfigure.configure();
    return SUCCESS;
  }

  command error_t Read.read(){
    return call Resource.request();
  }

  event void TimerSensor.fired() {
      error_t error;
      buf[0] = MCP9800_REGADDR_TEMPERATURE;
      state = STATE_SAMPLE;
      error = call I2CBasicAddr.write((I2C_START | I2C_STOP),  MCP9800_ADDRESS, 1, buf);
      if(error) post signalError();
  }

  event void Resource.granted(){
    error_t error;
    // setup one-shot mode, 9-bits
    state = STATE_SETUP;
    buf[0] = MCP9800_REGADDR_CONFIGURATION;
    buf[1] = MCP9800_CONFIGURATION_DEFAULT | 0x80; // enable one-shot mode

    error = call I2CBasicAddr.write((I2C_START | I2C_STOP), MCP9800_ADDRESS, 2, buf); 
    if(error) post signalError();
  }
  
  async event void I2CBasicAddr.readDone(error_t error, uint16_t addr, uint8_t length, uint8_t *data){
    if(call Resource.isOwner()) {
	uint16_t tmp = (data[0] << 8) | data[1];
	temp = tmp;
        if (error) post signalError();
        else post signalDone();
    }
  }

  async event void I2CBasicAddr.writeDone(error_t error, uint16_t addr, uint8_t length, uint8_t *data){
    if(call Resource.isOwner()){
      if(error) post signalDone();
      else if (state==STATE_SETUP) post startTimer();
      else if (state==STATE_SAMPLE) {
        error = call I2CBasicAddr.read((I2C_START | I2C_STOP), MCP9800_ADDRESS, 2, buf);
        if(error) post signalError();
      }
    }
  }   
  
  async event void ResourceRequested.requested(){ }
  async event void ResourceRequested.immediateRequested(){ }	  
  
}
