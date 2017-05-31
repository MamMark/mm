/**
 * Copyright @ 2008 Eric B. Decker
 * @author Eric B. Decker
 */

configuration mmControlC {
  provides {
    interface mmControl[uint8_t sns_id];
    interface Surface;
  }
  uses {
    interface SenseVal[uint8_t sns_id];
  }
}

implementation {
  components mmControlP, MainC;
  mmControl = mmControlP;
  MainC.SoftwareInit -> mmControlP;
  SenseVal = mmControlP;
  Surface  = mmControlP;

  components PanicC;
  mmControlP.Panic -> PanicC;

  components CollectC;
  mmControlP.CollectEvent -> CollectC;

#ifdef FAKE_SURFACE
  components new TimerMilliC() as SurfaceTimer;
  mmControlP.SurfaceTimer -> SurfaceTimer;
#endif
}
