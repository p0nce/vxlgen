module area;

import gfm.math.vector, gfm.math.box;
import std.algorithm;
import std.range;

interface IArea
{
    int numBlocks();
    vec3i[] enumerateIndices();
}

class PointArea : IArea
{
public:
    this(vec3i coord)
    {
        _coord = coord;
    }

    int numBlocks()
    {
        return 1;
    }

    vec3i[] enumerateIndices()
    {
        return [_coord];
    }

private:
    vec3i _coord;
    int numBlocks();
}

class ListArea : IArea
{
public:
    this(vec3i[] coord)
    {
        _coord = coord.dup;
    }

    int numBlocks()
    {
        return cast(int)(_coord.length);
    }

    vec3i[] enumerateIndices()
    {
        return _coord;
    }

private:
    vec3i[] _coord;
}

class BoxArea : IArea
{
public:
    this(box3i b)
    {
        _b = b;
    }

    int numBlocks()
    {
        return _b.volume();
    }

    vec3i[] enumerateIndices()
    {
        vec3i[] res;
        for (int x = _b.min.x; x < _b.max.x; ++x)
            for (int y = _b.min.y; y < _b.max.y; ++y)
                for (int z = _b.min.z; z < _b.max.z; ++z)
                    res ~= vec3i(x, y, z);

        return res;
    }

private:
    box3i _b;
}


