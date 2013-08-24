module tower;

import std.math;
import std.stdio;

import vector;
import aosmap;
import randutils;
import cell;
import grid;
import room;
import pattern;
import stair;
import funcs;
import box;


// TODO stairs to hard to find

class Level
{
public:

    this(int lvl, ref SimpleRng rng, bool isRoof)
    {
        vec3f color = randomColor(rng);
        this(lvl, rng, color, isRoof);
    }

    this(int lvl, ref SimpleRng rng, vec3f color,  bool isRoof)
    {
        groundColorLight = mix!(vec3f, float)( color, vec3f(1,1,1), 0.4f + 0.2f * randUniform(rng));
        groundColorDark = mix!(vec3f, float)( color, vec3f(0,0,0), 0.4f + 0.2f * randUniform(rng));
        wallColor = mix!(vec3f, float)(color, vec3f(0.5f,0.5f,0.5f), 0.4f + 0.2f * randUniform(rng));


        // lower level very dark
        if (lvl == 0)
        {
            groundColorLight *= 0.3;
            groundColorDark *= 0.3;
            wallColor *= 0.3;
        }

        if (isRoof)
        {
            groundPattern = PatternEx(Pattern.ONLY_ONE, false, false, 0.003f);
            balcony = BalconyType.BATTLEMENT;
        }
        else
        {
            groundPattern = PatternEx(cast(Pattern)dice(rng, Pattern.min, Pattern.max + 1), randBool(rng), randBool(rng), 0.008f);
            balcony = BalconyType.SIMPLE;
        }
    }
    vec3f groundColorLight;
    vec3f groundColorDark;
    vec3f wallColor;
    PatternEx groundPattern;
    BalconyType balcony;
}

final class Tower : IBlockStructure
{
    vec3i position;
    vec3i numCells;
    vec3i cellSize;
    vec3i dimension;
    int entranceRoomSize;
    box3i blueEntrance;
    box3i greenEntrance;

    this(vec3i position, vec3i numCells)
    {
        numCells.z += 1; // for roof

        this.position = position;
        this.numCells = numCells;
        cellSize = vec3i(4, 4, 6);

        dimension = numCells * cellSize + 1;

        entranceRoomSize = 0;
        int minDim = numCells.x < numCells.y ? numCells.x : numCells.y;
        if (minDim >= 1)
            entranceRoomSize = 1;
        if (minDim >= 13)
            entranceRoomSize = 3;
        if (minDim >= 23)
            entranceRoomSize = 5;
    }

    void buildBlocks(ref SimpleRng rng, AOSMap map)
    {
        Level[] levels;
        for (int l = 0; l < numCells.z - 1; ++l)
        {
            levels ~= new Level(l, rng, false);
        }  
        levels ~= new Level(numCells.z - 1, rng, vec3f(0.85f), true);
        levels ~= new Level(numCells.z, rng, vec3f(0.85f), true);

      

        Grid grid = new Grid(numCells);

        // generate rough map
        for (int i = 0; i < numCells.x; ++i)
            for (int j = 0; j < numCells.y; ++j)
                for (int k = 0; k < numCells.z; ++k)
                {
                    Cell* cell = &grid.cell(i, j, k);

                    cell.hasLeftWall = randUniform(rng) < 0.6;
                    cell.hasTopWall = randUniform(rng) < 0.6;
                    float floorThreshold = 0.95f;
                    
                    if (k == 0)
                        floorThreshold = 0.9f;
                    
                    if (k == numCells.z - 1)
                        floorThreshold = 1.0f;
                    cell.hasFloor = randUniform(rng) < floorThreshold;
                }        
        
        buildExternalCells(grid, levels);

        Room[] rooms = addRooms(rng, grid);
        Stair[] stairs = addStairs(rng, grid, levels);

        // make sure every level is fully connected!
        ensureEachFloorConnected(rng, grid);

        removeUninterestingPatterns(rng, grid);
        
        writefln(" - Render cells...");

        // red water
        {
            vec3i d = numCells * cellSize + 1;
            vec3f red = vec3f(80, 0, 0) / 255.0f;
            for (int y = 0; y < d.y; ++y)
            {
                for (int x = 0; x < d.x; ++x)
                {  
                    map.block(position.x + x, position.y + y, 0).setf(red);
                }
            }
        }

        for (int lvl = 0; lvl < numCells.z; ++lvl)
        {
            Level level = levels[lvl];
            for (int cellX = 0; cellX < numCells.x; ++cellX)
            {
                for (int cellY = 0; cellY < numCells.y; ++cellY)
                {
                    clearCell(rng, grid, map, vec3i(cellX, cellY, lvl), level);                                     
                }
            }
        }

        for (int lvl = 0; lvl < numCells.z; ++lvl)
        {
            for (int cellX = 0; cellX < numCells.x; ++cellX)
            {
                for (int cellY = 0; cellY < numCells.y; ++cellY)
                {
                    renderCell(rng, grid, map, vec3i(cellX, cellY, lvl), levels);
                }
            }
        }

        // build block structures

        void build(ICellStructure s)
        {
            vec3i cellPos = s.getCellPosition();
            vec3i sposition = position + cellPos * cellSize;
            s.buildBlocks(rng, grid, sposition, map);
        }
        
        writefln(" - Build block structures...");
        foreach (room; rooms)
            build(room);

        foreach (stair; stairs)
            build(stair);

        
    }

    void buildExternalCells(Grid grid, Level[] levels)
    {
        for (int x = 0 ; x < numCells.x; ++x)
            for (int y = 0 ; y < numCells.y; ++y)
                for (int z = 0 ; z < numCells.z; ++z)
                {
                    vec3i p = vec3i(x, y, z);

                    Cell* c = &grid.cell(p);
                    if (grid.isExternal(p))
                    {
                        if (x == 0)
                            c.hasLeftWall = false;
                    
                        if (y == 0)
                            c.hasTopWall = false;

                        if (z <= 1)
                            c.type = CellType.FULL;
                        else
                            c.balcony = levels[z].balcony;
                    }

                    if (z + 1 == numCells.z)
                    {
                        c.hasLeftWall = false;
                        c.hasTopWall = false;
                    }

                }
    }

    void ensureEachFloorConnected(ref SimpleRng rng, Grid grid)
    {
        writefln("Make levels navigable...");
        vec3i[] stack;
        stack.length = numCells.x * numCells.y;
        int stackIndex = 0;

        vec3i[4] DIRECTIONS = [ vec3i(1, 0, 0), vec3i(-1, 0, 0), vec3i(0, 1, 0), vec3i(0, -1, 0) ];

        for (int lvl = 0; lvl < numCells.z; ++lvl)
        {            
            int[] colours;
            for (int cellX = 0; cellX < numCells.x; ++cellX)
            {
                for (int cellY = 0; cellY < numCells.y; ++cellY)
                {
                    Cell* c = &grid.cell(cellX, cellY, lvl);
                    if (shouldBeConnected(c.type))
                        c.color = -1;
                    else
                        c.color = -2;
                }
            }

            int numColors = 0;
            int[] colorLookup;

            while(true)
            {
                int firstX = 0;
                int firstY = 0;

                bool foundUncolored = false;

                for (int cellX = firstX; cellX < numCells.x; ++cellX)
                {
                    for (int cellY = firstY; cellY < numCells.y; ++cellY)
                    {
                        Cell* c = &grid.cell(cellX, cellY, lvl);
                        if (c.color == -1) // has no color
                        {
                            firstX = cellX;                            

                            foundUncolored = true;

                            int color = numColors++;
                            c.color = color;
                            colorLookup ~= color;    

                            stack[stackIndex++] = vec3i(cellX, cellY, lvl);

                            // colorize with magic wand
                            while (stackIndex > 0)
                            {
                                vec3i p = stack[--stackIndex];
                                grid.cell(p).color = color;

                                
                                foreach (dir ; DIRECTIONS)
                                    if (grid.isConnectedWith(p, dir))
                                    {
                                        int otherColor = grid.cell(p + dir).color;
                                        assert(otherColor == -1 || otherColor == -2 || otherColor == color);
                                        if (otherColor == -1)
                                        {
                                            stack[stackIndex++] = (p + dir);
                                        }
                                    }
                            }
                        }
                    }
                }

                if (!foundUncolored)
                    break;              
            }                  

            // everyone has a color now
            for (int cellX = 0; cellX < numCells.x; ++cellX)
            {
                for (int cellY = 0; cellY < numCells.y; ++cellY)
                {
                    assert(grid.cell(cellX, cellY, lvl).color != -1);
                }
            }

            // makes everything connex
            int coloursToEliminate = cast(int)(colorLookup.length) - 1;

            // might be infinite loop ! TODO exit
            int firstX = 0;
            eliminate_colours:
            while (coloursToEliminate > 0)
            {
                // might be very long...
                // TODO: random traversal
                for (int cellX = firstX; cellX < numCells.x; ++cellX)
                {
                    for (int cellY = 0; cellY < numCells.y; ++cellY)
                    {
                        vec3i p = vec3i(cellX, cellY, lvl);
                        Cell* c = &grid.cell(p);

                        bool tryOrder = randBool(rng);

                        for (int k = 0; k < 2; ++k)
                        {
                            bool tryRight = (k == 0)  ^ tryOrder;
                            vec3i dir;
                            if (tryRight) 
                                dir = vec3i(1, 0, 0);
                            else 
                                dir = vec3i(0, 1, 0);

                            if (c.color != -2 && grid.contains(p + dir))
                            {                                
                                Cell* other = &grid.cell(p + dir);

                                if (other.color != -2)
                                {
                                    int colorA = colorLookup[c.color];
                                    int colorB = colorLookup[other.color];

                                    if (colorA != colorB)
                                    {
                                        grid.connectWith(p, dir);
                                        int minColor = colorA < colorB ? colorA : colorB;
                                        int maxColor = colorA > colorB ? colorA : colorB;

                                        firstX = cellX;

                                        // eradicate all traces of maxColor
                    //                    writefln("color %s => %s",maxColor, minColor); 
                                        foreach (ref lookup ; colorLookup)
                                        {
                                            if (lookup == maxColor)
                                                lookup = minColor;
                                        }
                                        coloursToEliminate--;
                                        continue eliminate_colours;
                                    }
                                }
                            }
                        }
                    }
                }

                // found nothing!
                // we have connex things
          //      writefln("Found %s unreachable area in level %s", coloursToEliminate, lvl) ;
                break eliminate_colours;
            }

            // everyone has color 0 or -2, else it's an unreachable area
            for (int cellX = 0; cellX < numCells.x; ++cellX)
            {
                for (int cellY = 0; cellY < numCells.y; ++cellY)
                {
                    vec3i p = vec3i(cellX, cellY, lvl);
                    int color = grid.cell(p).color;
                    if (color != -2 && colorLookup[color] != 0)
                    {
                        // unreachable area
                        assert(colorLookup[color] == color);
                        grid.open(p);
                    }

                }
            }
                
        }
    }

    void removeUninterestingPatterns(ref SimpleRng rng, Grid grid)
    {
        while(true)
        {
            bool found = false;
            for (int z = 0; z < numCells.z; ++z)
            {            
                for (int x = 0; x < numCells.x; ++x)
                {
                    for (int y = 0; y < numCells.y; ++y)
                    {
                        if (grid.numConnections(x, y, z) == 1)
                        {
                            Cell* c = &grid.cell(x, y, z);
                            if (c.type == CellType.REGULAR)
                            {
                                found = true;
                                grid.close(vec3i(x, y, z));
                            }
                        }
                    }
                }
            }

            if (!found)
                break;
        }
    }

    Room[] addRooms(ref SimpleRng rng, Grid grid)
    {      
        Room[] rooms;
        double roomProportion = 0.09;
        double roomCells = numCells.x * numCells.y * numCells.z * roomProportion;
        int numRooms = 0;

        void tryRoom(box3i bb, bool isEntrance)
        {
            if (grid.canBuildRoom(bb))
            {
                Room room = new Room(bb, isEntrance, cellSize);
                room.buildCells(rng, grid);
                rooms ~= room;

                numRooms = numRooms + 1;
                roomCells -= bb.volume();
            }
        }
        
        // build 4 entrances
        if (numCells.x > 7 && numCells.y > 7 && numCells.z > 3)
        {
            vec3i entranceSize = vec3i(4, 5, 3);
            vec3i middle = (vec3i(numCells.x, numCells.y, 0) - entranceSize) / 2;

            vec3i east = vec3i(numCells.x - entranceSize.x, middle.y, 1);
            vec3i west = vec3i(0, middle.y, 1);

            blueEntrance = box3i(west, west + entranceSize);
            greenEntrance = box3i(east, east + entranceSize);

            tryRoom(greenEntrance, true);
            tryRoom(blueEntrance, true);
        }


        while (roomCells > 0)
        {
            int maxWidth = numCells.x > 7 ? 7 : numCells.x;
            int maxDepth = numCells.y > 7 ? 7 : numCells.y;
            int maxHeight = numCells.z > 10 ? 10 : numCells.z;

            int roomWidth = dice(rng, 3, maxWidth);
            int roomDepth = dice(rng, 3, maxDepth);
            int roomHeight = 1;
            while (roomHeight < maxHeight && randUniform(rng) < 0.5)
                roomHeight = roomHeight + 1;

            vec3i roomSize = vec3i(roomWidth, roomDepth, roomHeight);
            vec3i pos = vec3i(dice(rng, 0, 1 + numCells.x - roomSize.x), dice(rng, 0, 1 + numCells.y - roomSize.y), dice(rng, 0, 1 + numCells.z - roomSize.z));
            box3i bb = box3i(pos, pos + roomSize);

            tryRoom(bb, false);
        }
        writefln(" - Added %d rooms", numRooms);
        return rooms;
    }

    Stair[] addStairs(ref SimpleRng rng, Grid grid, Level[] levels)
    {
        Stair[] stairs;

        int stairAdded = 0;

        for (int lvl = 0; lvl < numCells.z - 1; ++lvl)
        {    
            int suitableCells = 0;

            // count regular cells
            for (int x = 0; x < numCells.x; ++x)
            {
                for (int y = 0; y < numCells.y; ++y)
                {
                    if (availableForStair(grid.cell(x, y, lvl).type))
                        suitableCells++;
                }
            }

            int numStairInLevels = cast(int)(0.5 + 32 * suitableCells / (63.0 * 63));

            int stairRemaining = numStairInLevels;
            while (stairRemaining > 0)
            {
                vec3i direction = randUniform(rng) < 0.5 ? vec3i(1, 0, 0) : vec3i(0, 1, 0);
                if (randUniform(rng) < 0.5) 
                    direction = -direction;

                vec3i posA = vec3i(dice(rng, 0, numCells.x), dice(rng, 0, numCells.y), lvl);
                vec3i posB = posA + direction;
                vec3i posC = posA - direction;
                vec3i posAboveD = posB + direction + vec3i(0, 0, 1);

                // should not be too near another stair
                bool tooNear = false;
                foreach (other ; stairs)
                {
                    vec3i diff = other.start - posA;
                    if (abs(diff.x) + abs(diff.y) < 2) // threshold to adapt to tower size
                    {
                        tooNear = true;
                    }
                }

                if (!tooNear && grid.contains(posA) && grid.contains(posB) && grid.contains(posC) && grid.contains(posAboveD))
                {
                    if (grid.canbuildStair(posA) && grid.canbuildStair(posB) && grid.canbuildStair(posC) && grid.canbuildStair(posAboveD))
                    {
                        Stair stair = new Stair(posA, direction, levels[lvl + 1].groundColorDark, levels[lvl + 1].groundColorLight );
                        stair.buildCells(rng, grid);
                        stairs ~= stair;                        
                        stairRemaining = stairRemaining - 1;
                        stairAdded += 1;
                    }
                }                
            }
        }
        writefln(" - Added %d stairs", stairAdded);
        return stairs;
    }

    void clearCell(ref SimpleRng rng, Grid grid, AOSMap map, vec3i cellPos, Level level)
    {
        vec3i blockPosition = position + cellPos * cellSize;
        int cellX = cellPos.x;
        int cellY = cellPos.y;
        int lvl = cellPos.z;
        int x = blockPosition.x;
        int y = blockPosition.y;
        int z = blockPosition.z;

        // clear block inner space
        for (int i = 0; i < 5; ++i)
            for (int j = 0; j < 5; ++j)
                for (int k = 0; k < 7; ++k)
                { 
                    vec3i pos = vec3i(x + i, y + j, z + k);
                    if (map.contains(pos))
                        map.block(x + i, y + j, z + k).empty();
                }
    }

    void renderCell(ref SimpleRng rng, Grid grid, AOSMap map, vec3i cellPos, Level[] levels)
    {
        vec3i blockPosition = position + cellPos * cellSize;
        int cellX = cellPos.x;
        int cellY = cellPos.y;
        int lvl = cellPos.z;
        int x = blockPosition.x;
        int y = blockPosition.y;
        int z = blockPosition.z;

        const(Cell) cell = grid.cell(cellPos);
        bool isBalcony, isBalconyLeft, isBalconyRight, isBalconyTop, isBalconyBottom;
        grid.getBalconyMask(cellPos, isBalcony, isBalconyLeft, isBalconyRight, isBalconyTop, isBalconyBottom);
        
        bool canSeeInside = grid.canSeeInside(cellPos);

        // cell ground
        if (cell.hasFloor)
        {
            vec3f lightColor = levels[lvl].groundColorLight;
            vec3f darkColor = levels[lvl].groundColorDark;
            if (isStairPart(cell.type))
            {
                lightColor = levels[lvl+1].groundColorLight;
                darkColor = levels[lvl+1].groundColorDark;
            }
            for (int i = 0; i < 5; ++i)
                for (int j = 0; j < 5; ++j)
                {
                    // sometime forget one
                    if (lvl + 1 != numCells.z && randUniform(rng) > 0.999)
                        continue;

                    vec3f color = patternColor(rng, levels[lvl].groundPattern, 
                                               i + cellX * 4, 
                                               j + cellY * 4, 
                                               lightColor, 
                                               darkColor);
                    map.block(x + i, y + j, z).setf(color);
                }
        }

        if (grid.numConnections(cellX, cellY, lvl) == 0)
        {     
            // no connection, make it full
            for (int i = 1; i < 4; ++i)
                for (int j = 1; j < 4; ++j)
                    for (int k = 1; k < 7; ++k)
                        map.block(x + i, y + j, z + k).setf(levels[lvl].wallColor);
        }

        int wallBase = lvl == 0 ? 0 : 1;


        if (cell.hasLeftWall)
        {
            vec3f wallColor = levels[lvl].wallColor;

            // walls around a stair are coloured differently
            vec3i leftCell = cellPos - vec3i(1, 0, 0);
            if (isStairPart(cell.type) || (grid.contains(leftCell) && isStairPart(grid.cell(leftCell).type)))
            {
                wallColor = levels[lvl+1].wallColor;
            }


            if (cellX == 1)
                wallColor = grey(wallColor, 0.6f);
            for (int j = 0; j < 5; ++j)
                for (int k = wallBase; k < 7; ++k)
                {                            
                    map.block(x, y + j, z + k).setf(wallColor);
                } 

            if (canSeeInside && grid.canSeeInside(leftCell))
            {
                // single window
                if (randUniform(rng) < 0.08)
                    map.block(x, y + 2, z + 3).empty();

                //  two windows
                else if (randUniform(rng) < 0.04)
                {
                    map.block(x, y + 1, z + 3).empty();
                    map.block(x, y + 3, z + 3).empty();
                }
                //  triple window
                else if (randUniform(rng) < 0.04)
                {
                    map.block(x, y + 1, z + 3).empty();
                    map.block(x, y + 2, z + 3).empty();
                    map.block(x, y + 3, z + 3).empty();
                }
    /*            else if (randUniform(rng) < 0.04)
                {
                    // door
                    map.block(x, y + 2, z + 3).empty();
                    map.block(x, y + 2, z + 2).empty();
                    map.block(x, y + 2, z + 1).empty();
                } */
            }
        }             

        if (cell.hasTopWall)
        {
            vec3f wallColor = levels[lvl].wallColor;

            // walls around a stair are coloured differently
            vec3i topCell = cellPos - vec3i(0, 1, 0);
            if (isStairPart(cell.type) || (grid.contains(topCell) && isStairPart(grid.cell(topCell).type)))
            {
                wallColor = levels[lvl+1].wallColor;
            }

            if (cellY == 1)
                wallColor = grey(wallColor, 0.6f);
            for (int i = 0; i < 5; ++i)
                for (int k = wallBase; k < 7; ++k)
                {                            
                    map.block(x + i, y, z + k).setf(wallColor);
                }

            if (canSeeInside && grid.canSeeInside(topCell))
            {
                // single window
                if (randUniform(rng) < 0.08)
                    map.block(x + 2, y, z + 3).empty();

                //  two windows
                else if (randUniform(rng) < 0.04)
                {
                    map.block(x + 1, y, z + 3).empty();
                    map.block(x + 3, y, z + 3).empty();
                }
                //  triple window
                else if (randUniform(rng) < 0.04)
                {
                    map.block(x + 1, y, z + 3).empty();
                    map.block(x + 2, y, z + 3).empty();
                    map.block(x + 3, y, z + 3).empty();
                }
         /*       else if (randUniform(rng) < 0.04)
                {
                    // door
                    map.block(x + 2, y, z + 3).empty();
                    map.block(x + 2, y, z + 2).empty();
                    map.block(x + 2, y, z + 1).empty();
                }*/
            }
        }

        if (cell.type == CellType.FULL)
        {
            vec3f fullColor = grey(levels[lvl].wallColor, 0.7f);
            for (int i = 0; i < 5; ++i)
                for (int j = 0; j < 5; ++j)
                    for (int k = 0; k < 6; ++k)
                        map.block(x + i, y + j, z + k).setf(fullColor);
        }

        if (isBalcony)
        {
            vec3f balconyColor = grey(levels[lvl].wallColor, 0.6f);

            for (int i = 0; i < 5; ++i)
            {
                for (int j = 0; j < 5; ++j)
                {
                    int wallSize = -1;

                    if (cell.hasFloor)
                    {
                        if (i == 0 && isBalconyLeft)
                            wallSize = 1;
                        if (j == 0 && isBalconyTop)
                            wallSize = 1;
                        if (i + 1 == 5 && isBalconyRight)
                            wallSize = 1;
                        if (j + 1 == 5 && isBalconyBottom)
                            wallSize = 1;
                    }

                    if (cell.balcony == BalconyType.BATTLEMENT)
                    {
                        if ((i ^ j) & 1)
                            wallSize = -1;                       
                    }

                    for (int k = 0; k <= wallSize; ++k)
                    {
                        map.block(x + i, y + j, z + k).setf(balconyColor);
                    }
                }
            }       

            if (lvl % 2 == 0)
            {
                if (grid.numConnections(cellX, cellY, lvl) == 0)
                {     
                    // no connection, make it full
                    for (int i = 0; i < 5; ++i)
                        for (int j = 0; j < 5; ++j)
                            for (int k = 1; k < 6; ++k)
                                map.block(x + i, y + j, z + k).setf(balconyColor);
                }
            }
        }
    }
}



