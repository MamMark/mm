/**
 * Copyright @ 2008, 2010 Eric B. Decker
 * @author Eric B. Decker
 */

configuration CommDTC {
  provides interface CommDT[uint8_t sns_id];
}

implementation {
  components CommDTP;
  CommDT = CommDTP;

  components PanicC;
  CommDTP.Panic -> PanicC;

  components mmCommSwC;
  CommDTP.Send     -> mmCommSwC;
  CommDTP.SendBusy -> mmCommSwC;
  CommDTP.Packet   -> mmCommSwC;
  CommDTP.AMPacket -> mmCommSwC;
  
  components LedsC;
  CommDTP.Leds -> LedsC;
}
