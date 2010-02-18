/**
 * Copyright @ 2008 Eric B. Decker
 * @author Eric B. Decker
 */

configuration mm3CommDataC {
  provides interface mm3CommData[uint8_t sns_id];
}

implementation {
  components mm3CommDataP;
  mm3CommData = mm3CommDataP;

  components PanicC;
  mm3CommDataP.Panic -> PanicC;

  components mm3CommSwC;
  mm3CommDataP.Send     -> mm3CommSwC;
  mm3CommDataP.SendBusy -> mm3CommSwC;
  mm3CommDataP.Packet   -> mm3CommSwC;
  mm3CommDataP.AMPacket -> mm3CommSwC;
  
  components LedsC;
  mm3CommDataP.Leds -> LedsC;
}
