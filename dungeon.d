module dungeon;

import randutils;
import doodad;
import gfm.math;
import aosmap;
import block;
import colorize;
import room;

class Dungeon
{
    Room[] rooms;
    Doodad[] doodads;

    DoodadInstance[] objects;

    this(ref RNG rng)
    {
        doodads = loadAllDoodads();
        cwritefln( color("*** Loaded %s doodads", fg.light_green), doodads.length);

        foreach(i; 0..10000)
        {
            vec3i position = vec3i( randInt(rng, 10, 500), randInt(rng, 10, 500), randInt(rng, 1, 50));
            objects ~= new DoodadInstance(doodads[randInt(rng, 0, 2)], position, randInt(rng, 0, 4));
        }
    }


    void render(ref RNG rng, AOSMap map)
    {        
        //map.fill(map.wholeWorld, Block(149, 193, 21));

        map.clearBox(map.worldBox());
        for (int i = 0; i < 512; ++i)
            for (int j = 0; j < 512; ++j)
                for (int k = 0; k < 1; ++k)
                {
                    map.block(i,j,k) = Block(149, 193, 21);
                }
        
        
        foreach(di; objects)
            di.render(map);        
    }

}