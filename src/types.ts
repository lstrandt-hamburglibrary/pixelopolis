/**
 * types.ts
 * Core type definitions for Pixelopolis
 */

// ==================== TILE SYSTEM ====================

/**
 * Tile types for zoning
 */
export enum TileType {
  EMPTY = 0,
  ROAD = 1,
  RES = 2, // Residential
  COM = 3, // Commercial
  IND = 4, // Industrial
  POWER_PLANT = 5, // Power plant
}

/**
 * Building data for zone tiles
 */
export interface BuildingData {
  level: number; // 0 = empty lot, 1-3 = building levels
  unpoweredTime: number; // Seconds without power (for abandonment)
}

/**
 * Tile data structure
 */
export interface Tile {
  type: TileType;
  building?: BuildingData; // Only for RES/COM/IND tiles
  metadata?: Record<string, any>; // For future expansion
}

/**
 * Tile position in grid
 */
export interface TilePosition {
  x: number;
  y: number;
}

/**
 * Isometric configuration
 */
export const ISOMETRIC_CONFIG = {
  TILE_WIDTH: 64, // Width of isometric tile diamond
  TILE_HEIGHT: 32, // Height of isometric tile diamond
  BUILDING_HEIGHT_PER_LEVEL: 16, // Vertical pixels per building level
} as const;

// ==================== WORLD STATE ====================

/**
 * Serializable world state
 */
export interface WorldStateData {
  width: number;
  height: number;
  tileSize: number;
  tiles: Tile[][];
  seed: number;
  timestamp: number;
}

// ==================== BRUSH SYSTEM ====================

/**
 * Brush types (includes eraser)
 */
export enum BrushType {
  ROAD = 'ROAD',
  RES = 'RES',
  COM = 'COM',
  IND = 'IND',
  POWER_PLANT = 'POWER_PLANT',
  ERASER = 'ERASER',
}

/**
 * Brush tool configuration
 */
export interface BrushConfig {
  type: BrushType;
  size: number; // Future: support larger brushes
}

// ==================== COMMANDS ====================

/**
 * Command interface for undo/redo
 */
export interface Command {
  execute(): void;
  undo(): void;
  readonly name: string;
}

/**
 * Paint tile command data
 */
export interface PaintTileCommandData {
  position: TilePosition;
  oldTile: Tile;
  newTile: Tile;
}

// ==================== CAMERA ====================

/**
 * Camera state
 */
export interface CameraState {
  x: number;
  y: number;
  zoom: number;
  minZoom: number;
  maxZoom: number;
}

// ==================== RENDERING ====================

/**
 * Chunk configuration
 */
export interface ChunkConfig {
  chunkSize: number; // Tiles per chunk (e.g., 8×8)
  tileSize: number; // Pixels per tile
}

/**
 * Chunk position
 */
export interface ChunkPosition {
  chunkX: number;
  chunkY: number;
}

/**
 * Visual bounds
 */
export interface Bounds {
  left: number;
  top: number;
  right: number;
  bottom: number;
}

// ==================== CONSTANTS ====================

/**
 * Tile color mapping (enhanced saturation for Bit City look)
 */
export const TILE_COLORS: Record<TileType, number> = {
  [TileType.EMPTY]: 0x7ec850, // Bright grass green
  [TileType.ROAD]: 0x888888, // Lighter gray
  [TileType.RES]: 0x2ecc71, // Green
  [TileType.COM]: 0x3498db, // Blue
  [TileType.IND]: 0xf39c12, // Orange
  [TileType.POWER_PLANT]: 0xf1c40f, // Yellow
};

/**
 * Brush type to tile type mapping
 */
export const BRUSH_TO_TILE: Record<BrushType, TileType | null> = {
  [BrushType.ROAD]: TileType.ROAD,
  [BrushType.RES]: TileType.RES,
  [BrushType.COM]: TileType.COM,
  [BrushType.IND]: TileType.IND,
  [BrushType.POWER_PLANT]: TileType.POWER_PLANT,
  [BrushType.ERASER]: TileType.EMPTY,
};

/**
 * Brush display names
 */
export const BRUSH_NAMES: Record<BrushType, string> = {
  [BrushType.ROAD]: 'Road',
  [BrushType.RES]: 'Residential',
  [BrushType.COM]: 'Commercial',
  [BrushType.IND]: 'Industrial',
  [BrushType.POWER_PLANT]: 'Power Plant',
  [BrushType.ERASER]: 'Eraser',
};

/**
 * Brush colors for UI
 */
export const BRUSH_COLORS: Record<BrushType, number> = {
  [BrushType.ROAD]: TILE_COLORS[TileType.ROAD],
  [BrushType.RES]: TILE_COLORS[TileType.RES],
  [BrushType.COM]: TILE_COLORS[TileType.COM],
  [BrushType.IND]: TILE_COLORS[TileType.IND],
  [BrushType.POWER_PLANT]: TILE_COLORS[TileType.POWER_PLANT],
  [BrushType.ERASER]: 0xff0000,
};

// ==================== POWER SYSTEM ====================

/**
 * Power system constants
 */
export const POWER_CONFIG = {
  POWER_PER_PLANT: 200, // Power units provided by each plant
  POWER_RADIUS: 8, // Manhattan distance for power distribution
  POWERED_TINT: 0x88ff88, // Green tint for powered tiles
  UNPOWERED_TINT: 0x444444, // Dark tint for unpowered tiles
  OVERLAY_ALPHA: 0.4, // Alpha for power overlay
} as const;

/**
 * Power status for a tile
 */
export interface PowerStatus {
  isPowered: boolean;
  nearestPlantDistance?: number;
}

/**
 * Power grid state
 */
export interface PowerGridState {
  capacity: number; // Total power capacity (200 per plant)
  demand: number; // Number of powered building tiles
  plants: TilePosition[]; // Positions of all power plants
  poweredTiles: Set<string>; // Set of powered tile keys "x,y"
}

/**
 * Tile types that require power
 */
export const POWER_CONSUMING_TILES: TileType[] = [
  TileType.RES,
  TileType.COM,
  TileType.IND,
  TileType.ROAD,
];

/**
 * Tile display names
 */
export const TILE_NAMES: Record<TileType, string> = {
  [TileType.EMPTY]: 'Empty',
  [TileType.ROAD]: 'Road',
  [TileType.RES]: 'Residential',
  [TileType.COM]: 'Commercial',
  [TileType.IND]: 'Industrial',
  [TileType.POWER_PLANT]: 'Power Plant',
};

// ==================== SIMULATION SYSTEM ====================

/**
 * Simulation configuration
 */
export const SIMULATION_CONFIG = {
  TICK_RATE: 10, // Hz (10 ticks per second)
  TICK_INTERVAL: 100, // ms (1000 / 10)
  GROWTH_CHANCE: 0.01, // 1% chance per tick for empty lot to spawn building
  UPGRADE_BASE_CHANCE: 0.005, // 0.5% chance per tick to upgrade
  HAPPINESS_UPGRADE_MULTIPLIER: 2.0, // Multiplier when happy
  ABANDONMENT_TIME: 30, // Seconds without power before abandonment
  BASE_HAPPINESS: 0.5,
  POWER_HAPPINESS_BONUS: 0.2, // When >10% spare capacity
  SPARE_CAPACITY_THRESHOLD: 0.1, // 10%
  TAX_INTERVAL: 3, // Seconds between tax collection
} as const;

/**
 * Building level stats
 */
export interface BuildingLevelStats {
  population: number; // RES
  jobs: number; // IND
  shoppers: number; // COM
}

/**
 * Economy configuration
 */
export const ECONOMY_CONFIG = {
  TAX_PER_POPULATION: 2,
  TAX_PER_SHOPPER: 1,
  TAX_PER_JOB: 1,
  UPKEEP_PER_ROAD: 1,
  UPKEEP_PER_PLANT: 5,
  STARTING_BALANCE: 1000,
} as const;

/**
 * City statistics
 */
export interface CityStats {
  balance: number;
  population: number;
  jobs: number;
  shoppers: number;
  happiness: number;
}

// ==================== SAVE SYSTEM ====================

/**
 * Save data schema version
 */
export const SAVE_VERSION = 1;

/**
 * Complete save data
 */
export interface SaveData {
  version: number;
  timestamp: number;
  seed: number;
  worldState: WorldStateData;
  cityStats: CityStats;
}

/**
 * Save system configuration
 */
export const SAVE_CONFIG = {
  AUTOSAVE_INTERVAL: 15000, // 15 seconds in ms
  STORAGE_KEY: 'pixelopolis_save',
  INDICATOR_DURATION: 2000, // 2 seconds
} as const;
