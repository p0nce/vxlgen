module cell;


enum CellType
{
    AIR,
    REGULAR,
    ROOM_FLOOR,
    STAIR_BODY,
    STAIR_END,
    BALCONY
}

struct Cell
{
    bool hasLeftWall; // is connected to X-1
    bool hasTopWall; // is connected to Y-1    
    bool hasFloor; // is connected to Z-1
    CellType type;
    int color;
}

bool shouldBeConnected(CellType ct)
{
    final switch(ct)
    {
        case CellType.AIR: 
            return false;

        case CellType.BALCONY:
            return true;

        case CellType.REGULAR: 
            return true;

        case CellType.ROOM_FLOOR: 
            return true;

        case CellType.STAIR_BODY: 
            return false;

        case CellType.STAIR_END: 
            return true;
    }
}

bool availableForRoom(CellType ct)
{
    switch(ct)
    {
        case CellType.BALCONY:
            return true;

        case CellType.REGULAR: 
            return true;

        default:
            return false;
    }
}

bool availableForStair(CellType ct)
{
    switch(ct)
    {
        case CellType.REGULAR: 
            return true;

        default:
            return false;
    }
}