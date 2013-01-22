COMPONENT=TestRadioAppC

CFLAGS += -I$(TOSDIR_CSIRO)/lib/printf
CFLAGS += -I$(TOSDIR)/lib/printf
PFLAGS += -DNEW_PRINTF_SEMANTICS

# settings for the RF230 radio
PFLAGS += -DRF230_DEF_CHANNEL=26

# settings for the RF212 radio
CFLAGS += -DRF212_DEF_RFPOWER=102 # 868 Mhz band, 0dBm (0x66)
CFLAGS += -DRF212_DEF_CHANNEL=0 # 868.3 Mhz

include $(MAKERULES)

