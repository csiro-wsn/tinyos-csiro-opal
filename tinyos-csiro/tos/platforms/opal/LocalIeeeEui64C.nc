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
 * @author Philipp Sommer <philipp.sommer@csiro.au> (Opal port)
 *
 */

#include "PlatformIeeeEui64.h"

module LocalIeeeEui64C {
  provides interface LocalIeeeEui64;
} 
implementation {

  command ieee_eui64_t LocalIeeeEui64.getId() {
    ieee_eui64_t eui;

    eui.data[0] = IEEE_EUI64_COMPANY_ID_0;
    eui.data[1] = IEEE_EUI64_COMPANY_ID_1;
    eui.data[2] = IEEE_EUI64_COMPANY_ID_2;

    eui.data[3] = IEEE_EUI64_SERIAL_ID_0;
    eui.data[4] = IEEE_EUI64_SERIAL_ID_1;

    eui.data[5] = 0;
    eui.data[6] = TOS_NODE_ID >> 8;
    eui.data[7] = TOS_NODE_ID & 0xFF;
    return eui;
  }
}
