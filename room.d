module room;

import std.stdio;

import randutils;
import grid;
import cell;
import vector;
import aosmap;
import box;

class Room : ICellStructure
{   
    box3i pos;
    bool isEntrance;

    this(box3i p, bool isEntrance)
    {
        pos = p;
        this.isEntrance = isEntrance;
    }

    vec3i getCellPosition()
    {
        return pos.a;
    }

    void buildCells(ref SimpleRng rng, Grid grid)
    {
        for (int x = pos.a.x; x < pos.b.x; ++x)
            for (int y = pos.a.y; y < pos.b.y; ++y)
                for (int z = pos.a.z; z < pos.b.z; ++z)
                {                    
                    vec3i posi = vec3i(x, y, z);

                    grid.cell(posi).type = (z == pos.a.z) ? CellType.ROOM_FLOOR : CellType.AIR;

                    // balcony for floor
                    if (z == pos.a.z && grid.isExternal(posi) && !isEntrance)
                        grid.cell(posi).type = CellType.BALCONY;


                    // ensure floor
                    if (z == pos.a.z)
                        grid.cell(posi).hasFloor = true;

                    // ensure roof
                    if (grid.contains(x, y, z + 1) && (z + 1) == pos.b.z)
                        grid.disconnectWith(posi, vec3i(0, 0, 1));

                    // ensure space                    
                    if (x + 1 < pos.b.x)
                        grid.connectWith(posi, vec3i(1, 0, 0));

                    if (y + 1 < pos.b.y)
                        grid.connectWith(posi, vec3i(0, 1, 0));

                    if (z + 1 < pos.b.z)
                        grid.connectWith(posi, vec3i(0, 0, 1));
                }

        // balcony
        for (int z = pos.a.z + 1; z < pos.b.z; ++z)
            for (int x = pos.a.x - 1; x < pos.b.x + 1; ++x)
                for (int y = pos.a.y - 1; y < pos.b.y + 1; ++y)
                    if (grid.contains(x, y, z))
                    {
                        Cell* cell = &grid.cell(x, y, z);
                        if (cell.type == CellType.REGULAR)
                            cell.type = CellType.BALCONY;
                    }
    }

    void buildBlocks(ref SimpleRng rng, vec3i base, AOSMap map)
    {
        // todo add objects to room

    }
}
