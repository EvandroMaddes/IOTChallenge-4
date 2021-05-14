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
    interface Receive;
    interface AMSend;
    interface Timer<TMilli> as MilliTimer;
    interface Packet;
    interface SplitControl;
    // ack
    interface PacketAcknowledgements as Ack;
    // used to get source addr - allows for less hardcode
    interface AMPacket;
	interface Read<uint16_t>;
  }

} implementation {

  // note: counter shows how many requests have been sent without receiving an ACK back
  uint8_t counter=0;
  uint8_t rec_id;
  message_t packet;
  am_addr_t sender_addr;
  bool locked;

  //****************** Task send response *****************//
  void sendResp() {
  	/* This function is called when we receive the REQ message.
  	 * Nothing to do here. 
  	 * `call Read.read()` reads from the fake sensor.
  	 * When the reading is done it raise the event read one.
  	 */
	call Read.read();
  }
  	
  void sendReq()
  /* This function is called when we want to send a request
	 *
	 * STEPS:
	 * 1. Prepare the msg
	 * 2. Set the ACK flag for the message using the PacketAcknowledgements interface
	 *     (read the docs)
	 * 3. Send an UNICAST message to the correct node
	 * X. Use debug statements showing what's happening (i.e. message fields)
	 */{

        my_msg_t* message = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));
        if (message == NULL) {
            return;
        }
        message->msg_type = REQ;
        message->msg_counter = counter;
        message->value = 0;

        if(call Ack.requestAck(&packet)==SUCCESS) {
            dbg("radio_ack", "Ack message is enabled. Sending message...\n");
        } else {
        	dbgerror("radio_ack", "Acks DISABLED\n");
        }

        if(call AMSend.send(2, &packet, sizeof(my_msg_t)) == SUCCESS) {
            locked = TRUE;
        }
  }


  //***************** Boot interface ********************//
  event void Boot.booted() {
	dbg("boot","Application booted.\n");
	call SplitControl.start();
  }

  //***************** SplitControl interface ********************//
  event void SplitControl.startDone(error_t err){
    if(err == SUCCESS) {
        	dbg("radio", "Radio on!\n");
        if(TOS_NODE_ID==1) {
            call MilliTimer.startPeriodic(1000);
        }
    }
    else {
        call SplitControl.start();
    }
  }

  event void SplitControl.stopDone(error_t err){
    /* Fill it ... */
    dbg("split-control", "Application stopped\n");
  }

  //***************** MilliTimer interface ********************//
  event void MilliTimer.fired() {
	/* This event is triggered every time the timer fires.
	 * When the timer fires, we send a request
	 */
  	dbg("timer","Timer fired at %s.", sim_time_string());
    dbg("timer", " Counter is %hu.\n", counter);
    if(locked) {
        return;
    }
    else {
		sendReq();
    }
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
    if(&packet == buf) {
        my_msg_t* sent_msg = (my_msg_t*)buf;
        dbg("radio_send", "Sent message with counter: %hu\n", counter);
        locked = FALSE;
        // check for acks
        if(call Ack.wasAcked(buf) && TOS_NODE_ID==1) {
            call MilliTimer.stop();
            dbg("radio_ack", "Ack received.\n");
        }
        else if(call Ack.wasAcked(buf) && TOS_NODE_ID==2) {
            dbg("radio_ack", "Ack received.\n");
            call SplitControl.stop();
        }
        else {
            dbg("radio_ack", "Ack not received\n");
        }
        counter++;
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

    my_msg_t* message_received = (my_msg_t*)payload;
    dbg("radio_rec", "Received message\n");
    if(len != sizeof(my_msg_t)) return buf;

    dbg("radio_rec", "Received message and got through:\n\tType: %hu, \n\tCounter: %hu, \n\tValue: %hu\n", message_received->msg_type, message_received->msg_counter, message_received->value);


    if(TOS_NODE_ID==2) {
    	// prepare packet to send back
        counter = message_received->msg_counter;
        sender_addr = call AMPacket.source(buf);
        
        //send back the response
        sendResp();
    }

}

  //************************* Read interface **********************//
  event void Read.readDone(error_t result, uint16_t data) {
	/* This event is triggered when the fake sensor finishes to read (after a Read.read()) *
	 * STEPS:
	 * 1. Prepare the response (RESP)
	 * 2. Send back (with a unicast message) the response
	 * X. Use debug statement showing what's happening (i.e. message fields)
	 */
    if(!locked && result == SUCCESS) {

        my_msg_t* message = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));

        if (message == NULL) {
            return;
        }

		// prepare packet to send
        message->msg_type = RESP;
        message->msg_counter = counter;
        message->value = data;
        if(call Ack.requestAck(&packet)==SUCCESS) {
            dbg("radio_ack", "Acks enabled\n");
        }
        if(call AMSend.send(sender_addr, &packet, sizeof(my_msg_t)) == SUCCESS) {
            locked = TRUE;
        }

    }

}

}
