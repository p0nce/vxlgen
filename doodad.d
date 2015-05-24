module doodad;

import std.algorithm;
import std.file;
import gfm.math;
import colorize;
import voxd;
import aosmap;


// All doodads exist in six versions
enum numDirection = 16;

enum Direction
{
    unchanged,
    rotate90,
    rotate180,
    rotate270,

    invertXY,
    mirrorY,
    mirrorXY,
    mirrorX
}

class Doodad
{
public:

    VOX vox;
    alias vox this;

    this(VOX vox)
    {
        this.vox = vox;
        _size = vec3i(vox.width, vox.height, vox.depth);
    }

    vec3i transformDirection(int x, int y, int z, Direction dir)
    {
        final switch(dir) with (Direction)
        {
            case unchanged: return vec3i(x, y, z);
            case rotate90: return vec3i(height - 1 - y, x, z);
            case rotate180: return vec3i(width - 1 - x, height - 1 - y, z);
            case rotate270: return vec3i(y, width - 1 - x, z);
            case invertXY: return vec3i(y, x, z);
            case mirrorY: return vec3i(x, height - 1 - y, z);
            case mirrorXY: return vec3i(height - 1 - y, width - 1 - x, z);
            case mirrorX: return vec3i(width - 1 - x, y, z);
        }
    }

    vec3i transformSize(int width, int height, int depth, Direction dir)
    {
        final switch(dir) with (Direction)
        {
            case unchanged:
            case mirrorY:
            case rotate180:
            case mirrorX:
                return vec3i(width, height, depth);

            case rotate90:            
            case rotate270:
            case invertXY:
            case mirrorXY:
                 return vec3i(height, width, depth);
        }        
    }

    void applyDirection(Direction dir)
    {
        VOX newVox;
        vec3i newSize = transformSize(width, height, depth, dir);
        newVox.width = newSize.x;
        newVox.height = newSize.y;
        newVox.depth = newSize.z;
        newVox.voxels.length = newVox.numVoxels();

        for (int z = 0; z < newVox.depth; ++z)
            for (int y = 0; y < newVox.height; ++y)
                for (int x = 0; x < newVox.width; ++x)
                {
                    vec3i source = transformDirection(x, y, z, dir);
                    newVox.voxel(x, y, z) = vox.voxel(source.x, source.y, source.z);                    
                }

        vox = newVox;
    }

private:
    vec3i _size;    
}

Doodad[] loadAllDoodads()
{
    Doodad[] result;
    auto dFiles = filter!`endsWith(a.name,".vox")`(dirEntries("doodads",SpanMode.depth));
    foreach(d; dFiles)
    {
        for (Direction dir = Direction.min; dir <= Direction.max; ++dir)
        {
            VOX vox = decodeVOX(d);
            auto doodad = new Doodad(vox);
            doodad.applyDirection(dir);
            result ~= doodad;
            cwritefln(color(" - Loaded %s", fg.light_blue), d);
        }
    }
    return result;
}

class DoodadInstance
{
public:
    this(Doodad doodad, vec3i pos)
    {
        _pos = pos;
        _doodad = doodad;
    }

    bool isVisible(VoxColor c)
    {
        if (c.a == 0)
            return false;

        if (c.r == 0 && c.g == 255 && c.b == 0)
            return false;

        return true;
    }

    void render(AOSMap map)
    {
        int width = _doodad.width;
        int height = _doodad.height;
        int depth = _doodad.depth;
        for (int z = 0; z < depth; ++z)
            for (int y = 0; y < height; ++y)
                for (int x = 0; x < width; ++x)
                {
                    VoxColor c = _doodad.voxel(x, y, z);
                    int px = _pos.x + x;
                    int py = _pos.y + y;
                    int pz = _pos.z + z;
                    if (map.contains(px, py, pz))
                    {
                        if (isVisible(c))
                                map.block(px, py, pz).seti(c.r, c.g, c.b);
                        else
                            map.block(px, py, pz).empty();
                    }
                }
    }

private:
    Doodad _doodad;
    vec3i _pos;
    Direction _dir;
}
