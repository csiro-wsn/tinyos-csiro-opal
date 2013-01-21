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
 * @author Wanja Hofer <wanja@cs.fau.de>
 * @author Philipp Sommer <philipp.sommer@csiro.au> (Opal port)
 *
 */


#include "hardware.h"

module PlatformP
{
  provides
  {
    interface Init;
  }
  uses
  {
    interface Init as LedsInit;
    interface Init as FlashInit;
    interface Init as MoteClockInit;
    interface Init as MoteTimerInit;
    interface Sam3LowPower;
  }
}

implementation
{
  command error_t Init.init()
  {
    /* I/O pin configuration, clock calibration, and LED configuration
     * (see TEP 107)
     */
    call FlashInit.init();
    call LedsInit.init();
    call MoteClockInit.init();
    call MoteTimerInit.init();

    return SUCCESS;
  }

 async event void Sam3LowPower.customizePio() {

    AT91C_BASE_PIOC->PIO_OER |= AT91C_PIO_PC6;		// Opal LED1
    AT91C_BASE_PIOC->PIO_OER |= AT91C_PIO_PC7;		// Opal LED2
    AT91C_BASE_PIOC->PIO_OER |= AT91C_PIO_PC8;		// Opal LED3
    AT91C_BASE_PIOC->PIO_OER |= AT91C_PIO_PC23;		// RF212 PA enable
    AT91C_BASE_PIOC->PIO_OER |= AT91C_PIO_PC24;		// RF230 PA enable
    AT91C_BASE_PIOC->PIO_OER |= AT91C_PIO_PC25;		// Voltage measurements enable
    AT91C_BASE_PIOC->PIO_OER |= AT91C_PIO_PC26;		// TPM module enable

    AT91C_BASE_PIOC->PIO_CODR |= AT91C_PIO_PC23;	// disable RF212 PA
    AT91C_BASE_PIOC->PIO_CODR |= AT91C_PIO_PC24;	// disable RF230 PA
    AT91C_BASE_PIOC->PIO_CODR |= AT91C_PIO_PC25;	// disable Voltage measurement
    AT91C_BASE_PIOC->PIO_CODR |= AT91C_PIO_PC27;	// disable TPM module

    AT91C_BASE_PIOB->PIO_PPUDR |= AT91C_PIO_PB0;	// RF212 IRQ
    AT91C_BASE_PIOB->PIO_PPUDR |= AT91C_PIO_PB1;	// RF230 IRQ
    AT91C_BASE_PIOC->PIO_PPUDR |= AT91C_PIO_PC6;	// LED1
    AT91C_BASE_PIOC->PIO_PPUDR |= AT91C_PIO_PC7;	// LED2
    AT91C_BASE_PIOC->PIO_PPUDR |= AT91C_PIO_PC8;	// LED3
    AT91C_BASE_PIOC->PIO_PPUDR |= AT91C_PIO_PC23;	// RF212 PA
    AT91C_BASE_PIOC->PIO_PPUDR |= AT91C_PIO_PC24;	// RF230 PA
    AT91C_BASE_PIOC->PIO_PPUDR |= AT91C_PIO_PC25;	// Voltage
    AT91C_BASE_PIOC->PIO_PPUDR |= AT91C_PIO_PC26;	// TPM	
  }

  default command error_t LedsInit.init()
  {
    AT91C_BASE_PIOC->PIO_OER |= AT91C_PIO_PC6;
    AT91C_BASE_PIOC->PIO_OER |= AT91C_PIO_PC7;
    AT91C_BASE_PIOC->PIO_OER |= AT91C_PIO_PC8;

    AT91C_BASE_PIOC->PIO_SODR |= AT91C_PIO_PC6;
    AT91C_BASE_PIOC->PIO_SODR |= AT91C_PIO_PC7;
    AT91C_BASE_PIOC->PIO_SODR |= AT91C_PIO_PC8;
    return SUCCESS;
  }
}
