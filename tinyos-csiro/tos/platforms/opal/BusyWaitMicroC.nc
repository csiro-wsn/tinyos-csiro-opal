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
 */

/**
 * Busy wait component as per TEP102. 
 */

module BusyWaitMicroC @safe()
{
    provides interface BusyWait<TMicro,uint16_t>;
    uses interface HplSam3Clock as Clk;
}
implementation
{
    async command void BusyWait.wait(uint16_t dt) __attribute__((noinline)) {
        // based on the current rate we have to adjust the steps
        if (dt > 1){
            // calculate the cycles we should burn 
            volatile uint32_t cyc = (dt * (call Clk.getMainClockSpeed()))/12000;
            //volatile uint32_t cyc = (dt * (call Clk.getMainClockSpeed()))/12000;
            //volatile uint32_t cyc = 12000;
            
            // one cycle in this while loop takes 12 CPU cycles
            atomic {
            while(cyc > 0){
                asm volatile ("    nop\n");
                cyc--;
            }
            }
        }
    }

    async event void Clk.mainClockChanged(){};
}
