module main;

import std.stdio, 
       std.math,
       std.conv,
       std.string;

import randutils;
import gfm.math.box;
import gfm.math.vector;
import aosmap;
import area;
import block;

enum MAJOR_VERSION = 0;
enum MINOR_VERSION = 2;

void usage()
{
    writefln("vxlgen v%d.%d, GFM generation tool.", MAJOR_VERSION, MINOR_VERSION);
    writefln("http://www.gamesfrommars.fr");
    writefln("usage: vxlgen [-seed n] [-o map-name] [-help]");
    writefln("    -seed: select a seed");
    writefln("    -o   : name of the output file (.txt and .vxl extensions added)");
    writefln("    -help: show this help");
}

void main(string[] argv)
{
    Random rng;
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
                writefln("error: expected a number.");
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
                writefln("error: expected a filename.");
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
            writefln("error: unknown argument %s", arg);
            usage();
            return;
        }
    }

    auto map = new AOSMap();    
    
    writefln("*** Generating seed %s...", seed);



    writefln("*** Saving map to %s...", outputFileVXL);
    map.writeMap(outputFileVXL);

    writefln("*** Saving meta-data to %s...", outputFileTXT);

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

