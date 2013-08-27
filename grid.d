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
    void buildBlocks(ref SimpleRng rng, Grid grid, vec3i base, AOSMap map);
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
            cell.balcony = BalconyType.NONE;
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
        assert(cast(uint)x < numCells.x);
        assert(cast(uint)y < numCells.y);
        assert(cast(uint)z < numCells.z);
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

    void getBalconyMask(vec3i cellPos, out bool isBalcony, out bool isBalconyLeft, out bool isBalconyRight, out bool isBalconyTop, out bool isBalconyBottom,)
    {
        Cell* c = &cell(cellPos);
        isBalcony = c.balcony != BalconyType.NONE;
        isBalconyLeft = false;
        isBalconyRight = false;
        isBalconyTop = false;
        isBalconyBottom = false;

        if (!isBalcony)
            return;

        if (cellPos.x == 0)
            isBalconyLeft = true;
        else
        {
            Cell* left = &cell(cellPos + vec3i(-1, 0, 0));
            if (left.type == CellType.AIR && c.type != CellType.STAIR_END_HIGH)
                isBalconyLeft = true;
        }

        if (cellPos.x + 1 == numCells.x)
            isBalconyRight = true;
        else
        {
            Cell* right = &cell(cellPos + vec3i(1, 0, 0));
            if (right.type == CellType.AIR && c.type != CellType.STAIR_END_HIGH)
                isBalconyRight = true;
        }

        if (cellPos.y == 0)
            isBalconyTop = true;
        else
        {
            Cell* top = &cell(cellPos + vec3i(0, -1, 0));
            if (top.type == CellType.AIR && c.type != CellType.STAIR_END_HIGH)
                isBalconyTop = true;
        }

        if (cellPos.y + 1 == numCells.y)
            isBalconyBottom = true;
        else
        {
            Cell* bottom = &cell(cellPos + vec3i(0, 1, 0));
            if (bottom.type == CellType.AIR && c.type != CellType.STAIR_END_HIGH)
                isBalconyBottom = true;
        }
    }

    bool canSeeInside(vec3i pos)
    {
        if (!contains(pos))
            return true;

        Cell* c = &cell(pos);
        if (c.type == CellType.FULL)
            return false;

        if (numConnections(pos.x, pos.y, pos.z) == 0)
            return false;

        return true;
    }
    
private:
    int numConnectionsImpl(int x, int y, int z, bool countZ)
    {
        Cell it = cell(x, y, z);

        if (it.type == CellType.FULL)
            return 0;

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
            if (!right.hasLeftWall && right.type != CellType.FULL)
                res++;
        }

        if (y + 1 < numCells.y)
        {
            Cell bottom = cell(x, y + 1, z);
            if (!bottom.hasTopWall && bottom.type != CellType.FULL)
                res++;
        }

        if (countZ && (z + 1 < numCells.z))
        {
            Cell above = cell(x, y, z + 1);
            if (!above.hasFloor && above.type != CellType.FULL)
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
