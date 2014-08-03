module dungeon;

import randutils;
import gfm.math;
import aosmap;
import block;
import colorize : fg, cwritefln;
import colorize.colorize : colorize;
import room;

class Dungeon
{
    Room[] rooms;

    this(ref RNG rng)
    {
        int NUM_ROOMS = 1000;
        cwritefln( colorize("*** Create %d rooms", fg.light_green), NUM_ROOMS);

        for (int i = 0; i < NUM_ROOMS; ++i)
        {
            int width, height, depth;

            switch (dice(rng, 70, 15, 5))
            {
                // small room/corridor
                case 0:
                    width = randInt(rng, 5, 8);
                    height = randInt(rng, 5, 8);
                    depth = 3 + dice(rng, 50, 25, 20, 10);
                    break;

                // medium room
                case 1:
                    width = randInt(rng, 14, 30);
                    height = randInt(rng, 14, 30);
                    depth = randInt(rng, 5, 20);
                    break;

                // huge room
                case 2:
                    width = randInt(rng, 20, 50);
                    height = randInt(rng, 20, 50);
                    depth = randInt(rng, 10, 40);
                    break;
                default:
                    assert(0);
            }

            int x = randInt(rng, 1, 511 - width);
            int y = randInt(rng, 1, 511 - height);
            int z = randInt(rng, 1, 62 - depth);

            vec3i position = vec3i(x,y,z);
            vec3i dimension = vec3i(width, height, depth);
            box3i candidate = box3i(position, position + dimension);
            bool intersectsOther = false;
            for (int j = 0; j < i; ++j)
            {
                if (rooms[j].box().intersect(candidate).volume() != 0)
                    intersectsOther = true;
                break;                
            }
            if (!intersectsOther)
                rooms ~= new Room(position, dimension);
        }
        cwritedln("%s rooms built", rooms.length);
    }


    void render(ref RNG rng, AOSMap map)
    {
        map.fill(map.wholeWorld, Block(149, 193, 21));
        for (int i = 0; i < 512; ++i)
            for (int j = 0; j < 512; ++j)
                for (int k = 61; k < 62; ++k)
                {
                    //if (k == 0 && randInt(rng, 0, 1))
                    //    map.block(i,j,k) = Block(149, 193, 21);
                    //else
                        map.block(i,j,k).empty();
                }
        //map.clearBox(map.worldBox());

        // make rooms
        

        foreach(room; rooms)
            room.render(rng, map);
    }

}