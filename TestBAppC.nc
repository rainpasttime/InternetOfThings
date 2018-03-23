#include <Timer.h>
configuration TestBAppC {}
implementation {
	components TestBC;

	components MainC;
	components ActiveMessageC;
	components LedsC;
	components new AMSenderC(6);
	components new AMReceiverC(6);
	components new TimerMilliC() as Timer0;
	components new TimerMilliC() as Timer1;
	//components new TimerMilliC() as Timer2;

	TestBC.Boot -> MainC;
	TestBC.AMControl -> ActiveMessageC;
	TestBC.Leds -> LedsC;
	TestBC.Packet -> AMSenderC;
	TestBC.AMSend -> AMSenderC;
	TestBC.Receive -> AMReceiverC;
	TestBC.Timer0 -> Timer0;
	TestBC.Timer1 -> Timer1;
	//TestBC.Timer2 -> Timer2;
}
