/**
 *  Configuration file for wiring of sendAckC module to other common 
 *  components needed for proper functioning
 *
 *  @author Luca Pietro Borsani
 */

#include "sendAck.h"

configuration sendAckAppC {}

implementation {


/****** COMPONENTS *****/
  components MainC, sendAckC as App;
  //add the other components here
  components new AMSenderC(AM_MY_MSG);
  components new AMReceiverC(AM_MY_MSG);
  components new TimerMilliC() as timer;
  components ActiveMessageC;
  components SerialStartC;
  components new FakeSensorC() as sensor;


/****** INTERFACES *****/
  //Boot interface
  App.Boot -> MainC.Boot;

  /****** Wire the other interfaces down here *****/
  //Send and Receive interfaces
  App.AMSend -> AMSenderC;
  App.Packet -> AMSenderC;
  App.Receive -> AMReceiverC;
  
  //Radio Control
  App.SplitControl -> ActiveMessageC;
 
  //Interfaces to access package fields
    App.AMPacket -> AMSenderC;
  
  //Timer interface
  App.MilliTimer ->  timer;
  
  //Fake Sensor read
  App.Read -> sensor;
  
  //Packet acknowledgment
  App.Ack -> ActiveMessageC;
	
}

