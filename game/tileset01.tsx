<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.2" tiledversion="1.3.2" name="tileset01" tilewidth="32" tileheight="32" tilecount="400" columns="20">
 <image source="tileset01.png" width="640" height="640"/>
 <terraintypes>
  <terrain name="dirt" tile="45"/>
  <terrain name="dirtpath" tile="4"/>
  <terrain name="grass" tile="84"/>
  <terrain name="brickpath" tile="164"/>
  <terrain name="tilepath" tile="265"/>
  <terrain name="stair" tile="325"/>
  <terrain name="water" tile="20"/>
  <terrain name="pool" tile="310"/>
  <terrain name="roof" tile="301"/>
  <terrain name="wall" tile="361"/>
 </terraintypes>
 <tile id="4" terrain="1,1,1,1"/>
 <tile id="5" terrain="1,1,1,1"/>
 <tile id="6" terrain="1,1,1,1"/>
 <tile id="7" terrain="1,1,1,1"/>
 <tile id="8" terrain="1,1,1,1" probability="0.125"/>
 <tile id="20" terrain="6,6,6,6"/>
 <tile id="21" terrain="6,6,6,6" probability="0.125"/>
 <tile id="24" terrain="1,1,1,0"/>
 <tile id="25" terrain="1,1,0,0"/>
 <tile id="26" terrain="1,1,0,1"/>
 <tile id="27" terrain="0,0,0,1"/>
 <tile id="28" terrain="0,0,1,0"/>
 <tile id="40" terrain=",,,6">
  <animation>
   <frame tileid="40" duration="125"/>
   <frame tileid="120" duration="125"/>
   <frame tileid="200" duration="125"/>
   <frame tileid="120" duration="125"/>
  </animation>
 </tile>
 <tile id="41" terrain=",,6,6">
  <animation>
   <frame tileid="41" duration="125"/>
   <frame tileid="121" duration="125"/>
   <frame tileid="201" duration="125"/>
   <frame tileid="121" duration="125"/>
  </animation>
 </tile>
 <tile id="42" terrain=",,6,6">
  <animation>
   <frame tileid="42" duration="125"/>
   <frame tileid="122" duration="125"/>
   <frame tileid="202" duration="125"/>
   <frame tileid="122" duration="125"/>
  </animation>
 </tile>
 <tile id="43" terrain=",,6,">
  <animation>
   <frame tileid="43" duration="125"/>
   <frame tileid="123" duration="125"/>
   <frame tileid="203" duration="125"/>
   <frame tileid="123" duration="125"/>
  </animation>
 </tile>
 <tile id="44" terrain="1,0,1,0"/>
 <tile id="45" terrain="0,0,0,0"/>
 <tile id="46" terrain="0,1,0,1"/>
 <tile id="47" terrain="0,1,0,0"/>
 <tile id="48" terrain="1,0,0,0"/>
 <tile id="60" terrain=",6,,6">
  <animation>
   <frame tileid="60" duration="125"/>
   <frame tileid="140" duration="125"/>
   <frame tileid="220" duration="125"/>
   <frame tileid="140" duration="125"/>
  </animation>
 </tile>
 <tile id="61" terrain="6,6,6,">
  <animation>
   <frame tileid="61" duration="125"/>
   <frame tileid="141" duration="125"/>
   <frame tileid="221" duration="125"/>
   <frame tileid="141" duration="125"/>
  </animation>
 </tile>
 <tile id="62" terrain="6,6,,6">
  <animation>
   <frame tileid="62" duration="125"/>
   <frame tileid="142" duration="125"/>
   <frame tileid="222" duration="125"/>
   <frame tileid="142" duration="125"/>
  </animation>
 </tile>
 <tile id="63" terrain="6,,6,">
  <animation>
   <frame tileid="63" duration="125"/>
   <frame tileid="143" duration="125"/>
   <frame tileid="223" duration="125"/>
   <frame tileid="143" duration="125"/>
  </animation>
 </tile>
 <tile id="64" terrain="1,0,1,1"/>
 <tile id="65" terrain="0,0,1,1"/>
 <tile id="66" terrain="0,1,1,1"/>
 <tile id="67" terrain="0,0,0,0" probability="0.125"/>
 <tile id="68" terrain="0,0,0,0" probability="0.125"/>
 <tile id="80" terrain=",6,,6">
  <animation>
   <frame tileid="80" duration="125"/>
   <frame tileid="160" duration="125"/>
   <frame tileid="240" duration="125"/>
   <frame tileid="160" duration="125"/>
  </animation>
 </tile>
 <tile id="81" terrain="6,,6,6">
  <animation>
   <frame tileid="81" duration="125"/>
   <frame tileid="161" duration="125"/>
   <frame tileid="241" duration="125"/>
   <frame tileid="161" duration="125"/>
  </animation>
 </tile>
 <tile id="82" terrain=",6,6,6">
  <animation>
   <frame tileid="82" duration="125"/>
   <frame tileid="162" duration="125"/>
   <frame tileid="242" duration="125"/>
   <frame tileid="162" duration="125"/>
  </animation>
 </tile>
 <tile id="83" terrain="6,,6,">
  <animation>
   <frame tileid="83" duration="125"/>
   <frame tileid="163" duration="125"/>
   <frame tileid="243" duration="125"/>
   <frame tileid="163" duration="125"/>
  </animation>
 </tile>
 <tile id="84" terrain="2,2,2,2"/>
 <tile id="85" terrain="2,2,2,2"/>
 <tile id="86" terrain="2,2,2,2"/>
 <tile id="87" terrain="2,2,2,2" probability="0.125"/>
 <tile id="88" terrain="2,2,2,2" probability="0.125"/>
 <tile id="100" terrain=",6,,">
  <animation>
   <frame tileid="100" duration="125"/>
   <frame tileid="180" duration="125"/>
   <frame tileid="260" duration="125"/>
   <frame tileid="180" duration="125"/>
  </animation>
 </tile>
 <tile id="101" terrain="6,6,,">
  <animation>
   <frame tileid="101" duration="125"/>
   <frame tileid="181" duration="125"/>
   <frame tileid="261" duration="125"/>
   <frame tileid="181" duration="125"/>
  </animation>
 </tile>
 <tile id="102" terrain="6,6,,">
  <animation>
   <frame tileid="102" duration="125"/>
   <frame tileid="182" duration="125"/>
   <frame tileid="262" duration="125"/>
  </animation>
 </tile>
 <tile id="103" terrain="6,,,">
  <animation>
   <frame tileid="103" duration="125"/>
   <frame tileid="183" duration="125"/>
   <frame tileid="263" duration="125"/>
   <frame tileid="183" duration="125"/>
  </animation>
 </tile>
 <tile id="104" terrain="2,2,2,"/>
 <tile id="105" terrain="2,2,,"/>
 <tile id="106" terrain="2,2,,2"/>
 <tile id="107" terrain=",,,2"/>
 <tile id="108" terrain=",,2,"/>
 <tile id="124" terrain="2,,2,"/>
 <tile id="126" terrain=",2,,2"/>
 <tile id="127" terrain=",2,,"/>
 <tile id="128" terrain="2,,,"/>
 <tile id="130">
  <animation>
   <frame tileid="130" duration="66"/>
   <frame tileid="131" duration="66"/>
   <frame tileid="132" duration="66"/>
   <frame tileid="133" duration="66"/>
  </animation>
 </tile>
 <tile id="144" terrain="2,,2,2"/>
 <tile id="145" terrain=",,2,2"/>
 <tile id="146" terrain=",2,2,2"/>
 <tile id="150">
  <animation>
   <frame tileid="150" duration="66"/>
   <frame tileid="151" duration="66"/>
   <frame tileid="152" duration="66"/>
   <frame tileid="153" duration="66"/>
  </animation>
 </tile>
 <tile id="164" terrain="3,3,3,3"/>
 <tile id="165" terrain="3,3,3,3"/>
 <tile id="166" terrain="3,3,3,3"/>
 <tile id="167" terrain="3,3,3,3"/>
 <tile id="168" terrain="3,3,3,3"/>
 <tile id="184" terrain="3,3,3,"/>
 <tile id="185" terrain="3,3,,"/>
 <tile id="186" terrain="3,3,,3"/>
 <tile id="187" terrain=",,,3"/>
 <tile id="188" terrain=",,3,"/>
 <tile id="204" terrain="3,,3,"/>
 <tile id="206" terrain=",3,,3"/>
 <tile id="207" terrain=",3,,"/>
 <tile id="208" terrain="3,,,"/>
 <tile id="224" terrain="3,,3,3"/>
 <tile id="225" terrain=",,3,3"/>
 <tile id="226" terrain=",3,3,3"/>
 <tile id="244" terrain="4,4,4,"/>
 <tile id="245" terrain="4,4,,"/>
 <tile id="246" terrain="4,4,,4"/>
 <tile id="247" terrain=",,,4"/>
 <tile id="248" terrain=",,4,"/>
 <tile id="264" terrain="4,,4,"/>
 <tile id="265" terrain="4,4,4,4"/>
 <tile id="266" terrain=",4,,4"/>
 <tile id="267" terrain=",4,,"/>
 <tile id="268" terrain="4,,,"/>
 <tile id="280" terrain=",,,8"/>
 <tile id="281" terrain=",,8,8"/>
 <tile id="282" terrain=",,8,"/>
 <tile id="283" terrain="8,8,8,8"/>
 <tile id="284" terrain="4,,4,4"/>
 <tile id="285" terrain=",,4,4"/>
 <tile id="286" terrain=",4,4,4"/>
 <tile id="289" terrain=",,,7"/>
 <tile id="290" terrain=",,7,7"/>
 <tile id="291" terrain=",,7,"/>
 <tile id="292" terrain="7,7,7,"/>
 <tile id="293" terrain="7,7,,7"/>
 <tile id="300" terrain=",8,,8"/>
 <tile id="301" terrain="8,8,8,8"/>
 <tile id="302" terrain="8,,8,"/>
 <tile id="303" terrain="8,8,8,8"/>
 <tile id="304" terrain="5,5,5,"/>
 <tile id="305" terrain="5,5,,"/>
 <tile id="306" terrain="5,5,,5"/>
 <tile id="307" terrain=",,,5"/>
 <tile id="308" terrain=",,5,"/>
 <tile id="309" terrain=",7,,7"/>
 <tile id="310" terrain="7,7,7,7"/>
 <tile id="311" terrain="7,,7,"/>
 <tile id="312" terrain="7,,7,7"/>
 <tile id="313" terrain=",7,7,7"/>
 <tile id="320" terrain=",8,,"/>
 <tile id="321" terrain="8,8,,"/>
 <tile id="322" terrain="8,,,"/>
 <tile id="323" terrain="8,8,8,8"/>
 <tile id="324" terrain="5,,5,"/>
 <tile id="325" terrain="5,5,5,5"/>
 <tile id="326" terrain=",5,,5"/>
 <tile id="327" terrain=",5,,"/>
 <tile id="328" terrain="5,,,"/>
 <tile id="329" terrain=",7,,"/>
 <tile id="330" terrain="7,7,,"/>
 <tile id="331" terrain="7,,,"/>
 <tile id="332" terrain="7,7,7,7" probability="0.125"/>
 <tile id="333" terrain="7,7,7,7" probability="0.125"/>
 <tile id="340" terrain=",,,9"/>
 <tile id="341" terrain=",,9,9"/>
 <tile id="342" terrain=",,9,"/>
 <tile id="343" terrain="8,8,8,8"/>
 <tile id="344" terrain="5,,5,5"/>
 <tile id="345" terrain=",,5,5"/>
 <tile id="346" terrain=",5,5,5"/>
 <tile id="360" terrain=",9,,9"/>
 <tile id="361" terrain="9,9,9,9"/>
 <tile id="362" terrain="9,,9,"/>
 <tile id="380" terrain=",9,,"/>
 <tile id="381" terrain="9,9,,"/>
 <tile id="382" terrain="9,,,"/>
</tileset>
