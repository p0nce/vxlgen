module main;

import std.stdio, 
       std.math,
       std.conv,
       std.string;

import randutils;
import box;
import vector;
import aosmap;
import area;
import block;
import tower;
import terrain;

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
    SimpleRng rng = SimpleRng.make();

    // parse arguments

    string outputFileVXL = "output.vxl";
    string outputFileTXT = "output.txt";

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
            seed = rng.seed.x | (cast(ulong)(rng.seed.y) << 32);
            assert(seed == ul);
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

    int floors = dice(rng, 7, 11);
    int cellsX = dice(rng, 21, 41);
    int cellsY = dice(rng, 21, 41);

    makeTerrain(rng, map);

    vec3i cellSize = vec3i(4, 4, 6);
    
    vec3i numCells = vec3i(cellsX, cellsY, floors);
    vec3i dimensions = numCells * cellSize + 1;
    vec3i towerPos = vec3i(254 - dimensions.x/2, 254 - dimensions.y/2, 1);    
    box3i blueSpawnArea;
    box3i greenSpawnArea;

    writefln("- cell size is %s", pythonTuple(cellSize));
    writefln("- num cells is %s", pythonTuple(numCells));

    makeTower(rng, map, towerPos, numCells, cellSize, blueSpawnArea, greenSpawnArea);

    debug {} else
    {
        writefln("*** Color bleeding...");
        map.colorBleed();

        writefln("*** Compute omnidirectional Ambient Occlusion...");
        map.betterAO();

        writefln("*** Reverse client Ambient Occlusion...");
        map.reverseClientAO();
    }

    writefln("*** Saving map to %s...", outputFileVXL);
    map.writeMap(outputFileVXL);

    writefln("*** Saving meta-data to %s...", outputFileTXT);

    void writeTXT(string outputFileTXT, ulong seed)
    {
        auto f = File(outputFileTXT, "w"); // open for writing

        f.writefln("name = 'Labyrinth'");
        f.writefln("version = '%s.%s'", MAJOR_VERSION, MINOR_VERSION);
        f.writefln("author = 'vxlgen'");
        f.writefln("description = ('Labyrinth generated map')");
        f.writefln("seed = %s", seed);

        f.writefln("extensions = {");

        f.writefln("  'tower_position': %s,", pythonTuple(towerPos) );
        f.writefln("  'tower_cells': %s,", pythonTuple(numCells) );
        f.writefln("  'cell_size': %s,", pythonTuple(cellSize) );
        vec3f blueSpawnPos = cast(vec3f)(blueSpawnArea.a + blueSpawnArea.b) / 2.0f;
        vec3f greenSpawnPos = cast(vec3f)(greenSpawnArea.a + greenSpawnArea.b) / 2.0f;
        blueSpawnPos.z = 63 - 7;
        greenSpawnPos.z = 63 - 7;

        f.writefln("  'blue_base_coord': %s,", pythonTuple(blueSpawnPos));
        f.writefln("  'green_base_coord': %s", pythonTuple(greenSpawnPos));

        //f.writefln("  'blue_base_coord': %s,", pythonTuple(vec3f(254.5f - 55.0f, 254.5f, 63 - 7)));
        //f.writefln("  'green_base_coord': %s", pythonTuple(vec3f(254.5f + 55.0f, 254.5f, 63 - 7)));

        f.writefln("}");
        
        f.close();
    }
    writeTXT(outputFileTXT, seed);

}

void makeTower(ref SimpleRng rng, AOSMap map, vec3i towerPos, vec3i numCells, vec3i cellSize, out box3i blueSpawnArea, out box3i greenSpawnArea)
{
    assert(cellSize == vec3i(4, 4, 6)); // TODO other cell size?
    writefln("*** Build tower...");
      
    auto tower = new Tower(towerPos, numCells);
    tower.buildBlocks(rng, map);

    blueSpawnArea = box3i(towerPos + tower.blueEntrance.a * cellSize, towerPos + tower.blueEntrance.b * cellSize);
    greenSpawnArea = box3i(towerPos + tower.greenEntrance.a * cellSize, towerPos + tower.greenEntrance.b * cellSize);
}

void makeTerrain(ref SimpleRng rng, AOSMap map)
{
    writefln("*** Generate terrain...");
    auto terrain = new Terrain(vec2i(512, 512), rng);
    terrain.buildBlocks(rng, map);
}

string pythonTuple(vec3i v)
{
    return format("(%s, %s, %s)", v.x, v.y, v.z);
}

string pythonTuple(vec3f v)
{
    return format("(%s, %s, %s)", v.x, v.y, v.z);
}

