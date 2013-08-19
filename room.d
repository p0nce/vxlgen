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
    vec3i cellSize;

    this(box3i p, bool isEntrance, vec3i cellSize)
    {
        pos = p;
        this.isEntrance = isEntrance;
        this.cellSize = cellSize;
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

    void buildBlocks(ref SimpleRng rng, Grid grid, vec3i base, AOSMap map)
    {
        // red carpet for entrance
        /+if (isEntrance)
        {
            vec3f redCarpet = vec3f(1, 0, 0);
            for (int x = 0; x < pos.width(); ++x)
                for (int y = 0; y < pos.height(); ++y)
                {
                    int z = 0;
                    vec3i cellPos = pos.a + vec3i(x, y, z);
                    
                    Cell* cell = &grid.cell(cellPos);
                    if (cell.type == CellType.ROOM_FLOOR)
                    {
                        for (int j = 0; j < cellSize.y; ++j)
                        {
                            for (int i = 0; i < cellSize.x; ++i)
                            {
                                map.block(vec3i(i, j, 0) + cellPos * cellSize).setf(redCarpet);
                            }
                        }
                    }                    
                }

        }
        +/
    }
}
