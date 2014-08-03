module randutils;


private import std.random;

alias RNG = Xorshift64;

public import gfm.math.simplerng;
import gfm.math.vector, gfm.math.funcs;

int randInt(ref RNG rng, int min, int max)
{
    assert(max > min);
    int res = uniform(min, max, rng);
    assert(res >= min && res < max);
    return res;
}

vec3f randomPerturbation(ref RNG rng)
{
    return vec3f(rng.randNormal(0, 1), rng.randNormal(0, 1), rng.randNormal(0, 1));
}

vec3f randomColor(ref RNG rng)
{
    return vec3f(rng.randUniform(), rng.randUniform(), rng.randUniform());
}

bool randBool(ref RNG rng)
{
    return uniform(0, 2, rng) != 0;
}

double randUniform(ref RNG rng)
{
    return uniform(0.0, 1.0, rng);    
}

vec2i randomDirection(ref Random rng)
{
    int dir = dice(rng, 0, 4);
    if (dir == 0)
        return vec2i(1, 0);
    if (dir == 1)
        return vec2i(-1, 0);
    if (dir == 2)
        return vec2i(0, 1);
    if (dir == 3)
        return vec2i(0, -1);
    assert(false);
}

// only 2D rotation along z axis
vec3i rotate(vec3i v, vec3i direction)
{
    if (direction == vec3i(1, 0, 0))
    {
        return v;
    }
    else if (direction == vec3i(-1, 0, 0))
    {
        return vec3i (-v.x, -v.y, v.z);
    }
    else if (direction == vec3i(0, 1, 0))
    {
        return vec3i( -v.y, v.x, v.z);
    }
    else if (direction == vec3i(0, -1, 0))
    {
        return vec3i( v.y, -v.x, v.z);
    }
    else 
        assert(false);
}

vec3f grey(vec3f color, float fraction)
{
    float g = (color.x + color.y + color.z) / 3;
    return lerp(color, vec3f(g, g, g), fraction);
}