module room;
import randutils;
import gfm.math;
import aosmap;
import block;

class Room
{

    this(vec3i position, vec3i dimension)
    {
        this.position = position;
        this.dimension = dimension;
    }

    vec3i position;
    vec3i dimension;

    box3i box()
    {
        return box3i(position, position + dimension);
    }

    void render(ref RNG rng, AOSMap map)
    {
        int r = randInt(rng, 0, 255);
        int g = randInt(rng, 0, 255);
        int b = randInt(rng, 0, 255);
        //map.fill(box(), Block(r,g,b));
        map.clearBox(box());
    }
}
