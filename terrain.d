module terrain;

import std.stdio;
import std.math;

import vector;
import aosmap;
import randutils;
import perlin;


void makeTerrain(ref SimpleRng rng, AOSMap map)
{
    writefln("*** Make terrain...");
    // make heightmap

    Perlin3D[] perlin;
    perlin.length = 8;
    for (int oct = 0; oct < 8; ++oct)
    {
        perlin[oct] = new Perlin3D(rng);
    }
    

    int[] height;
    vec2i mapDim = vec2i(512, 512);
    height.length = mapDim.x * mapDim.y;
    height[] = 0;

    double z = 10;
    for (int y = 0; y < mapDim.y; ++y)
    {
        for (int x = 0; x < mapDim.x; ++x)
        {  
            double fx = x / cast(double)mapDim.x;
            double fy = y / cast(double)mapDim.y;
            
            for (int oct = 0; oct < 8; ++oct)
            {
                double freq = 2.0 ^^ oct;
                double zo = 3 * (perlin[oct].noise(fx * freq, fy * freq, 0.5) - 0.5);
                double amplitude = 2.0 ^^ (-oct);
                z += zo * amplitude;
            }
            
            int h = cast(int)(0.5 + z);
            if (h < 1) 
                h = 1;
            height[y * mapDim.x + x] = h;
        }
    }

    // render height
    for (int y = 0; y < mapDim.y; ++y)
    {
        for (int x = 0; x < mapDim.x; ++x)
        {        
            for (int k = 1; k <= height[y * mapDim.x + x]; ++k)
            {
                vec3f color = vec3f(168 / 255.0f, 194 / 255.0f, 75 / 255.0f);
                map.block(x, y, k).setf(color);
            }            
        }
    }

    /*
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
        }*/
}
