configuration BareMessageC
{
  provides
  {
    interface BareSend;
    interface BareReceive;
    interface Packet as BarePacket;
    interface PacketLink;
    interface LowPowerListening;
    interface SplitControl as RadioControl;
    interface ShortAddressConfig;
  }
}
implementation
{

  #if defined(OPAL_RADIO_RF212)
        components RF212BareMessageC as BareMessageC;
  #else
        components RF230BareMessageC as BareMessageC;
  #endif


  BareSend = BareMessageC;
  BareReceive = BareMessageC;
  BarePacket = BareMessageC;
  PacketLink = BareMessageC;
  LowPowerListening = BareMessageC;
  RadioControl = BareMessageC;
  ShortAddressConfig = BareMessageC;
}
