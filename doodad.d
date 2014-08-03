module doodad;
import std.algorithm;
import std.file;
import gfm.math;
import colorize;
import voxd;


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

class DoodadInstance
{
public:
    this(Doodad doodad, vec3i pos)
    {
        _pos = pos;
        _doodad = doodad;
    }

private:
    Doodad _doodad;
    vec3i _pos;
}