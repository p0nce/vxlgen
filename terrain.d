module terrain;

import std.stdio;
import std.math;

import vector;
import aosmap;
import randutils;
import perlin;


void makeTerrain(ref SimpleRng rng, AOSMap map)
{
    // make heightmap

    writefln("*** Make terrain...");
    // ground
    for (int i = 0; i < 512; ++i)
        for (int j = 0; j < 512; ++j)
        {
            double distanceToCenter = vec2f(i, j).distanceTo(vec2f(256,256));

            if (distanceToCenter < 220)
            {
                vec3f color;

                if (distanceToCenter > 200)
                    color = vec3f(0.9, 0.9, 0.9);
                else 
                    color = vec3f(168 / 255.0f, 194 / 255.0f, 75 / 255.0f);

                color += randomPerturbation(rng) * 0.03f;

                int height = cast(int)(0.5 + 10 * cos(PI * 0.5 * distanceToCenter / 240.0f));
                if (height > 7)
                    height = 7;
                for (int k = 1; k <= height; ++k)
                {
                    map.block(i, j, k).setf(color);
                }
            }
        }
}
