/*
* Copyright (c) 2009, University of Szeged
* All rights reserved.
*
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions
* are met:
*
* - Redistributions of source code must retain the above copyright
* notice, this list of conditions and the following disclaimer.
* - Redistributions in binary form must reproduce the above
* copyright notice, this list of conditions and the following
* disclaimer in the documentation and/or other materials provided
* with the distribution.
* - Neither the name of University of Szeged nor the names of its
* contributors may be used to endorse or promote products derived
* from this software without specific prior written permission.
*
* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
* "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
* LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
* FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
* COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
* INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
* (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
* SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
* HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
* STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
* ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
* OF THE POSSIBILITY OF SUCH DAMAGE.
*
* Author: Miklos Maroti
*/

#include <RF231DriverLayer.h>
#include <Tasklet.h>
#include <RadioAssert.h>
#include <TimeSyncMessageLayer.h>
#include <RadioConfig.h>

module RF231DriverHwAckP
{
	provides
	{
		interface Init as PlatformInit @exactlyonce();
		interface Init as SoftwareInit @exactlyonce();

		interface RadioState;
		interface RadioSend;
		interface RadioReceive;
		interface RadioCCA;
		interface RadioPacket;
		interface Read<uint8_t> as ReadRSSI;

		interface PacketField<uint8_t> as PacketTransmitPower;
		interface PacketField<uint8_t> as PacketRSSI;
		interface PacketField<uint8_t> as PacketTimeSyncOffset;
		interface PacketField<uint8_t> as PacketLinkQuality;
		interface LinkPacketMetadata;

		interface PacketAcknowledgements;
	}

	uses
	{
		interface GeneralIO as SELN;
		interface Resource as SpiResource;

		interface FastSpiByte;

		interface GeneralIO as SLP_TR;
		interface GeneralIO as RSTN;

		interface GpioCapture as IRQ;

		interface BusyWait<TMicro, uint16_t>;
		interface LocalTime<TRadio>;

		interface RF231DriverConfig as Config;

		interface PacketFlag as TransmitPowerFlag;
		interface PacketFlag as RSSIFlag;
		interface PacketFlag as TimeSyncFlag;

		interface PacketTimeStamp<TRadio, uint32_t>;

		interface Tasklet;
		interface RadioAlarm;

		interface PacketFlag as AckReceivedFlag;
		interface Ieee154PacketLayer;
		interface ActiveMessageAddress;

#ifdef RADIO_DEBUG
		interface DiagMsg;
#endif
	}
}

implementation
{
	RF231_header_t* getHeader(message_t* msg)
	{
		return ((void*)msg) + call Config.headerLength(msg);
	}

	void* getPayload(message_t* msg)
	{
		return ((void*)msg) + call RadioPacket.headerLength(msg);
	}

	RF231_metadata_t* getMeta(message_t* msg)
	{
		return ((void*)msg) + sizeof(message_t) - call RadioPacket.metadataLength(msg);
	}

/*----------------- STATE -----------------*/

	tasklet_norace uint8_t state;
	enum
	{
		STATE_P_ON = 0,
		STATE_SLEEP = 1,
		STATE_SLEEP_2_TRX_OFF = 2,
		STATE_TRX_OFF = 3,
		STATE_TRX_OFF_2_RX_ON = 4,
		STATE_RX_ON = 5,
		STATE_BUSY_TX_2_RX_ON = 6,
	};

	tasklet_norace uint8_t cmd;
	enum
	{
		CMD_NONE = 0,			// the state machine has stopped
		CMD_TURNOFF = 1,		// goto SLEEP state
		CMD_STANDBY = 2,		// goto TRX_OFF state
		CMD_TURNON = 3,			// goto RX_ON state
		CMD_TRANSMIT = 4,		// currently transmitting a message
		CMD_CCA = 6,			// performing clear chanel assesment
		CMD_CHANNEL = 7,		// changing the channel
		CMD_SIGNAL_DONE = 8,		// signal the end of the state transition
		CMD_DOWNLOAD = 9,		// download the received message
		CMD_RSSI = 10,			// sample RSSI
	};

	norace bool radioIrq;

	tasklet_norace uint8_t txPower;
	tasklet_norace uint8_t channel;

	tasklet_norace message_t* rxMsg;
	message_t rxMsgBuffer;

	uint16_t capturedTime;	// the current time when the last interrupt has occured

	tasklet_norace uint8_t rssi;

/*----------------- REGISTER -----------------*/

	inline void writeRegister(uint8_t reg, uint8_t value)
	{
		RADIO_ASSERT( call SpiResource.isOwner() );
		RADIO_ASSERT( reg == (reg & RF231_CMD_REGISTER_MASK) );

		call SELN.clr();
		call FastSpiByte.splitWrite(RF231_CMD_REGISTER_WRITE | reg);
		call FastSpiByte.splitReadWrite(value);
		call FastSpiByte.splitRead();
		call SELN.set();
	}

	inline uint8_t readRegister(uint8_t reg)
	{
		RADIO_ASSERT( call SpiResource.isOwner() );
		RADIO_ASSERT( reg == (reg & RF231_CMD_REGISTER_MASK) );

		call SELN.clr();
		call FastSpiByte.splitWrite(RF231_CMD_REGISTER_READ | reg);
		call FastSpiByte.splitReadWrite(0);
		reg = call FastSpiByte.splitRead();
		call SELN.set();

		return reg;
	}

/*----------------- ALARM -----------------*/

	enum
	{
		SLEEP_WAKEUP_TIME = (uint16_t)(880 * RADIO_ALARM_MICROSEC),
		PLL_CALIBRATION_TIME = (uint16_t)(180 * RADIO_ALARM_MICROSEC),
		CCA_REQUEST_TIME = (uint16_t)(140 * RADIO_ALARM_MICROSEC),

		// 8 undocumented delay, 128 for CSMA, 16 for delay, 5*32 for preamble and SFD
		TX_SFD_DELAY = (uint16_t)((8 + 128 + 16 + 5*32) * RADIO_ALARM_MICROSEC),

		// 32 for frame length, 16 for delay
		RX_SFD_DELAY = (uint16_t)((32 + 16) * RADIO_ALARM_MICROSEC),
	};

	tasklet_async event void RadioAlarm.fired()
	{
		if( state == STATE_SLEEP_2_TRX_OFF )
			state = STATE_TRX_OFF;
		else if( state == STATE_TRX_OFF_2_RX_ON )
		{
			RADIO_ASSERT( cmd == CMD_TURNON || cmd == CMD_CHANNEL );

			state = STATE_RX_ON;
			cmd = CMD_SIGNAL_DONE;
		}
		else if( cmd == CMD_CCA )
		{
			uint8_t cca;

			RADIO_ASSERT( state == STATE_RX_ON );

			cmd = CMD_NONE;
			cca = readRegister(RF231_TRX_STATUS);

			RADIO_ASSERT( (cca & RF231_TRX_STATUS_MASK) == RF231_RX_AACK_ON );

			signal RadioCCA.done( (cca & RF231_CCA_DONE) ? ((cca & RF231_CCA_STATUS) ? SUCCESS : EBUSY) : FAIL );
		}
		else
			RADIO_ASSERT(FALSE);

		// make sure the rest of the command processing is called
		call Tasklet.schedule();
	}

/*----------------- INIT -----------------*/

	command error_t PlatformInit.init()
	{
		call SELN.makeOutput();
		call SELN.set();
		call SLP_TR.makeOutput();
		call SLP_TR.clr();
		call RSTN.makeOutput();
		call RSTN.set();

		#ifdef DEBUGGING_PIN_RF231_TX_INIT
	        DEBUGGING_PIN_RF231_TX_INIT;
		#endif 

		#ifdef DEBUGGING_PIN_RF231_RX_INIT
	        DEBUGGING_PIN_RF231_RX_INIT;
		#endif 


		rxMsg = &rxMsgBuffer;

		return SUCCESS;
	}

	task void setupRadio()
	{
		// for powering up the radio
		call SpiResource.request();
	}


	command error_t SoftwareInit.init()
	{
		post setupRadio();
		return SUCCESS;
	}

	void initRadio()
	{
		uint16_t temp;

		call BusyWait.wait(510);

		call RSTN.clr();
		call SLP_TR.clr();
		call BusyWait.wait(6);
		call RSTN.set();

		writeRegister(RF231_TRX_CTRL_0, RF231_TRX_CTRL_0_VALUE);
		writeRegister(RF231_TRX_STATE, RF231_TRX_OFF);

		call BusyWait.wait(510);

		writeRegister(RF231_IRQ_MASK, RF231_IRQ_TRX_UR | RF231_IRQ_TRX_END );
		writeRegister(RF231_CCA_THRES, RF231_CCA_THRES_VALUE);
		writeRegister(RF231_PHY_TX_PWR, RF231_TX_AUTO_CRC_ON | (RF231_DEF_RFPOWER & RF231_TX_PWR_MASK));

		txPower = RF231_DEF_RFPOWER & RF231_TX_PWR_MASK;
		channel = RF231_DEF_CHANNEL & RF231_CHANNEL_MASK;
		writeRegister(RF231_PHY_CC_CCA, RF231_CCA_MODE_VALUE | channel);

		writeRegister(RF231_XAH_CTRL, 0x4); // AACK_ACK_TIME set to 1
		writeRegister(RF231_CSMA_SEED_1, 0);

		temp = call ActiveMessageAddress.amGroup();
		writeRegister(RF231_PAN_ID_0, temp);
		writeRegister(RF231_PAN_ID_1, temp >> 8);

		call SLP_TR.set();
		state = STATE_SLEEP;
	}

/*----------------- SPI -----------------*/

	event void SpiResource.granted()
	{
		call SELN.makeOutput();
		call SELN.set();

		if( state == STATE_P_ON )
		{
			initRadio();
			call SpiResource.release();
		}
		else
			call Tasklet.schedule();
	}

	bool isSpiAcquired()
	{
		if( call SpiResource.isOwner() )
			return TRUE;

		if( call SpiResource.immediateRequest() == SUCCESS )
		{
			call SELN.makeOutput();
			call SELN.set();

			return TRUE;
		}

		call SpiResource.request();
		return FALSE;
	}

/*----------------- CHANNEL -----------------*/

tasklet_async command uint8_t RadioState.getChannel()
	{
		return channel;
	}

	tasklet_async command error_t RadioState.setChannel(uint8_t c)
	{
		c &= RF231_CHANNEL_MASK;

		if( cmd != CMD_NONE )
			return EBUSY;
		else if( channel == c )
			return EALREADY;

		channel = c;
		cmd = CMD_CHANNEL;
		call Tasklet.schedule();

		return SUCCESS;
	}

	inline void changeChannel()
	{
		RADIO_ASSERT( cmd == CMD_CHANNEL );
		RADIO_ASSERT( state == STATE_SLEEP || state == STATE_TRX_OFF || state == STATE_RX_ON );

		if( isSpiAcquired() && call RadioAlarm.isFree() )
		{
			writeRegister(RF231_PHY_CC_CCA, RF231_CCA_MODE_VALUE | channel);

			if( state == STATE_RX_ON )
			{
				call RadioAlarm.wait(PLL_CALIBRATION_TIME);
				state = STATE_TRX_OFF_2_RX_ON;
			}
			else
				cmd = CMD_SIGNAL_DONE;
		}
	}

/*----------------- TURN ON/OFF -----------------*/

	inline void changeState()
	{
		if( (cmd == CMD_STANDBY || cmd == CMD_TURNON)
			&& state == STATE_SLEEP && call RadioAlarm.isFree() )
		{
			call SLP_TR.clr();
			#ifdef DEBUGGING_PIN_RF231_ON   
			DEBUGGING_PIN_RF231_ON;
			#endif 
			call RadioAlarm.wait(SLEEP_WAKEUP_TIME);
			state = STATE_SLEEP_2_TRX_OFF;
		}
		else if( cmd == CMD_TURNON && state == STATE_TRX_OFF
			&& isSpiAcquired() && call RadioAlarm.isFree() )
		{
			uint16_t temp;

			RADIO_ASSERT( ! radioIrq );

			readRegister(RF231_IRQ_STATUS); // clear the interrupt register
			call IRQ.captureRisingEdge();

			// setChannel was ignored in SLEEP because the SPI was not working, so do it here
			writeRegister(RF231_PHY_CC_CCA, RF231_CCA_MODE_VALUE | channel);

			temp = call ActiveMessageAddress.amAddress();
			writeRegister(RF231_SHORT_ADDR_0, temp);
			writeRegister(RF231_SHORT_ADDR_1, temp >> 8);

			call RadioAlarm.wait(PLL_CALIBRATION_TIME);
			writeRegister(RF231_TRX_STATE, RF231_RX_AACK_ON);
			state = STATE_TRX_OFF_2_RX_ON;
			#ifdef DEBUGGING_PIN_RF231_ON   
			DEBUGGING_PIN_RF231_ON;
			#endif 
		}
		else if( (cmd == CMD_TURNOFF || cmd == CMD_STANDBY)
			&& state == STATE_RX_ON && isSpiAcquired() )
		{
			writeRegister(RF231_TRX_STATE, RF231_FORCE_TRX_OFF);

			call IRQ.disable();
			radioIrq = FALSE;

			#ifdef DEBUGGING_PIN_RF231_OFF   
			DEBUGGING_PIN_RF231_OFF;
			#endif 
			state = STATE_TRX_OFF;
		}

		if( cmd == CMD_TURNOFF && state == STATE_TRX_OFF )
		{
			readRegister(RF231_IRQ_STATUS); // clear the interrupt register
			call SLP_TR.set();
			state = STATE_SLEEP;
			cmd = CMD_SIGNAL_DONE;
		}
		else if( cmd == CMD_STANDBY && state == STATE_TRX_OFF )
			cmd = CMD_SIGNAL_DONE;
	}

	tasklet_async command error_t RadioState.turnOff()
	{
		if( cmd != CMD_NONE )
			return EBUSY;
		else if( state == STATE_SLEEP )
			return EALREADY;

		cmd = CMD_TURNOFF;
		call Tasklet.schedule();

		return SUCCESS;
	}

	tasklet_async command error_t RadioState.standby()
	{
		if( cmd != CMD_NONE || (state == STATE_SLEEP && ! call RadioAlarm.isFree()) )
			return EBUSY;
		else if( state == STATE_TRX_OFF )
			return EALREADY;

		cmd = CMD_STANDBY;
		call Tasklet.schedule();

		return SUCCESS;
	}

	tasklet_async command error_t RadioState.turnOn()
	{
		if( cmd != CMD_NONE || (state == STATE_SLEEP && ! call RadioAlarm.isFree()) )
			return EBUSY;
		else if( state == STATE_RX_ON )
			return EALREADY;

		cmd = CMD_TURNON;
		call Tasklet.schedule();

		return SUCCESS;
	}

	default tasklet_async event void RadioState.done() { }

	task void changeAddress()
	{
		call Tasklet.suspend();

		if( isSpiAcquired() )
		{
			uint16_t temp = call ActiveMessageAddress.amAddress();
			writeRegister(RF231_SHORT_ADDR_0, temp);
			writeRegister(RF231_SHORT_ADDR_1, temp >> 8);
		}
		else
			post changeAddress();

		call Tasklet.resume();
	}

	async event void ActiveMessageAddress.changed()
	{
		post changeAddress();
	}

/*----------------- TRANSMIT -----------------*/

	tasklet_norace message_t* txMsg;

	tasklet_async command error_t RadioSend.send(message_t* msg)
	{
		uint16_t time;
		uint32_t time32;
		uint8_t* data;
		uint8_t length;
		uint8_t upload1;
		uint8_t upload2;

		if( cmd != CMD_NONE || state != STATE_RX_ON || radioIrq || ! isSpiAcquired())
			return EBUSY;

		length = (call PacketTransmitPower.isSet(msg) ?
			call PacketTransmitPower.get(msg) : RF231_DEF_RFPOWER) & RF231_TX_PWR_MASK;

		if( length != txPower )
		{
			txPower = length;
			writeRegister(RF231_PHY_TX_PWR, RF231_TX_AUTO_CRC_ON | txPower);
		}

		writeRegister(RF231_TRX_STATE, RF231_TX_ARET_ON);

		// do something useful, just to wait a little
		time32 = call LocalTime.get();
		data = getPayload(msg);
		length = getHeader(msg)->length;

		if( call PacketTimeSyncOffset.isSet(msg) )
		{
			// the number of bytes before the embedded timestamp
			upload1 = (((void*)msg) - (void*)data + call PacketTimeSyncOffset.get(msg));

			// the FCS is automatically generated (2 bytes)
			upload2 = length - 2 - upload1;

			// make sure that we have enough space for the timestamp
			RADIO_ASSERT( upload2 >= 4 && upload2 <= 127 );
		}
		else
		{
			upload1 = length - 2;
			upload2 = 0;
		}
		RADIO_ASSERT( upload1 >= 1 && upload1 <= 127 );

		// we have missed an incoming message in this short amount of time
		if( (readRegister(RF231_TRX_STATUS) & RF231_TRX_STATUS_MASK) != RF231_TX_ARET_ON )
		{
			RADIO_ASSERT( (readRegister(RF231_TRX_STATUS) & RF231_TRX_STATUS_MASK) == RF231_BUSY_RX_AACK );

			writeRegister(RF231_TRX_STATE, RF231_RX_AACK_ON);
			return EBUSY;
		}

#ifndef RF231_SLOW_SPI
		atomic
		{
			#ifdef DEBUGGING_PIN_RF231_TX_SET
			DEBUGGING_PIN_RF231_TX_SET;
			#endif 
			call SLP_TR.set();
			time = call RadioAlarm.getNow();
		}
		call SLP_TR.clr();
#endif

		RADIO_ASSERT( ! radioIrq );

		call SELN.clr();
		call FastSpiByte.splitWrite(RF231_CMD_FRAME_WRITE);

		// length | data[0] ... data[length-3] | automatically generated FCS
		call FastSpiByte.splitReadWrite(length);

		do {
			call FastSpiByte.splitReadWrite(*(data++));
		}
		while( --upload1 != 0 );

#ifdef RF231_SLOW_SPI
		atomic
		{
			#ifdef DEBUGGING_PIN_RF231_TX_SET
			DEBUGGING_PIN_RF231_TX_SET;
			#endif 
			call SLP_TR.set();
			time = call RadioAlarm.getNow();
		}
		call SLP_TR.clr();
#endif

		time32 += (int16_t)(time + TX_SFD_DELAY) - (int16_t)(time32);

		if( upload2 != 0 )
		{
			uint32_t absolute = *(timesync_absolute_t*)data;
			*(timesync_relative_t*)data = absolute - time32;

			// do not modify the data pointer so we can reset the timestamp
			RADIO_ASSERT( upload1 == 0 );
			do {
				call FastSpiByte.splitReadWrite(data[upload1]);
			}
			while( ++upload1 != upload2 );

			*(timesync_absolute_t*)data = absolute;
		}

		// wait for the SPI transfer to finish
		call FastSpiByte.splitRead();
		call SELN.set();

		/*
		 * There is a very small window (~1 microsecond) when the RF231 went
		 * into PLL_ON state but was somehow not properly initialized because
		 * of an incoming message and could not go into BUSY_TX. I think the
		 * radio can even receive a message, and generate a TRX_UR interrupt
		 * because of concurrent access, but that message probably cannot be
		 * recovered.
		 *
		 * TODO: this needs to be verified, and make sure that the chip is
		 * not locked up in this case.
		 */

		// go back to RX_ON state when finished
		writeRegister(RF231_TRX_STATE, RF231_RX_AACK_ON);

		call PacketTimeStamp.set(msg, time32);

#ifdef RADIO_DEBUG_MESSAGES
		if( call DiagMsg.record() )
		{
			call DiagMsg.chr('t');
			call DiagMsg.uint32(call PacketTimeStamp.isValid(msg) ? call PacketTimeStamp.timestamp(msg) : 0);
			call DiagMsg.uint16(call RadioAlarm.getNow());
			call DiagMsg.int8(length);
			call DiagMsg.hex8s(getPayload(msg), length - 2);
			call DiagMsg.send();
		}
#endif

		// wait for the TRX_END interrupt
		txMsg = msg;
		state = STATE_BUSY_TX_2_RX_ON;
		cmd = CMD_TRANSMIT;

		// release the SPI bus
		call SpiResource.release();

		return SUCCESS;
	}

	default tasklet_async event void RadioSend.sendDone(error_t error) { }
	default tasklet_async event void RadioSend.ready() { }

/*----------------- CCA -----------------*/

	tasklet_async command error_t RadioCCA.request()
	{
		if( cmd != CMD_NONE || state != STATE_RX_ON || ! isSpiAcquired() || ! call RadioAlarm.isFree() )
			return EBUSY;

		// see Errata B7 of the datasheet
		// writeRegister(RF231_TRX_STATE, RF231_PLL_ON);
		// writeRegister(RF231_TRX_STATE, RF231_RX_AACK_ON);

		writeRegister(RF231_PHY_CC_CCA, RF231_CCA_REQUEST | RF231_CCA_MODE_VALUE | channel);
		call RadioAlarm.wait(CCA_REQUEST_TIME);
		cmd = CMD_CCA;

		return SUCCESS;
	}

	default tasklet_async event void RadioCCA.done(error_t error) { }


/*----------------- RSSI -----------------*/


	task void signalRssiDone()
	{
		signal ReadRSSI.readDone(SUCCESS, rssi);
		cmd = CMD_NONE;
	}

	inline void sampleRssi()
	{
		RADIO_ASSERT( cmd == CMD_RSSI );
		RADIO_ASSERT( state == STATE_RX_ON );

		if( isSpiAcquired() )
		{
			rssi = readRegister(RF231_PHY_RSSI) & RF231_RSSI_MASK;
			post signalRssiDone();
		}
	}

	command error_t ReadRSSI.read()
	{

		if( cmd != CMD_NONE )
			return EBUSY;
		cmd = CMD_RSSI;
		call Tasklet.schedule();
		return SUCCESS;
	}

	default event void ReadRSSI.readDone(error_t result, uint8_t data) { };



/*----------------- RECEIVE -----------------*/

	inline void downloadMessage()
	{
		uint8_t length;
		uint16_t crc;

		call SELN.clr();
		call FastSpiByte.write(RF231_CMD_FRAME_READ);

		// read the length byte
		length = call FastSpiByte.write(0);

		// if correct length
		if( length >= 3 && length <= call RadioPacket.maxPayloadLength() + 2 )
		{
			uint8_t read;
			uint8_t* data;

			// initiate the reading
			call FastSpiByte.splitWrite(0);

			data = getPayload(rxMsg);
			getHeader(rxMsg)->length = length;
			crc = 0;

			// we do not store the CRC field
			length -= 2;

			read = call Config.headerPreloadLength();
			if( length < read )
				read = length;

			length -= read;

			do {
				crc = RF231_CRCBYTE_COMMAND(crc, *(data++) = call FastSpiByte.splitReadWrite(0));
			}
			while( --read != 0  );

			if( signal RadioReceive.header(rxMsg) )
			{
				while( length-- != 0 )
					crc = RF231_CRCBYTE_COMMAND(crc, *(data++) = call FastSpiByte.splitReadWrite(0));

				crc = RF231_CRCBYTE_COMMAND(crc, call FastSpiByte.splitReadWrite(0));
				crc = RF231_CRCBYTE_COMMAND(crc, call FastSpiByte.splitReadWrite(0));

				call PacketLinkQuality.set(rxMsg, call FastSpiByte.splitRead());
			}
			else
			{
				call FastSpiByte.splitRead(); // finish the SPI transfer
				crc = 1;
			}
		}
		else
			crc = 1;

		call SELN.set();

		if( crc == 0 && call PacketTimeStamp.isValid(rxMsg) )
		{
			uint32_t time32 = call PacketTimeStamp.timestamp(rxMsg);
			length = getHeader(rxMsg)->length;

/*
 * If you hate floating point arithmetics and do not care of up to 400 microsecond time stamping errors,
 * then define RF231_HWACK_SLOPPY_TIMESTAMP, which will be significantly faster.
 */
#ifdef RF231_HWACK_SLOPPY_TIMESTAMP
			time32 -= (uint16_t)(RX_SFD_DELAY) + ((uint16_t)(length) << (RADIO_ALARM_MILLI_EXP - 5));
#else
			time32 -= (uint16_t)(RX_SFD_DELAY) + (uint16_t)(32.0 * RADIO_ALARM_MICROSEC * (uint16_t)length);
#endif

			call PacketTimeStamp.set(rxMsg, time32);
		}

#ifdef RADIO_DEBUG_MESSAGES
		if( call DiagMsg.record() )
		{
			length = getHeader(rxMsg)->length;

			call DiagMsg.chr('r');
			call DiagMsg.uint32(call PacketTimeStamp.isValid(rxMsg) ? call PacketTimeStamp.timestamp(rxMsg) : 0);
			call DiagMsg.uint16(call RadioAlarm.getNow());
			call DiagMsg.int8(crc == 0 ? length : -length);
			call DiagMsg.hex8s(getPayload(rxMsg), length - 2);
			call DiagMsg.int8(call PacketRSSI.isSet(rxMsg) ? call PacketRSSI.get(rxMsg) : -1);
			call DiagMsg.uint8(call PacketLinkQuality.isSet(rxMsg) ? call PacketLinkQuality.get(rxMsg) : 0);
			call DiagMsg.send();
		}
#endif

		state = STATE_RX_ON;
		cmd = CMD_NONE;

		// signal only if it has passed the CRC check
		if( crc == 0 )
			rxMsg = signal RadioReceive.receive(rxMsg);
	}

/*----------------- IRQ -----------------*/

	async event void IRQ.captured(uint16_t time)
	{
		RADIO_ASSERT( ! radioIrq );

		atomic
		{
			capturedTime = time;
			radioIrq = TRUE;
		}

		call Tasklet.schedule();
	}

	void serviceRadio()
	{
		if(state != STATE_SLEEP && isSpiAcquired() )
		{
			uint16_t time;
			uint32_t time32;
			uint8_t irq;
			uint8_t temp;

			atomic time = capturedTime;
			radioIrq = FALSE;
			irq = readRegister(RF231_IRQ_STATUS);

#ifdef RADIO_DEBUG
			// TODO: handle this interrupt
			if( irq & RF231_IRQ_TRX_UR )
			{
				if( call DiagMsg.record() )
				{
					call DiagMsg.str("assert ur");
					call DiagMsg.uint16(call RadioAlarm.getNow());
					call DiagMsg.hex8(readRegister(RF231_TRX_STATUS));
					call DiagMsg.hex8(readRegister(RF231_TRX_STATE));
					call DiagMsg.hex8(irq);
					call DiagMsg.uint8(state);
					call DiagMsg.uint8(cmd);
					call DiagMsg.send();
				}
			}
#endif

			if( irq & RF231_IRQ_TRX_END )
			{
				if( cmd == CMD_TRANSMIT )
				{
					RADIO_ASSERT( state == STATE_BUSY_TX_2_RX_ON );

					#ifdef DEBUGGING_PIN_RF231_TX_CLR
					DEBUGGING_PIN_RF231_TX_CLR;
					#endif 

					temp = readRegister(RF231_TRX_STATE) & RF231_TRAC_STATUS_MASK;

					if( call Ieee154PacketLayer.getAckRequired(txMsg) )
						call AckReceivedFlag.setValue(txMsg, temp != RF231_TRAC_NO_ACK);

					state = STATE_RX_ON;
					cmd = CMD_NONE;

					signal RadioSend.sendDone(temp != RF231_TRAC_CHANNEL_ACCESS_FAILURE ? SUCCESS : EBUSY);

					// TODO: we could have missed a received message
					RADIO_ASSERT( ! (irq & RF231_IRQ_RX_START) );
				}
				else if( cmd == CMD_NONE )
				{
					RADIO_ASSERT( state == STATE_RX_ON );

					#ifdef DEBUGGING_PIN_RF231_RX_CLR
					DEBUGGING_PIN_RF231_RX_CLR;
					#endif 

					if( irq == RF231_IRQ_TRX_END )
					{
						call PacketRSSI.set(rxMsg, readRegister(RF231_PHY_ED_LEVEL));

						// TODO: compensate for packet transmission time when downloading
						time32 = call LocalTime.get();
						time32 += (int16_t)(time) - (int16_t)(time32);
						call PacketTimeStamp.set(rxMsg, time32);
					}
					else
					{
						call PacketRSSI.clear(rxMsg);
						call PacketTimeStamp.clear(rxMsg);
					}

					cmd = CMD_DOWNLOAD;
				}
				else
					RADIO_ASSERT(FALSE);
			}
		}
	}

	default tasklet_async event bool RadioReceive.header(message_t* msg)
	{
		return TRUE;
	}

	default tasklet_async event message_t* RadioReceive.receive(message_t* msg)
	{
		return msg;
	}

/*----------------- TASKLET -----------------*/

	task void releaseSpi()
	{
		call SpiResource.release();
	}

	tasklet_async event void Tasklet.run()
	{
		if( radioIrq )
			serviceRadio();

		if( cmd != CMD_NONE )
		{
			if( cmd == CMD_DOWNLOAD )
				downloadMessage();
			else if( CMD_TURNOFF <= cmd && cmd <= CMD_TURNON )
				changeState();
			else if( cmd == CMD_CHANNEL )
				changeChannel();
			else if ( cmd == CMD_RSSI )
				sampleRssi();
			
			if( cmd == CMD_SIGNAL_DONE )
			{
				cmd = CMD_NONE;
				signal RadioState.done();
			}
		}

		if( cmd == CMD_NONE && state == STATE_RX_ON && ! radioIrq )
			signal RadioSend.ready();

		call SpiResource.release();
	}

/*----------------- RadioPacket -----------------*/

	async command uint8_t RadioPacket.headerLength(message_t* msg)
	{
		return call Config.headerLength(msg) + sizeof(RF231_header_t);
	}

	async command uint8_t RadioPacket.payloadLength(message_t* msg)
	{
		return getHeader(msg)->length - 2;
	}

	async command void RadioPacket.setPayloadLength(message_t* msg, uint8_t length)
	{
		RADIO_ASSERT( 1 <= length && length <= 125 );
		RADIO_ASSERT( call RadioPacket.headerLength(msg) + length + call RadioPacket.metadataLength(msg) <= sizeof(message_t) );

		// we add the length of the CRC, which is automatically generated
		getHeader(msg)->length = length + 2;
	}

	async command uint8_t RadioPacket.maxPayloadLength()
	{
		RADIO_ASSERT( call Config.maxPayloadLength() - sizeof(RF231_header_t) <= 125 );

		return call Config.maxPayloadLength() - sizeof(RF231_header_t);
	}

	async command uint8_t RadioPacket.metadataLength(message_t* msg)
	{
		return call Config.metadataLength(msg) + sizeof(RF231_metadata_t);
	}

	async command void RadioPacket.clear(message_t* msg)
	{
		// all flags are automatically cleared
	}

/*----------------- PacketTransmitPower -----------------*/

	async command bool PacketTransmitPower.isSet(message_t* msg)
	{
		return call TransmitPowerFlag.get(msg);
	}

	async command uint8_t PacketTransmitPower.get(message_t* msg)
	{
		return getMeta(msg)->power;
	}

	async command void PacketTransmitPower.clear(message_t* msg)
	{
		call TransmitPowerFlag.clear(msg);
	}

	async command void PacketTransmitPower.set(message_t* msg, uint8_t value)
	{
		call TransmitPowerFlag.set(msg);
		getMeta(msg)->power = value;
	}

/*----------------- PacketRSSI -----------------*/

	async command bool PacketRSSI.isSet(message_t* msg)
	{
		return call RSSIFlag.get(msg);
	}

	async command uint8_t PacketRSSI.get(message_t* msg)
	{
		return getMeta(msg)->rssi;
	}

	async command void PacketRSSI.clear(message_t* msg)
	{
		call RSSIFlag.clear(msg);
	}

	async command void PacketRSSI.set(message_t* msg, uint8_t value)
	{
		// just to be safe if the user fails to clear the packet
		call TransmitPowerFlag.clear(msg);

		call RSSIFlag.set(msg);
		getMeta(msg)->rssi = value;
	}

/*----------------- PacketTimeSyncOffset -----------------*/

	async command bool PacketTimeSyncOffset.isSet(message_t* msg)
	{
		return call TimeSyncFlag.get(msg);
	}

	async command uint8_t PacketTimeSyncOffset.get(message_t* msg)
	{
		return call RadioPacket.headerLength(msg) + call RadioPacket.payloadLength(msg) - sizeof(timesync_absolute_t);
	}

	async command void PacketTimeSyncOffset.clear(message_t* msg)
	{
		call TimeSyncFlag.clear(msg);
	}

	async command void PacketTimeSyncOffset.set(message_t* msg, uint8_t value)
	{
		// we do not store the value, the time sync field is always the last 4 bytes
		RADIO_ASSERT( call PacketTimeSyncOffset.get(msg) == value );

		call TimeSyncFlag.set(msg);
	}

/*----------------- PacketLinkQuality -----------------*/

	async command bool PacketLinkQuality.isSet(message_t* msg)
	{
		return TRUE;
	}

	async command uint8_t PacketLinkQuality.get(message_t* msg)
	{
		return getMeta(msg)->lqi;
	}

	async command void PacketLinkQuality.clear(message_t* msg)
	{
	}

	async command void PacketLinkQuality.set(message_t* msg, uint8_t value)
	{
		getMeta(msg)->lqi = value;
	}

/*----------------- PacketAcknowledgements -----------------*/

	async command error_t PacketAcknowledgements.requestAck(message_t* msg)
	{
		call Ieee154PacketLayer.setAckRequired(msg, TRUE);

		return SUCCESS;
	}

	async command error_t PacketAcknowledgements.noAck(message_t* msg)
	{
		call Ieee154PacketLayer.setAckRequired(msg, FALSE);

		return SUCCESS;
	}

	async command bool PacketAcknowledgements.wasAcked(message_t* msg)
	{
		return call AckReceivedFlag.get(msg);
	}

/*----------------- LinkPacketMetadata -----------------*/

	async command bool LinkPacketMetadata.highChannelQuality(message_t* msg)
	{
		return call PacketLinkQuality.get(msg) > 200;
	}
}
