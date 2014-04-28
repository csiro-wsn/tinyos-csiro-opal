configuration RF231BareMessageC
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
  components RF231RadioC as RadioC;

  BareSend = RadioC;
  BareReceive = RadioC;
  BarePacket = RadioC.BarePacket;
  PacketLink = RadioC;
  LowPowerListening = RadioC;
  RadioControl = RadioC.SplitControl;
  ShortAddressConfig = RadioC;
}
