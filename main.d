module main;

import std.stdio;
import std.math;
import std.conv;

import randutils;
import vector;
import aosmap;
import area;
import block;
import tower;
import terrain;


// aos://16777343:32887





void usage()
{
    writefln("vxlgen v0.1, GFM generation tool.");
    writefln("http://www.gamesfrommars.fr");
    writefln("usage: vxlgen [-seed n] [-o output-file.vxl]");
}

void main(string[] argv)
{
    SimpleRng rng = SimpleRng.make();

    // parse arguments

    string outputFile = "output.vxl";

    ulong seed = rng.seed.x | (cast(ulong)(rng.seed.y) << 32);

    for(int i = 1; i < argv.length; ++i)
    {
        string arg = argv[i];
        if (arg == "-seed")
        {
            i = i + 1;
            if (i == argv.length)
            {
                writefln("error: expected a number.");
                usage();
                return;
            }
            ulong ul = to!ulong(argv[i]);
            uint a = ul & 0xffffffff;
            uint b = (ul >> 32) & 0xffffffff;
            rng = SimpleRng(vec2ui(a, b));
        }
        else if (arg == "-o")
        {
            i = i + 1;
            if (i == argv.length)
            {
                writefln("error: expected a filename.");
                usage();
                return;
            }
            outputFile = argv[i];
        }
        else if (arg == "-h" || arg == "-help")
        {
            usage();
            return;
        }
    }

    auto map = new AOSMap();    
    
    writefln("*** Generating seed %s...", seed);
    makeTerrain(rng, map);
    makeTower(rng, map);
    writefln("*** Color bleeding...");
    map.colorBleed();

    writefln("*** Compute omnidirectional Ambient Occlusion...");
    map.betterAO();

    writefln("*** Reverse client Ambient Occlusion...");
    map.reverseClientAO();

    writefln("*** Saving to %s...", outputFile);
    map.writeMap(outputFile);
}


