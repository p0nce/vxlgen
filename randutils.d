module randutils;


import std.random;

public import simplerng;
import vector, funcs;

int dice(ref SimpleRng rng, int min, int max)
{
    assert(max > min);
    int res;
    res = min + cast(int)(randUniform(rng) * (max - min));
    assert(res >= min && res < max);
    return res;
}

vec3f randomPerturbation(ref SimpleRng rng)
{
    return vec3f(rng.getNormal(0, 1), rng.getNormal(0, 1), rng.getNormal(0, 1));
}

vec3f randomColor(ref SimpleRng rng)
{
    return vec3f(rng.getUniform(), rng.getUniform(), rng.getUniform());
}

bool randBool(ref SimpleRng rng)
{
    //double x = rng.getUniform();
    return rng.getUint() & 1;
}

double randUniform(ref SimpleRng rng)
{
    auto rnd = Xorshift(rng.seed.x);
    rng.getUint();
    return uniform(0.0, 1.0, rnd);    
}

vec2i randomDirection(ref SimpleRng rng)
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
    return mix(color, vec3f(g, g, g), fraction);
}