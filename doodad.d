module doodad;
import std.algorithm;
import std.file;
import gfm.math;
import colorize;
import voxd;
import aosmap;


class Doodad
{
public:
    this(VOX vox)
    {
        _vox = vox;
        _size = vec3i(vox.width, vox.height, vox.depth);
    }

private:
    vec3i _size;
    VOX _vox;
}

Doodad[] loadAllDoodads()
{
    Doodad[] result;
    auto dFiles = filter!`endsWith(a.name,".vox")`(dirEntries(".",SpanMode.depth));
    foreach(d; dFiles)
    {
        result ~= new Doodad(decodeVOX(d));
        cwritefln(color(" - Loaded %s", fg.light_blue), d);
    }
    return result;
}

alias Direction = int;

void direction2vector(Direction dir, out mat2x2i m)
{
    switch(dir)
    {
        case 0: 
            m = mat2i(1, 0, 
                      0, 1); 
            break;
        case 1: 
            m = mat2i(0, 1, 
                      -1, 0); 
            break;
        case 2:
            m = mat2i(-1, 0, 
                      0, -1); 
            break;
        case 3:
            m = mat2i(0, -1, 
                      1, 0); 
            break;
        default:
            assert(0);
    }
}

class DoodadInstance
{
public:
    this(Doodad doodad, vec3i pos, Direction dir)
    {
        _pos = pos;
        _doodad = doodad;
        _dir = dir;
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
        mat2i mrot;
        direction2vector(_dir, mrot);
        int width = _doodad._vox.width;
        int height = _doodad._vox.height;
        int depth = _doodad._vox.depth;
        for (int z = 0; z < depth; ++z)
            for (int y = 0; y < height; ++y)
                for (int x = 0; x < width; ++x)
                {
                    vec2i disp = mrot * vec2i(x, y);
                    VoxColor c = _doodad._vox.voxel(x, y, z);
                    if (isVisible(c))
                        map.block(_pos.x + disp.x, _pos.y + disp.y, _pos.z + z).seti(c.r, c.g, c.b);
                    else
                        map.block(_pos.x + disp.x, _pos.y + disp.y, _pos.z + z).empty();
                }
    }

private:
    Doodad _doodad;
    vec3i _pos;
    Direction _dir;
}