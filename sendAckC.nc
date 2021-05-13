/**
 *  Source file for implementation of module sendAckC in which
 *  the node 1 send a request to node 2 until it receives a response.
 *  The reply message contains a reading from the Fake Sensor.
 *
 *  @author Luca Pietro Borsani
 */

#include "sendAck.h"
#include "Timer.h"

#define UNICAST_ADDRESS 0

module sendAckC {

  uses {
  /****** INTERFACES *****/
	interface Boot; 
	
    //interfaces for communication
    interface SplitControl;
	interface Packet;
    interface AMSend;
    interface Receive;

	//interface for timer
    //other interfaces, if needed
	interface Timer<TMilli> as Timer;
	
	//interface used to perform sensor reading (to get the value from a sensor)
	interface Read<uint16_t> ;
  }

} implementation {

  uint8_t counter=0;
  uint8_t rec_id;
  message_t packet;

  void sendReq();
  void sendResp();
  
  
  //***************** Send request function ********************//
  void sendReq() {
	/* This function is called when we want to send a request
	 *
	 * STEPS:
	 * 1. Prepare the msg
	 * 2. Set the ACK flag for the message using the PacketAcknowledgements interface
	 *     (read the docs)
	 * 3. Send an UNICAST message to the correct node
	 * X. Use debug statements showing what's happening (i.e. message fields)
	 */
  	my_msg_t* mess = (my_msg_t*)(call Packet.getPayload(&packet, sizeof(my_msg_t)));
	  if (mess == NULL) {
		return;
	  }
	  mess->msg_type = 1;
	  mess->msg_counter = counter;
	  mess->value = 0;
	  dbg("radio_pack","Preparing the message... \n");
	  
	  request_ack(mess);
 }        

  //****************** Task send response *****************//
  void sendResp() {
  	/* This function is called when we receive the REQ message.
  	 * Nothing to do here. 
  	 * `call Read.read()` reads from the fake sensor.
  	 * When the reading is done it raise the event read one.
  	 */
	call Read.read();
  }

  //***************** Boot interface ********************//
  event void Boot.booted() {
	dbg("boot","Application booted.\n");
	/* Fill it ... */
    call SplitControl.start();
  }

  //***************** SplitControl interface ********************//
  event void SplitControl.startDone(error_t err){
    /* Fill it ... */
    if(err == SUCCESS) {
    	dbg("radio", "Radio on!\n");
	if (TOS_NODE_ID > 0){
        call Timer.startPeriodic( 1000 );
  	}
    }
    else{
	//dbg for error
	call SplitControl.start();
    }
  }
  
  event void SplitControl.stopDone(error_t err){
    /* Fill it ... */
  }

  //***************** MilliTimer interface ********************//
  event void MilliTimer.fired() {
	/* This event is triggered every time the timer fires.
	 * When the timer fires, we send a request
	 * Fill this part...
	 */
  	counter++;
  	dbg("timer","Timer fired at %s.", sim_time_string());
    dbg("timer", " Counter is %hu.\n", counter);
	//call TempRead.read();

  	call sendReq();
  }
  

  //********************* AMSend interface ****************//
  event void AMSend.sendDone(message_t* buf,error_t err) {
	/* This event is triggered when a message is sent 
	 *
	 * STEPS:
	 * 1. Check if the packet is sent
	 * 2. Check if the ACK is received (read the docs)
	 * 2a. If yes, stop the timer. The program is done
	 * 2b. Otherwise, send again the request
	 * X. Use debug statements showing what's happening (i.e. message fields)
	 */
  	if (&packet == buf && error == SUCCESS) {
      dbg("radio_send", "Packet sent...");
      dbg_clear("radio_send", " at time %s \n", sim_time_string());
    }
    else{
      dbgerror("radio_send", "Send done error!\n");
    }

    if (wasAcked(buf) == SUCCESS){
		dbg("radio_send", "The program is done!\n");
		SplitControl.stop();

    }else{
    	dbgerror("radio_send", "No ACK received! Send a new request.\n");
    	call sendReq()
    }
  }

  //***************************** Receive interface *****************//
  event message_t* Receive.receive(message_t* buf,void* payload, uint8_t len) {
	/* This event is triggered when a message is received 
	 *
	 * STEPS:
	 * 1. Read the content of the message
	 * 2. Check if the type is request (REQ)
	 * 3. If a request is received, send the response
	 * X. Use debug statements showing what's happening (i.e. message fields)
	 */

  	if (len != sizeof(my_msg_t)) {
  		return bufPtr;}
    else {
      my_msg_t* mess = (my_msg_t*)payload;

      if (mess->type == 1){

        	call sendResp();    
            dbg("radio_rec", "Received packet at time %s\n", sim_time_string());
            dbg("radio_pack"," Payload length %hhu \n", call Packet.payloadLength( bufPtr ));
            dbg("radio_pack", ">>>Pack \n");
            dbg_clear("radio_pack","\t\t Payload Received\n" );
            dbg_clear("radio_pack", "\t\t type: %hhu \n ", mess->msg_type);
      	  	dbg_clear("radio_pack", "\t\t counter: %hhu \n", mess->msg_counter);
      	  	dbg_clear("radio_pack", "\t\t value: %hhu \n ", mess->value);

      	}

     
      return bufPtr;
    }
    {

  }
  
  //************************* Read interface **********************//
  event void Read.readDone(error_t result, uint16_t data) {
	/* This event is triggered when the fake sensor finish to read (after a Read.read()) 
	 *
	 * STEPS:
	 * 1. Prepare the response (RESP)
	 * 2. Send back (with a unicast message) the response
	 * X. Use debug statement showing what's happening (i.e. message fields)
	 */
  	my_msg_t* mess = (my_msg_t*)(call Packet.getPayload(&packet, sizeof(my_msg_t)));
	  if (mess == NULL) {
		return;
	  }
	  mess->msg_type = 2;
	  mess->msg_counter = counter;
	  mess->value = data;
	  dbg("radio_pack","Preparing the message... \n");
	  
	  if(call AMSend.send(UNICAST_ADDRESS, &packet,sizeof(my_msg_t)) == SUCCESS){ //send to mote 1
 	    dbg("radio_send", "Packet passed to lower layer successfully!\n");
	    dbg("radio_pack",">>>Pack\n \t Payload length %hhu \n", call Packet.payloadLength( &packet ) );
	    dbg_clear("radio_pack","\t\t Payload Received\n" );
        dbg_clear("radio_pack", "\t\t type: %hhu \n ", mess->msg_type);
      	dbg_clear("radio_pack", "\t\t counter: %hhu \n", mess->msg_counter);
      	dbg_clear("radio_pack", "\t\t value: %hhu \n ", mess->value);

  	}
}

