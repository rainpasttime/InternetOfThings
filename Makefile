COMPONENT=TestBAppC
CFLAGS += -I$(TOSDIR)/lib/net \
          -I$(TOSDIR)/lib/printf
CFLAGS += -DENABLE_PR
# channels from 11 to 26
CFLAGS+=-DCC2420_DEF_CHANNEL=20
# transmission power from 1 to 31
CFLAGS+=-DCC2420_DEF_RFPOWER=1
CFLAGS += -DTOSH_DATA_LENGTH=128
include $(MAKERULES)

