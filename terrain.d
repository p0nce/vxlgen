module terrain;

import std.stdio;
import std.math;

import funcs;
import vector;
import aosmap;
import randutils;
import simplexnoise;


void makeTerrain(ref SimpleRng rng, AOSMap map)
{
    writefln("*** Make terrain...");
    // make heightmap

    int NUM_OCT = 8;
    SimplexNoise[] noises = new SimplexNoise[NUM_OCT];
    for (int oct = 0; oct < NUM_OCT; ++oct)
    {
        noises[oct] = new SimplexNoise(rng);        
    }


    int[] height;
    vec2i mapDim = vec2i(512, 512);
    height.length = mapDim.x * mapDim.y;
    height[] = 0;

    
    for (int y = 0; y < mapDim.y; ++y)
    {
        for (int x = 0; x < mapDim.x; ++x)
        {  
            double fx = x / cast(double)mapDim.x;
            double fy = y / cast(double)mapDim.y;
            double z = 3;
            
            for (int oct = 0; oct < NUM_OCT; ++oct)
            {
                double freq = 2.0 ^^ oct;
                double zo = (noises[oct].noise(fx * freq, fy * freq));
                double amplitude = 44 * 2.0 ^^ (-oct);
                z += zo * amplitude;
            }


            if (z > 62) 
                z = 62;
            if (z >= 1) 
            {
                z = 1 + (((z - 1) / 62.0) ^^ 2.0) * 62.0;
            }
            if (z > 54) 
                z = 54 + log2(z - 53);

            double distanceToCenter = vec2f(x, y).distanceTo(vec2f(255,255));
            double heightIdeal = 7;
            z = mix(z, heightIdeal, clamp!double(2 - distanceToCenter * 0.012, 0, 1));
            
            int h = cast(int)(0.5 + z);
            if (h < 1) 
                h = 0;
            if (h > 62) 
                h = 62;

            height[y * mapDim.x + x] = h;
          
        }
    }

    // render height
    for (int y = 0; y < mapDim.y; ++y)
    {
        for (int x = 0; x < mapDim.x; ++x)
        {       
            int h = height[y * mapDim.x + x];
            for (int k = 1; k <= h; ++k)
            {
                vec3f color = void;

                if (k == 1)
                {
                    color = vec3f(0.9, 0.9, 0.9);
                    color += randomPerturbation(rng) * 0.015f;
                }
                else if (k == 2)
                {
                    vec3f sand = color = vec3f(0.9, 0.9, 0.9);
                    vec3f green = vec3f(168 / 255.0f, 194 / 255.0f, 75 / 255.0f);
                    color = (sand + green) / 2;
                    color += randomPerturbation(rng) * 0.015f;
                }
                else if (k < 16)
                {
                    vec3f green = vec3f(168 / 255.0f, 194 / 255.0f, 75 / 255.0f);
                    vec3f marron = vec3f(118 / 255.0f, 97 / 255.0f, 56 / 255.0f);
                    color = mix(green, marron, (k - 2.0f) / (16.0f - 2.0f));
                    color += randomPerturbation(rng) * 0.025f;
                }
                else if (k < 32)
                {
                    vec3f marron = vec3f(118 / 255.0f, 97 / 255.0f, 56 / 255.0f);
                    vec3f grey = vec3f(0.6f, 0.6f, 0.6f);
                    float t = (k - 16.0f) / (32.0f - 16.0f);
                    color = mix(marron, grey, (k - 16.0f) / (32.0f - 16.0f));
                    color += randomPerturbation(rng) * (0.02f - t * 0.01f);
                }
                else if (k < 48)
                {
                    vec3f grey = vec3f(0.6f, 0.6f, 0.6f);
                    vec3f white = vec3f(1,1,1);
                    color = mix(grey, white, (k - 32.0f) / (48.0f - 32.0f));
                    color += randomPerturbation(rng) * 0.01f;
                }
                else
                {
                    color = vec3f(1,1,1);
                    color += randomPerturbation(rng) * 0.01f;
                }

                map.block(x, y, k).setf(color);
            }            
        }
    }
}
