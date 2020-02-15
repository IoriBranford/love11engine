<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.2" tiledversion="1.3.2" name="playershot" tilewidth="16" tileheight="32" tilecount="5" columns="5">
 <tileoffset x="-8" y="0"/>
 <image source="playershot.png" width="80" height="32"/>
 <tile id="0">
  <properties>
   <property name="tilename" value="muzzleflash"/>
  </properties>
  <animation>
   <frame tileid="0" duration="33"/>
   <frame tileid="1" duration="33"/>
  </animation>
 </tile>
 <tile id="2">
  <properties>
   <property name="tilename" value="bullet"/>
  </properties>
  <animation>
   <frame tileid="2" duration="33"/>
   <frame tileid="3" duration="33"/>
   <frame tileid="4" duration="33"/>
   <frame tileid="3" duration="33"/>
  </animation>
 </tile>
</tileset>
