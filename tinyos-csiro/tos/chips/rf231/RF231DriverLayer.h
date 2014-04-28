/*
 * Copyright (c) 2007, Vanderbilt University
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
 *
 * Author: Miklos Maroti
 */

#ifndef __RF231DRIVERLAYER_H__
#define __RF231DRIVERLAYER_H__

typedef nx_struct rf231_header_t
{
	nxle_uint8_t length;
} rf231_header_t;

typedef struct rf231_metadata_t
{
	uint8_t lqi;
	union
	{
		uint8_t power;
		uint8_t rssi;
	};
} rf231_metadata_t;

enum rf231_registers_enum
{
	RF231_TRX_STATUS = 0x01,
	RF231_TRX_STATE = 0x02,
	RF231_TRX_CTRL_0 = 0x03,
    RF231_TRX_CTRL_1 = 0x04,
	RF231_PHY_TX_PWR = 0x05,
	RF231_PHY_RSSI = 0x06,
	RF231_PHY_ED_LEVEL = 0x07,
	RF231_PHY_CC_CCA = 0x08,
	RF231_CCA_THRES = 0x09,
	RF231_ANT_DIV = 0x0D,
	RF231_IRQ_MASK = 0x0E,
	RF231_IRQ_STATUS = 0x0F,
	RF231_VREG_CTRL = 0x10,
	RF231_BATMON = 0x11,
	RF231_XOSC_CTRL = 0x12,
	RF231_PLL_CF = 0x1A,
	RF231_PLL_DCU = 0x1B,
	RF231_PART_NUM = 0x1C,
	RF231_VERSION_NUM = 0x1D,
	RF231_MAN_ID_0 = 0x1E,
	RF231_MAN_ID_1 = 0x1F,
	RF231_SHORT_ADDR_0 = 0x20,
	RF231_SHORT_ADDR_1 = 0x21,
	RF231_PAN_ID_0 = 0x22,
	RF231_PAN_ID_1 = 0x23,
	RF231_IEEE_ADDR_0 = 0x24,
	RF231_IEEE_ADDR_1 = 0x25,
	RF231_IEEE_ADDR_2 = 0x26,
	RF231_IEEE_ADDR_3 = 0x27,
	RF231_IEEE_ADDR_4 = 0x28,
	RF231_IEEE_ADDR_5 = 0x29,
	RF231_IEEE_ADDR_6 = 0x2A,
	RF231_IEEE_ADDR_7 = 0x2B,
	RF231_XAH_CTRL = 0x2C,
	RF231_CSMA_SEED_0 = 0x2D,
	RF231_CSMA_SEED_1 = 0x2E,
};

enum rf231_trx_register_enums
{
	RF231_CCA_DONE = 1 << 7,
	RF231_CCA_STATUS = 1 << 6,
	RF231_TRX_STATUS_MASK = 0x1F,
	RF231_P_ON = 0,
	RF231_BUSY_RX = 1,
	RF231_BUSY_TX = 2,
	RF231_RX_ON = 6,
	RF231_TRX_OFF = 8,
	RF231_PLL_ON = 9,
	RF231_SLEEP = 15,
	RF231_BUSY_RX_AACK = 17,
	RF231_BUSR_TX_ARET = 18,
	RF231_RX_AACK_ON = 22,
	RF231_TX_ARET_ON = 25,
	RF231_RX_ON_NOCLK = 28,
	RF231_AACK_ON_NOCLK = 29,
	RF231_BUSY_RX_AACK_NOCLK = 30,
	RF231_STATE_TRANSITION_IN_PROGRESS = 31,
	RF231_TRAC_STATUS_MASK = 0xE0,
	RF231_TRAC_SUCCESS = 0,
	RF231_TRAC_SUCCESS_DATA_PENDING = 1 << 5,
	RF231_TRAC_CHANNEL_ACCESS_FAILURE = 3 << 5,
	RF231_TRAC_NO_ACK = 5 << 5,
	RF231_TRAC_INVALID = 7 << 5,
	RF231_TRX_CMD_MASK = 0x1F,
	RF231_NOP = 0,
	RF231_TX_START = 2,
	RF231_FORCE_TRX_OFF = 3,
	RF231_RX_CRC_VALID = 1 << 7,
};

enum rf231_phy_register_enums
{
	RF231_TX_AUTO_CRC_ON = 1 << 7,
	RF231_TX_PWR_MASK = 0x0F,
	RF231_RSSI_MASK = 0x1F,
	RF231_CCA_REQUEST = 1 << 7,
	RF231_CCA_MODE_0 = 0 << 5,
	RF231_CCA_MODE_1 = 1 << 5,
	RF231_CCA_MODE_2 = 2 << 5,
	RF231_CCA_MODE_3 = 3 << 5,
	RF231_CHANNEL_MASK = 0x1F,
	RF231_CCA_CS_THRES_SHIFT = 4,
	RF231_CCA_ED_THRES_SHIFT = 0,
};

enum rf231_irq_register_enums
{
	RF231_IRQ_BAT_LOW = 1 << 7,
	RF231_IRQ_TRX_UR = 1 << 6,
	RF231_IRQ_AMI = 1 << 5,
	RF231_IRQ_CCA_ED_DONE = 1 << 4,
	RF231_IRQ_TRX_END = 1 << 3,
	RF231_IRQ_RX_START = 1 << 2,
	RF231_IRQ_PLL_UNLOCK = 1 << 1,
	RF231_IRQ_PLL_LOCK = 1 << 0,
};

enum rf231_control_register_enums
{
	RF231_AVREG_EXT = 1 << 7,
	RF231_AVDD_OK = 1 << 6,
	RF231_DVREG_EXT = 1 << 3,
	RF231_DVDD_OK = 1 << 2,
	RF231_BATMON_OK = 1 << 5,
	RF231_BATMON_VHR = 1 << 4,
	RF231_BATMON_VTH_MASK = 0x0F,
	RF231_XTAL_MODE_OFF = 0 << 4,
	RF231_XTAL_MODE_EXTERNAL = 4 << 4,
	RF231_XTAL_MODE_INTERNAL = 15 << 4,
};

enum rf231_pll_register_enums
{
	RF231_PLL_CF_START = 1 << 7,
	RF231_PLL_DCU_START = 1 << 7,
};

enum rf231_spi_command_enums
{
	RF231_CMD_REGISTER_READ = 0x80,
	RF231_CMD_REGISTER_WRITE = 0xC0,
	RF231_CMD_REGISTER_MASK = 0x3F,
	RF231_CMD_FRAME_READ = 0x20,
	RF231_CMD_FRAME_WRITE = 0x60,
	RF231_CMD_SRAM_READ = 0x00,
	RF231_CMD_SRAM_WRITE = 0x40,
};

#endif//__RF231DRIVERLAYER_H__
