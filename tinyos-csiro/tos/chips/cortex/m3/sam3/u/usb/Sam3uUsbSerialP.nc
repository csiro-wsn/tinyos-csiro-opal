/*
 * Copyright (c) 2010 CSIRO Australia
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
 */

/**
 * High Speed USB to Serial implementation
 *
 * @author Kevin Klues
 * @author Philipp Sommer
 */

#include <sam3uudphshardware.h>


// at91lib files for cdc-serial

//#include <board.h>

#include <usb/common/core/USBInterfaceRequest.c>
#include <usb/common/core/USBGetDescriptorRequest.c>
#include <usb/common/core/USBSetAddressRequest.c>
#include <usb/common/core/USBFeatureRequest.c>
#include <usb/common/core/USBGenericRequest.c>
#include <usb/common/core/USBEndpointDescriptor.c>
#include <usb/common/core/USBSetConfigurationRequest.c>
#include <usb/common/core/USBGenericDescriptor.c>
#include <usb/common/core/USBConfigurationDescriptor.c>
#include <usb/device/core/USBD_UDPHS.c>
#include <usb/device/core/USBDDriver.c>
#include <usb/device/cdc-serial/CDCDSerialDriver.c>
#include <usb/device/cdc-serial/CDCDSerialDriverDescriptors.c>
#include <usb/common/cdc/CDCLineCoding.c>
#include <usb/common/cdc/CDCSetControlLineStateRequest.c>


/**
* This module provides a serial driver for the USB port of the SAM3U.
* A read request will be started immediately after the device has been configured by the USB
* host. This has to be done since the TinyOS serial stack expects characters being received byte-by-byte
* after enabling the serial port.
*/


module Sam3uUsbSerialP {
  provides {
    interface Init;
    interface SplitControl;
    interface StdControl;
    interface UartStream;
    interface UartByte;
  } 
  uses {
    interface HplNVICInterruptCntl as UDPHSInterrupt;
    interface HplSam3PeripheralClockCntl as UDPHSClockControl;
    interface FunctionWrapper as UdphsInterruptWrapper;
  }
}
implementation {
 

  norace struct {
    volatile bool rlock   : 1;
    volatile bool wlock   : 1;
  } flags;


  norace uint8_t buffer[USBEndpointDescriptor_MAXBULKSIZE_HS]; // maximum bulk packet size 512 bytes

  norace uint8_t* rbuf;
  norace uint8_t* wbuf;
  norace uint16_t rlen;
  norace uint16_t wlen;
  norace error_t werror;
  norace error_t rerror;

  task void signalSendDone();
  task void signalReceiveDone();

  //------------------------------------------------------------------------------
  //         Callbacks re-implementation
  //------------------------------------------------------------------------------

  //------------------------------------------------------------------------------
  /// Invoked when the USB driver is reset. Does nothing by default.
  //------------------------------------------------------------------------------
  void USBDCallbacks_Reset(void) @spontaneous() @C()
  {
    // Does nothing
    signal SplitControl.stopDone(SUCCESS);
  }

  void USBDCallbacks_Initialized(void) @spontaneous() @C()
  { 
    // Set the Interrupt Priority
    call UDPHSInterrupt.configure(IRQ_PRIO_UDPHS);
    call UDPHSInterrupt.enable();

    flags.rlock = 0;
    flags.wlock = 0;
  }

  //------------------------------------------------------------------------------
  /// Invoked when the USB device leaves the Suspended state. 
  //------------------------------------------------------------------------------
  void USBDCallbacks_Resumed(void) @spontaneous() @C()
  {

    flags.rlock = 0;
    flags.wlock = 0;

  }
  
  //------------------------------------------------------------------------------
  /// Invoked when the USB device gets suspended.
  //------------------------------------------------------------------------------
  void USBDCallbacks_Suspended(void) @spontaneous() @C()
  {

    // check for pending operations
    if (flags.rlock) {
      rerror = FAIL;
      rlen = 0;
      post signalReceiveDone();
    }

    if (flags.wlock) {
      werror = FAIL;
      wlen = 0;
      post signalSendDone();
    }

    flags.wlock = 1;
    flags.rlock = 1;

  }

  //------------------------------------------------------------------------------
  /// Notifies of a change in the currently active setting of an interface.
  /// \param interface  Number of the interface whose setting has changed.
  /// \param setting  New interface setting.
  //------------------------------------------------------------------------------

  void USBDDriverCallbacks_InterfaceSettingChanged(unsigned char interf, unsigned char setting) @spontaneous() @C()
  {
    // does nothing
  }

  //------------------------------------------------------------------------------
  /// Invoked when the configuration of the device has changed.
  //------------------------------------------------------------------------------
  void USBDDriverCallbacks_ConfigurationChanged(unsigned char cfgnum) @spontaneous() @C()
  {
    // TODO: check configuration number
    signal SplitControl.startDone(SUCCESS);
  }

  //------------------------------------------------------------------------------
  /// Callback invoked when data has been received on the USB.
  //------------------------------------------------------------------------------
  void UsbDataReceived(unsigned int unused,
                       unsigned char status,
                       unsigned int received,
                       unsigned int remaining) @spontaneous() @C()
  {
    rerror = (status == USBD_STATUS_SUCCESS) ? SUCCESS : FAIL;
    rlen = received;
    post signalReceiveDone();
  }
  
  //------------------------------------------------------------------------------
  /// Callback invoked when data has been written on the USB.
  //------------------------------------------------------------------------------
  void UsbDataWritten(unsigned int unused,
                      unsigned char status,
                      unsigned int written,
                      unsigned int remaining) @spontaneous() @C()
  {
    werror = (status == USBD_STATUS_SUCCESS) ? SUCCESS : FAIL;
    wlen = written;
    post signalSendDone();
  }


  error_t UsbStartReceive( uint8_t* buf, uint16_t len ) @spontaneous() @C()
  {
    int e;
    if(flags.rlock)
      return EBUSY;

    flags.rlock = 1;
    rbuf = buf;
    rlen = len;
    e = CDCDSerialDriver_Read(rbuf, rlen, (TransferCallback) UsbDataReceived, 0);
    if (e != USBD_STATUS_SUCCESS) {
      flags.rlock = 0;
      return FAIL;
    }
    return SUCCESS;
  }

  error_t UsbStartSend(uint8_t* buf, uint16_t len) @spontaneous() @C()
  {
    int e;
    if(flags.wlock)
      return EBUSY;

    flags.wlock = 1;
    wbuf = buf;
    e = CDCDSerialDriver_Write(wbuf, len, (TransferCallback) UsbDataWritten, 0);
    if (e != USBD_STATUS_SUCCESS) {
      flags.wlock = 0;
      return FAIL;
    }
    return SUCCESS;
  }



  task void signalSendDone() {
    flags.wlock = 0;
    signal UartStream.sendDone(wbuf, wlen, werror);
  }

  task void signalReceiveDone() {

    uint8_t i;

    flags.rlock = 0;
    for(i=0; i<rlen; i++)
      signal UartStream.receivedByte(rbuf[i]);
    signal UartStream.receiveDone(rbuf, rlen, rerror);
  }

  command error_t Init.init() {
    return SUCCESS;
  }

  command error_t StdControl.start() {

    // Enable the UDPHS clock in the PMC
    call UDPHSClockControl.enable();

    // Enable the UPLL
    PMC->uckr.bits.upllcount = 3;
    PMC->uckr.bits.upllen = 1;
    while(!PMC->sr.bits.locku);

    // Enable udphs
    UDPHS->ctrl.bits.en_udphs = 1;

    // BOT driver initialization
    CDCDSerialDriver_Initialize();
    // Connect pull-up, wait for configuration
    USBD_Connect();

    return SUCCESS;
  }

  command error_t StdControl.stop() {

    USBD_Disconnect();

    // Disable the UDPHS clock in the PMC
    call UDPHSClockControl.disable();

    // Disable the UPLL
    PMC->uckr.bits.upllen = 0;

    // Disabel udphs
    UDPHS->ctrl.bits.en_udphs = 0;
    return SUCCESS;
  }

  command error_t SplitControl.start() { return call StdControl.start(); }
  command error_t SplitControl.stop() { return call StdControl.stop(); }


  async command error_t UartByte.send( uint8_t byte) {
    return FAIL;
  }

  async command error_t UartByte.receive( uint8_t* byte, uint8_t timeout ) {
    return FAIL;
  }

  async command error_t UartStream.send( uint8_t* buf, uint16_t len ) {
    return UsbStartSend(buf, len);
  }

  async command error_t UartStream.receive( uint8_t* buf, uint16_t len ) {
    return UsbStartReceive(buf, len);
  }

  async command error_t UartStream.enableReceiveInterrupt() {
    return SUCCESS;
  }

  async command error_t UartStream.disableReceiveInterrupt() {
    return FAIL;
  }


void UdphsIrqHandler(void) @C() @spontaneous()
{
    call UdphsInterruptWrapper.preamble();
    USBD_IrqHandler();
    call UdphsInterruptWrapper.postamble();
}

}

