"""

  laby.py

From babel_script.py by Yourself (anti grief by izzy)
   + onectf.py by Yourself
   + intelrpg.py by Danke

Adapted to labyrinth map by ponce
 - all players have two powers: +3 HP/sec and grenade-teleport

"""

from pyspades.constants import *
from random import randint
from twisted.internet import reactor
from commands import add, admin
from pyspades.collision import vector_collision, distance_3d_vector
from pyspades.server import grenade_packet, block_action, set_tool
from pyspades.world import Grenade
from pyspades.common import Vertex3
import random
import commands

BLUE_BASE_COORDS = (256 - 57, 254.5)
GREEN_BASE_COORDS = (256 + 54, 254.5)
SPAWN_SIZE = 7
FLAG_SPAWN_POS = (256, 256)
HIDE_POS = (0, 0, 63)

def get_entity_location(self, entity_id):
    if entity_id == BLUE_BASE:
        return BLUE_BASE_COORDS + (63 - 7,)
    elif entity_id == GREEN_BASE:
        return GREEN_BASE_COORDS + (63 - 7,)
    elif entity_id == BLUE_FLAG:
        return (256 - 2 + 1, 256, 0)
    elif entity_id == GREEN_FLAG:
        return (256 + 2 - 1, 256, 0)

def get_spawn_location(connection):
    xb = connection.team.base.x
    yb = connection.team.base.y
    xb += randint(-SPAWN_SIZE, SPAWN_SIZE)
    yb += randint(-SPAWN_SIZE, SPAWN_SIZE)
    return (xb, yb, 63-7)

def z_to_floor(z):
    lvl = int((63-z)/6)
    return level_to_floor(lvl)

def level_to_floor(lvl):
    if lvl == 10:
        return "on the roof"
    elif lvl == 1:
        return "at ground floor" 
    else:
        return "at floor " + str(lvl-1)


def intel_spawn_location(self):
    loop = 0
    while True:
        AREA = 24 
        x = randint(255 - AREA, 255 + AREA)
        y = randint(255 - AREA, 255 + AREA)
        lvl = randint(0, 10)
        z = 3 +  6 * lvl
        z = 63 - z
        loop = loop + 1
        if (loop < 1000): # detect infinite loop (never happened yet)
            if self.map.get_solid(x, y, z):
                continue
            if self.map.get_solid(x+1, y, z):
                continue
            if self.map.get_solid(x, y+1, z):
                continue
            if self.map.get_solid(x+1, y+1, z):
                continue
            if self.map.get_solid(x, y, z-1):
                continue
            if self.map.get_solid(x+1, y, z-1):
                continue
            if self.map.get_solid(x, y+1, z-1):
                continue
            if self.map.get_solid(x+1, y+1, z-1):
                continue

        self.send_chat("The intel spawned " + level_to_floor(lvl) + ".")
        return (x, y, z)



def apply_script(protocol, connection, config):

    class LabyrinthConnection(connection):
        
        def on_flag_take(self):
            flag = self.team.flag
            if flag.player is None:
                flag.set(*HIDE_POS)
                flag.update()
            else:
                return False
            return connection.on_flag_take(self)
        
        def on_flag_drop(self):

            # move both intel
            position = self.world_object.position
            x = int(position.x)
            y = int(position.y)
            z =  max(0, int(position.z))

            # find  floor
            while z < 63 and not self.protocol.map.get_solid(x, y, z):
                z = z + 1

            flag = self.team.flag
            flag.set(x, y, z)
            flag.update()

            other_flag = self.team.other.flag
            other_flag.set(x, y, z)
            other_flag.update()

            return connection.on_flag_drop(self)

        def on_flag_capture(self):
            self.protocol.one_ctf_spawn_pos = intel_spawn_location(self.protocol)
            self.protocol.onectf_reset_flags()
            return connection.on_flag_capture(self)
        
        def intel_every_second(self):
            if self is None or self.hp <= 0:
                return
            self.set_hp(self.hp + 3, type = FALL_KILL)

        def on_grenade_thrown(self, grenade):
            grenade.callback = self.explosion
            connection.on_grenade_thrown(self, grenade)

        def explosion(self, grenade):
            x, y, z = (int(n) for n in grenade.position.get())
            self.set_location_safe((x, y, z - 1))


    class LabyrinthProtocol(protocol):
        intel_second_counter = 0
        counter2 = 0

        def onectf_reset_flag(self, flag):
            pos = (self.one_ctf_spawn_pos[0], self.one_ctf_spawn_pos[1], self.one_ctf_spawn_pos[2])
            if flag is not None:
                flag.player = None
                flag.set(*pos)
                flag.update()
            return pos

        def onectf_reset_flags(self):
            self.onectf_reset_flag(self.blue_team.flag)
            self.onectf_reset_flag(self.green_team.flag)
        
        def on_game_end(self):
            self.onectf_reset_flags()
            return protocol.on_game_end(self)

        def on_map_change(self, map):
            self.map_info.cap_limit = 1
            self.map_info.get_entity_location = get_entity_location
            self.map_info.get_spawn_location = get_spawn_location
            self.one_ctf_spawn_pos = intel_spawn_location(self)
            return protocol.on_map_change(self, map)

        def on_flag_spawn(self, x, y, z, flag, entity_id):
            pos = self.onectf_reset_flag(flag.team.other.flag)
            protocol.on_flag_spawn(self, pos[0], pos[1], pos[2], flag, entity_id)
            return pos

        def on_world_update(self):
            self.intel_second_counter += 1
            if self.intel_second_counter >= 90:
                for player in self.players.values():
                    player.intel_every_second()
                self.intel_second_counter = 0
            self.counter2 += 1
            if self.counter2 >= 10000:
                self.counter2 = 0
                for player in self.players.values():
                    message = floor(player)
                    if message != "":
                        player.send_chat(floor(player))
            protocol.on_world_update(self)

    return LabyrinthProtocol, LabyrinthConnection

@commands.alias('floor')
def floor(connection):
    if connection not in connection.protocol.players:
        raise KeyError()
    if connection is None:
        return ""
    player = connection
    if player.world_object is None:
        return ""
    pz = player.get_location()[2]

    blue_flag = connection.protocol.blue_team.flag
    green_flag = connection.protocol.green_team.flag
    ibfpos = (blue_flag.x, blue_flag.y, blue_flag.z)
    igfpos = (green_flag.x, green_flag.y, green_flag.z)
    pos = ibfpos
    if (ibfpos[0] < 1):
        pos = igfpos

    if blue_flag.player is not None:
        pos = blue_flag.player.get_location()
    if green_flag.player is not None:
        pos = green_flag.player.get_location()

    iz = pos[2]
    return "You are " + z_to_floor(pz) + ", the intel is " + z_to_floor(iz) + "."
add(floor)

