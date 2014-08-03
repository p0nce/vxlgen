module main;

import std.stdio, 
       std.math,
       std.conv,
       std.string;

import dungeon;
import randutils;
import gfm.math.box;
import gfm.math.vector;
import aosmap;
import area;
import block;
import colorize;

enum MAJOR_VERSION = 0;
enum MINOR_VERSION = 2;




void usage()
{
    cwritefln("vxlgen v%d.%d, GFM generation tool.", MAJOR_VERSION, MINOR_VERSION);
    cwritefln("http://www.gamesfrommars.fr");
    cwritefln("usage: vxlgen [-seed n] [-o map-name] [-help]");
    cwritefln("    -seed: select a seed");
    cwritefln("    -o   : name of the output file (.txt and .vxl extensions added)");
    cwritefln("    -help: show this help");
}

void main(string[] argv)
{
    RNG rng;
    uint seed = unpredictableSeed();
    rng.seed(seed);

    // parse arguments

    string outputFileVXL = "output.vxl";
    string outputFileTXT = "output.txt";

    for(int i = 1; i < argv.length; ++i)
    {
        string arg = argv[i];
        if (arg == "-seed")
        {
            i = i + 1;
            if (i == argv.length)
            {
                cwritefln("error: expected a number.");
                usage();
                return;
            }
            uint ul = to!uint(argv[i]);
            rng.seed(ul);            
        }
        else if (arg == "-o")
        {
            i = i + 1;
            if (i == argv.length)
            {
                cwritefln("error: expected a filename.");
                usage();
                return;
            }
            outputFileVXL = argv[i] ~ ".vxl";
            outputFileTXT = argv[i] ~ ".txt";
        }     
        else if (arg == "-h" || arg == "-help")
        {
            usage();
            return;
        }
        else
        {
            cwritefln("error: unknown argument %s", arg);
            usage();
            return;
        }
    }

    auto map = new AOSMap();    
    
    cwritefln( color("*** Generating seed %s...", fg.light_green), seed);
    auto dungeon = new Dungeon(rng);

    cwritefln( color("*** Rendering dungeon...", fg.light_green));
    dungeon.render(rng, map);

    cwritefln( color("*** Saving map to %s...", fg.light_green), outputFileVXL);
    map.writeMap(outputFileVXL);

    cwritefln( color("*** Saving meta-data to %s...", fg.light_green), outputFileTXT);

    void writeTXT(string outputFileTXT, ulong seed)
    {
        auto f = File(outputFileTXT, "w"); // open for writing

        f.writefln("name = 'Random dungeon'");
        f.writefln("version = '%s.%s'", MAJOR_VERSION, MINOR_VERSION);
        f.writefln("author = 'vxlgen ~dungeon'");
        f.writefln("description = ('Dungeon generated map')");
        f.writefln("seed = %s", seed);

        f.writefln("extensions = {");


        f.writefln("}");
        
        f.close();
    }
    writeTXT(outputFileTXT, seed);

}

string pythonTuple(vec3i v)
{
    return format("(%s, %s, %s)", v.x, v.y, v.z);
}

string pythonTuple(vec3f v)
{
    return format("(%s, %s, %s)", v.x, v.y, v.z);
}



