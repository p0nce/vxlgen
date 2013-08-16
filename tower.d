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

    this(int lvl, ref SimpleRng rng)
    {
        vec3f color = randomColor(rng);
        this(lvl, rng, color);
    }

    this(int lvl, ref SimpleRng rng, vec3f color)
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

        groundPattern = PatternEx(cast(Pattern)dice(rng, Pattern.min, Pattern.max + 1), randBool(rng), randBool(rng));
    }
    vec3f groundColorLight;
    vec3f groundColorDark;
    vec3f wallColor;
    PatternEx groundPattern;
}

class Tower : IBlockStructure
{
    vec3i position;
    vec3i numCells;
    vec3i cellSize;
    vec3i dimension;
    int entranceRoomSize;

    this(vec3i position, vec3i numCells)
    {
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
        levels.length = numCells.z;
        for (int l = 0; l < numCells.z; ++l)
        {
            levels[l] = new Level(l, rng);
        }  
        levels ~= new Level(numCells.z, rng, vec3f(0.7f));


        Grid grid = new Grid(numCells);

        // generate rough map
        for (int i = 0; i < numCells.x; ++i)
            for (int j = 0; j < numCells.y; ++j)
                for (int k = 0; k < numCells.z; ++k)
                {
                    Cell* cell = &grid.cell(i, j, k);

                    cell.hasLeftWall = randUniform(rng) < 0.5;
                    cell.hasTopWall = randUniform(rng) < 0.5;
                    cell.hasFloor = randUniform(rng)  < 0.95;
                }        
        
        buildExternalCells(grid);

        Room[] rooms = addRooms(rng, grid);
        Stair[] stairs = addStairs(rng, grid, levels);

        // make sure every level is fully connected!
        ensureEachFloorConnected(rng, grid);

        removeUninterestingPatterns(rng, grid);
        
        writefln(" - Render cells...");

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
            s.buildBlocks(rng, sposition, map);
        }
        
        writefln(" - Build block structures...");
        foreach (room; rooms)
            build(room);

        makeTowerEnvelope(rng, map);
        foreach (stair; stairs)
            build(stair);

        
    }

    void buildExternalCells(Grid grid)
    {
        for (int x = 0 ; x < numCells.x; ++x)
            for (int y = 0 ; y < numCells.y; ++y)
                for (int z = 0 ; z < numCells.z; ++z)
                {
                    vec3i p = vec3i(x, y, z);

                    Cell* c = &grid.cell(p);
                    if (grid.isExternal(p))
                    {
                        c.type = CellType.BALCONY;

                        if (x == 0)
                        {
                            c.hasLeftWall = false;
                        }

                        if (y == 0)
                        {
                            c.hasTopWall = false;
                        }
                    }
                }
    }

    void makeTowerEnvelope(ref SimpleRng rng, AOSMap map)
    {             

        vec3f grey = vec3f(0.7f,0.7f,0.7f);
        vec3f lightGrey = vec3f(0.8f,0.8f,0.8f);

        // top
        {
            for (int x = 0 ; x < dimension.x; ++x)
                for (int y = 0 ; y < dimension.y; ++y)
                {
                    map.block(position.x + x, position.y + y, position.z + dimension.z - 1).setf(lightGrey);
                }     

            for (int x = 0 ; x < dimension.x; x += 2)            
            {
                map.block(position.x + x, position.y, position.z + dimension.z).setf(grey);            
                map.block(position.x + x, position.y + dimension.y - 1, position.z + dimension.z).setf(lightGrey);            
            }

            for (int y = 0 ; y < dimension.y; y += 2)
            {
                map.block(position.x, position.y + y, position.z + dimension.z).setf(grey);
                map.block(position.x + dimension.x - 1, position.y + y, position.z + dimension.z).setf(lightGrey);
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

                        for (int k = 0; k < 2; ++k)
                        {
                            bool tryRight = k == 0;
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
                            if (c.type == CellType.REGULAR || c.type == CellType.BALCONY)
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

    Room[]  addRooms(ref SimpleRng rng, Grid grid)
    {      
        Room[] rooms;
        double roomProportion = 0.09;
        double roomCells = numCells.x * numCells.y * numCells.z * roomProportion;
        int numRooms = 0;

        void tryRoom(box3i bb, bool isEntrance)
        {
            if (grid.canBuildRoom(bb))
            {
                Room room = new Room(bb, isEntrance);
                room.buildCells(rng, grid);
                rooms ~= room;

                numRooms = numRooms + 1;
                roomCells -= bb.volume();
            }
        }
        
        // build 4 entrances
        if (numCells.x > 7 && numCells.y > 7 && numCells.z > 3)
        {
            vec3i entranceSize = vec3i(3, 3, 3);
            vec3i middle = (vec3i(31, 31, 0) - entranceSize) / 2;

            vec3i north = vec3i(middle.x, 0, 1);
            vec3i south = vec3i(middle.x, numCells.y - entranceSize.y, 1);
            vec3i east = vec3i(numCells.x - entranceSize.x, middle.y, 1);
            vec3i west = vec3i(0, middle.y, 1);

            tryRoom(box3i(north, north + entranceSize), true);
            tryRoom(box3i(south, south + entranceSize), true);
            tryRoom(box3i(east, east + entranceSize), true);
            tryRoom(box3i(west, west + entranceSize), true);
        }


        while (roomCells > 0)
        {
            int maxWidth = numCells.x > 7 ? 7 : numCells.x;
            int maxDepth = numCells.y > 7 ? 7 : numCells.y;
            int maxHeight = numCells.z > 7 ? 7 : numCells.z;

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
        int numStairInLevels = cast(int)(0.5 + 32 * (numCells.x * numCells.y) / (63.0 * 63)); // TODO adapt to available cells
        for (int lvl = 0; lvl < numCells.z; ++lvl)
        {            
            int stairRemaining = numStairInLevels;
            while (stairRemaining > 0)
            {
                vec3i direction = randUniform(rng) < 0.5 ? vec3i(1, 0, 0) : vec3i(0, 1, 0);
                if (randUniform(rng) < 0.5) 
                    direction = -direction;

                vec3i posA = vec3i(dice(rng, 0, numCells.x), dice(rng, 0, numCells.y), lvl);
                vec3i posB = posA + direction;
                vec3i posC = posA - direction;

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


                if (!tooNear && grid.contains(posA) && grid.contains(posB) && grid.contains(posC))
                {
                    if (grid.canbuildStair(posA) && grid.canbuildStair(posB) && grid.canbuildStair(posC))
                    {
                        Stair stair = new Stair(posA, direction, levels[lvl + 1].groundColorDark, levels[lvl + 1].groundColorLight );
                        stair.buildCells(rng, grid);
                        stairs ~= stair;                        
                        stairRemaining = stairRemaining - 1;
                    }
                }                
            }
        }
        writefln(" - Added %d stairs", numCells.z * numStairInLevels);
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

        const(Cell) cell = grid.cell(cellPos);
        bool isBalcony = cell.type == CellType.BALCONY;
        

        int xmin = 0;
        int xmax = 5;
        int ymin = 0;
        int ymax = 5;

        if (isBalcony)
        {
            bool isBalconyLeft = isBalcony && ( (cellX == 0) || grid.cell(cellPos + vec3i(-1, 0, 0)).type == CellType.AIR);
            bool isBalconyRight = isBalcony && ( (cellX + 1 == numCells.x) || grid.cell(cellPos + vec3i(1, 0, 0)).type == CellType.AIR);
            bool isBalconyTop = isBalcony && ( (cellY == 0) || grid.cell(cellPos + vec3i(0, -1, 0)).type == CellType.AIR);
            bool isBalconyBottom = isBalcony && ( (cellY + 1 == numCells.y) || grid.cell(cellPos + vec3i(0, 1, 0)).type == CellType.AIR);
        }
        
        // clear block inner space
        for (int i = xmin; i < xmax; ++i)
            for (int j = ymin; j < ymax; ++j)
                for (int k = 0; k < 7; ++k)
                {                
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
        bool isBalcony = cell.type == CellType.BALCONY;
        bool isBalconyLeft = isBalcony && ( (cellX == 0) || grid.cell(cellPos + vec3i(-1, 0, 0)).type == CellType.AIR);
        bool isBalconyRight = isBalcony && ( (cellX + 1 == numCells.x) || grid.cell(cellPos + vec3i(1, 0, 0)).type == CellType.AIR);
        bool isBalconyTop = isBalcony && ( (cellY == 0) || grid.cell(cellPos + vec3i(0, -1, 0)).type == CellType.AIR);
        bool isBalconyBottom = isBalcony && ( (cellY + 1 == numCells.y) || grid.cell(cellPos + vec3i(0, 1, 0)).type == CellType.AIR);
        
        if (isBalcony)
        {
            int xmin = 0;
            int xmax = 5;
            int ymin = 0;
            int ymax = 5;

            vec3f wallColor = grey(levels[lvl].wallColor, 0.6f);

            for (int i = xmin; i < xmax; ++i)
            {
                for (int j = ymin; j < ymax; ++j)
                {
                    vec3f color = patternColor(rng, levels[lvl].groundPattern, 
                                                i + cellX * 4, 
                                                j + cellY * 4, 
                                                levels[lvl].groundColorLight, 
                                                levels[lvl].groundColorDark);

                    int wallSize = -1;
                    int lvlBalconyWall = lvl == 0 ? 6 : 1;
                    if (cell.hasFloor)
                    {
                        map.block(x + i, y + j, z).setf(color);

                        if (i == xmin && isBalconyLeft)
                            wallSize = lvlBalconyWall;
                        if (j == ymin && isBalconyTop)
                            wallSize = lvlBalconyWall;
                        if (i + 1 == xmax && isBalconyRight)
                            wallSize = lvlBalconyWall;
                        if (j + 1 == ymax && isBalconyBottom)
                            wallSize = lvlBalconyWall;
                    }

                    if (lvl <= 1)
                        wallSize = 6;
                        
                    if (i == 0 && cell.hasLeftWall)
                        wallSize = 6;
                    if (j == 0 && cell.hasTopWall)
                        wallSize = 6;

                    vec3f black = vec3f(0,0,0);
                    for (int k = 0; k <= wallSize; ++k)
                    {
                        map.block(x + i, y + j, z + k).setf(wallColor);
                    }
                }
            }

            if (grid.numConnections(cellX, cellY, lvl) == 0)
            {     
                // no connection, make it full
                for (int i = xmin; i < xmax; ++i)
                    for (int j = ymin; j < ymax; ++j)
                        for (int k = 1; k < 7; ++k)
                            map.block(x + i, y + j, z + k).setf(wallColor);
            }
            return;
        }

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
                    if (randUniform(rng) > 0.999)
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
    //        return;
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

            // single window
            if (randUniform(rng) < 0.04)
                map.block(x, y + 2, z + 3).empty();

            //  two windows
            else if (randUniform(rng) < 0.02)
            {
                map.block(x, y + 1, z + 3).empty();
                map.block(x, y + 3, z + 3).empty();
            }
            //  triple window
            if (randUniform(rng) < 0.02)
            {
                map.block(x, y + 1, z + 3).empty();
                map.block(x, y + 2, z + 3).empty();
                map.block(x, y + 3, z + 3).empty();
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

            // single window
            if (randUniform(rng) < 0.04)
                map.block(x + 2, y, z + 3).empty();

            //  two windows
            else if (randUniform(rng) < 0.02)
            {
                map.block(x + 1, y, z + 3).empty();
                map.block(x + 3, y, z + 3).empty();
            }
            //  triple window
            if (randUniform(rng) < 0.02)
            {
                map.block(x + 1, y, z + 3).empty();
                map.block(x + 2, y, z + 3).empty();
                map.block(x + 3, y, z + 3).empty();
            }
        } 
    }
}



void makeTower(ref SimpleRng rng, AOSMap map)
{
    writefln("*** Build tower...");


    vec3i towerPos = vec3i(128 + 64, 128 + 64, 1);
    vec3i numCells = vec3i(63 - 32, 63 - 32, 10);
  
    auto tower = new Tower(towerPos, numCells);
    tower.buildBlocks(rng, map);

}



