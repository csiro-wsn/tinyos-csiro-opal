configuration RF212BareMessageC
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
  components RF212RadioC;

  BareSend = RF212RadioC;
  BareReceive = RF212RadioC;
  BarePacket = RF212RadioC.BarePacket;
  PacketLink = RF212RadioC;
  LowPowerListening = RF212RadioC;
  RadioControl = RF212RadioC.SplitControl;
  ShortAddressConfig = RF212RadioC;
}
