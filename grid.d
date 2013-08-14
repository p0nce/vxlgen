module grid;

import vector;
import std.math;
import cell;
import aosmap;
import randutils;
import box;

interface ICellStructure
{    
    void buildCells(ref SimpleRng rng, Grid grid);

    vec3i getCellPosition();
    void buildBlocks(ref SimpleRng rng, vec3i base, AOSMap map);
}

// grid of cells
class Grid
{
    vec3i numCells;
    Cell[] cells;

    this(vec3i numCells)
    {
        this.numCells = numCells;

        cells.length = numCells.x * numCells.y * numCells.z;

        foreach (ref cell ; cells)
        {
            cell.type = CellType.REGULAR;
        }
    }

    bool contains(vec3i v)
    {
        return contains(v.x, v.y, v.z);
    }

    bool contains(int x, int y, int z)
    {
        if (cast(uint)x  >= numCells.x) 
            return false;
        if (cast(uint)y  >= numCells.y) 
            return false;
        if (cast(uint)z  >= numCells.z) 
            return false;
        return true;
    }

    ref Cell cell(vec3i v)
    {
        return cell(v.x, v.y, v.z);
    }

    ref Cell cell(int x, int y, int z)
    {
        return cells[z * (numCells.x * numCells.y ) + y * numCells.x + x];
    }

    int numConnections(int x, int y, int z)
    {
        return numConnectionsImpl(x, y, z, true);
    }

    int numConnectionsSameLevel(int x, int y, int z)
    {
        return numConnectionsImpl(x, y, z, false);
    }   

    bool isExternal(vec3i v)
    {
        if (v.x == 0 || v.y == 0)
            return true;
        if (v.x + 1 == numCells.x || v.y + 1 == numCells.y)
            return true;
        return false;
    }
    

    // only works with direct neighbours
    bool isConnectedWith(vec3i v, vec3i dir)
    {
        assert(abs(dir.x) + abs(dir.y) + abs(dir.z) == 1);
        assert(contains(v));
        if (!contains(v + dir))
            return false;

        Cell it = cell(v);
        if (dir.x == -1)
            return !it.hasLeftWall;
        if (dir.y == -1)
            return !it.hasTopWall;
        if (dir.z == -1)
            return !it.hasFloor;

        Cell other = cell(v + dir);
        if (dir.x == 1)
            return !other.hasLeftWall;
        if (dir.y == 1)
            return !other.hasTopWall;
        if (dir.z == 1)
            return !other.hasFloor;

        assert(false);
    }

    void connectWith(vec3i v, vec3i dir)
    {
        return setWall(v, dir, false);
    }

    void disconnectWith(vec3i v, vec3i dir)
    {
        return setWall(v, dir, true);
    }

    void tryDisconnectWith(vec3i v, vec3i dir)
    {
        if (contains(v + dir))
            return setWall(v, dir, true);
    }

    void tryConnectWith(vec3i v, vec3i dir)
    {
        if (contains(v + dir))
            return setWall(v, dir, false);
    }

    bool canbuildStair(vec3i pos)
    {
        CellType type = cell(pos).type;
        return availableForStair(type);
    }

    bool canBuildRoom(box3i pos)
    {
        for (int x = pos.a.x; x < pos.b.x; ++x)
            for (int y = pos.a.y; y < pos.b.y; ++y)
                for (int z = pos.a.z; z < pos.b.z; ++z)
                {
                    CellType type = cell(x, y, z).type;
                    if (!availableForRoom(type))
                        return false;
                }
        return true;
    }

    void close(vec3i v)
    {
        tryDisconnectWith(v, vec3i(1, 0, 0));
        tryDisconnectWith(v, vec3i(-1, 0, 0));
        tryDisconnectWith(v, vec3i(0, 1, 0));
        tryDisconnectWith(v, vec3i(0, -1, 0));
        tryDisconnectWith(v, vec3i(0, 0, 1));
        tryDisconnectWith(v, vec3i(0, 0, -1));
    }

    void open(vec3i v)
    {
        tryConnectWith(v, vec3i(1, 0, 0));
        tryConnectWith(v, vec3i(-1, 0, 0));
        tryConnectWith(v, vec3i(0, 1, 0));
        tryConnectWith(v, vec3i(0, -1, 0));
        tryConnectWith(v, vec3i(0, 0, 1));
        tryConnectWith(v, vec3i(0, 0, -1));
    }
    
private:
    int numConnectionsImpl(int x, int y, int z, bool countZ)
    {
        Cell it = cell(x, y, z);

        int res = 0;
        
        if (z > 0 && !it.hasFloor && countZ) 
            res++;
        if (x > 0 && !it.hasLeftWall) 
            res++;
        if (y > 0 && !it.hasTopWall) 
            res++;

        if (x + 1 < numCells.x)
        {
            Cell right = cell(x + 1, y, z);
            if (!right.hasLeftWall)
                res++;
        }

        if (y + 1 < numCells.y)
        {
            Cell bottom = cell(x, y + 1, z);
            if (!bottom.hasTopWall)
                res++;
        }

        if (countZ && (z + 1 < numCells.z))
        {
            Cell above = cell(x, y, z + 1);
            if (!above.hasFloor)
                res++;
        }
        return res;
    }

    // only works with direct neighbours
    void setWall(vec3i v, vec3i dir, bool enabled)
    {
        assert(abs(dir.x) + abs(dir.y) + abs(dir.z) == 1);
        assert(contains(v));
        assert(contains(v + dir));

        Cell* it = &cell(v);
        if (dir.x == -1)
            it.hasLeftWall = enabled;
        else if (dir.y == -1)
            it.hasTopWall = enabled;
        else if (dir.z == -1)
            it.hasFloor = enabled;

        Cell* other = &cell(v + dir);
        if (dir.x == 1)
            other.hasLeftWall = enabled;
        else if (dir.y == 1)
            other.hasTopWall = enabled;
        else if (dir.z == 1)
            other.hasFloor = enabled;
    }
}