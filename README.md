# AirShuttle [airshuttle]

A transportation mod for sightseeing tours.

![TechPack](https://github.com/joe7575/airshuttle/blob/master/screenshot.png)


## Instructions

The air shuttle, called "Milchtüte", is remote controlled and can't be self-driven by any player.
The means the flight route must be defined beforehand.

Start/stop is always the launcher position. Chat commands allow to define waypoints.
The player has to have 'airshuttle' privs to be able to configure the flight route.


## Step by Step

1. Place the launcher block at your preferred start position, the displayed number (ID) will be the flight number for this block.

2. Specify the waypoints with `add_waypoint <id> <number> <extra-height>`  
   You can specify the altitude relative to your current position.  
   `<id>` is the flight ID, `<number>` are the waypoints number from 1 .. 20  
   `<extra-height>` should be something between 3..20 nodes  
   Marker blocks appear at all waypoints, but disappear after a few minutes.

3. Deleting points again with `del_waypoint <id> <number>`
   There may also be gaps in the numbers.

4. With `del_route <id>` you can delete the route again. If you remove the launcher block, the route is gone too.

5. With `show_route <id>` you can have your route displayed.

5. When you right-click the launcher block, the air shuttle appears. After right-clicking the air shuttle
   the flight starts. The only possibility to abort the flight is to leave the game.

6. After arrival you have to right-click the air shuttle to get free again.


## Further hints

* The higher you fly, the faster you fly. 
* If the distance between to waypoints is greater than 200 nodes, the air shuttle we be teleported to the next waypoint. 
  This allows you to visit hotspots far away without spending too much time.
* At the waypoints the plane slows down, especially with strong changes of direction.
* There is no recipe so far, only the admin are players with creative privs can distribute launcher blocks to players.
* Only one flight at the same time. The launcher is blocked in the meantime.



### License
Copyright (C) 2018 Joachim Stolberg  
Mod highly inspired by airboat from paramat and flying_carpet from Wuzzy  
Code: Licensed under the GNU LGPL version 2.1 or later. See LICENSE.txt  
Textures: CC BY-SA 3.0


### Dependencies 
-


### History 
- 2018-09-26  v0.1  * first try
