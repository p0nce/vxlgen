module perlin;

import std.math;

import randutils;

class Perlin3D
{
public:
    this(ref SimpleRng rng)
    {
        p.length = 256;
        Gx.length = 256;
        Gy.length = 256;
        Gz.length = 256;

        for (int i=0; i<256; ++i) 
        {
            p[i] = i;
            Gx[i] = -1 + 2 * randUniform(rng);
            Gy[i] = -1 + 2 * randUniform(rng);
            Gz[i] = -1 + 2 * randUniform(rng);
        }

        int j=0;
        int swp=0;
        for (int i=0; i<256; i++) 
        {
            j = dice(rng, 0, 256);

            swp = p[i];
            p[i] = p[j];
            p[j] = swp;
        }
    }
    

    // Generates a Perlin (smoothed) noise value between -1 and 1, at the given 3D position.
    float noise(float sample_x, float sample_y, float sample_z)
    {
        // Unit cube vertex coordinates surrounding the sample point
        int x0 = cast(int)(floor(sample_x));
        int x1 = x0 + 1;
        int y0 = cast(int)(floor(sample_y));
        int y1 = y0 + 1;
        int z0 = cast(int)(floor(sample_z));
        int z1 = z0 + 1;

        // Determine sample point position within unit cube
        float px0 = sample_x - x0;
        float px1 = px0 - 1.0f;
        float py0 = sample_y - y0;
        float py1 = py0 - 1.0f;
        float pz0 = sample_z - z0;
        float pz1 = pz0 - 1.0f;

        // Compute dot product between gradient and sample position vector
        int gIndex = p[(x0 + p[(y0 + p[z0 & 255]) & 255]) & 255];
        float d000 = Gx[gIndex]*px0 + Gy[gIndex]*py0 + Gz[gIndex]*pz0;
        gIndex = p[(x1 + p[(y0 + p[z0 & 255]) & 255]) & 255];
        float d001 = Gx[gIndex]*px1 + Gy[gIndex]*py0 + Gz[gIndex]*pz0;

        gIndex = p[(x0 + p[(y1 + p[z0 & 255]) & 255]) & 255];
        float d010 = Gx[gIndex]*px0 + Gy[gIndex]*py1 + Gz[gIndex]*pz0;
        gIndex = p[(x1 + p[(y1 + p[z0 & 255]) & 255]) & 255];
        float d011 = Gx[gIndex]*px1 + Gy[gIndex]*py1 + Gz[gIndex]*pz0;

        gIndex = p[(x0 + p[(y0 + p[z1 & 255]) & 255]) & 255];
        float d100 = Gx[gIndex]*px0 + Gy[gIndex]*py0 + Gz[gIndex]*pz1;
        gIndex = p[(x1 + p[(y0 + p[z1 & 255]) & 255]) & 255];
        float d101 = Gx[gIndex]*px1 + Gy[gIndex]*py0 + Gz[gIndex]*pz1;

        gIndex = p[(x0 + p[(y1 + p[z1 & 255]) & 255]) & 255];
        float d110 = Gx[gIndex]*px0 + Gy[gIndex]*py1 + Gz[gIndex]*pz1;
        gIndex = p[(x1 + p[(y1 + p[z1 & 255]) & 255]) & 255];
        float d111 = Gx[gIndex]*px1 + Gy[gIndex]*py1 + Gz[gIndex]*pz1;

        // Interpolate dot product values at sample point using polynomial interpolation 6x^5 - 15x^4 + 10x^3
        float wx = ((6*px0 - 15)*px0 + 10)*px0*px0*px0;
        float wy = ((6*py0 - 15)*py0 + 10)*py0*py0*py0;
        float wz = ((6*pz0 - 15)*pz0 + 10)*pz0*pz0*pz0;

        float xa = d000 + wx*(d001 - d000);
        float xb = d010 + wx*(d011 - d010);
        float xc = d100 + wx*(d101 - d100);
        float xd = d110 + wx*(d111 - d110);
        float ya = xa + wy*(xb - xa);
        float yb = xc + wy*(xd - xc);
        float value = ya + wz*(yb - ya);
        return value;
    }


private:
    // Permutation table  
    int[] p; 

    // Gradient vectors
    float[] Gx; 
    float[] Gy;
    float[] Gz;
};
