/**
 * Copyright @ 2008, 2010 Eric B. Decker
 * @author Eric B. Decker
 */

configuration mmCommDataC {
  provides interface mmCommData[uint8_t sns_id];
}

implementation {
  components mmCommDataP;
  mmCommData = mmCommDataP;

  components PanicC;
  mmCommDataP.Panic -> PanicC;

  components mmCommSwC;
  mmCommDataP.Send     -> mmCommSwC;
  mmCommDataP.SendBusy -> mmCommSwC;
  mmCommDataP.Packet   -> mmCommSwC;
  mmCommDataP.AMPacket -> mmCommSwC;
  
  components LedsC;
  mmCommDataP.Leds -> LedsC;
}
