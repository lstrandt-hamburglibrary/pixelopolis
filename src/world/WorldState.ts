/**
 * WorldState.ts
 * Core world data model with JSON serialization
 */

import { Tile, TileType, TilePosition, WorldStateData, ISOMETRIC_CONFIG } from '@/types';
import { rng } from '@/utils/RNG';

export class WorldState {
  private width: number;
  private height: number;
  private tileSize: number;
  private tiles: Tile[][];
  private seed: number;

  constructor(width: number = 64, height: number = 64, tileSize: number = 32, seed?: number) {
    this.width = width;
    this.height = height;
    this.tileSize = tileSize;
    this.seed = seed ?? Date.now();

    // Initialize RNG with seed
    rng.setSeed(this.seed);

    // Initialize empty tile grid
    this.tiles = [];
    for (let y = 0; y < height; y++) {
      this.tiles[y] = [];
      for (let x = 0; x < width; x++) {
        this.tiles[y][x] = { type: TileType.EMPTY };
      }
    }
  }

  /**
   * Get tile at position
   */
  getTile(x: number, y: number): Tile | null {
    if (x < 0 || x >= this.width || y < 0 || y >= this.height) {
      return null;
    }
    return this.tiles[y][x];
  }

  /**
   * Set tile at position
   */
  setTile(x: number, y: number, tile: Tile): boolean {
    if (x < 0 || x >= this.width || y < 0 || y >= this.height) {
      return false;
    }
    this.tiles[y][x] = { ...tile };
    return true;
  }

  /**
   * Get tile type at position
   */
  getTileType(x: number, y: number): TileType | null {
    const tile = this.getTile(x, y);
    return tile ? tile.type : null;
  }

  /**
   * Set tile type at position
   */
  setTileType(x: number, y: number, type: TileType): boolean {
    const tile = this.getTile(x, y);
    if (!tile) return false;

    // Initialize building data for zone tiles
    const newTile = { ...tile, type };
    if (type === TileType.RES || type === TileType.COM || type === TileType.IND) {
      newTile.building = {
        level: 0,
        unpoweredTime: 0,
      };
    } else {
      // Remove building data for non-zone tiles
      delete newTile.building;
    }

    return this.setTile(x, y, newTile);
  }

  /**
   * Check if position is valid
   */
  isValidPosition(x: number, y: number): boolean {
    return x >= 0 && x < this.width && y >= 0 && y < this.height;
  }

  /**
   * Get world dimensions
   */
  getWidth(): number {
    return this.width;
  }

  getHeight(): number {
    return this.height;
  }

  getTileSize(): number {
    return this.tileSize;
  }

  getSeed(): number {
    return this.seed;
  }

  /**
   * Get world dimensions in pixels
   */
  getPixelWidth(): number {
    return this.width * this.tileSize;
  }

  getPixelHeight(): number {
    return this.height * this.tileSize;
  }

  /**
   * Convert world coordinates to tile position (ISOMETRIC)
   */
  worldToTile(worldX: number, worldY: number): TilePosition {
    // Isometric to tile coordinates
    const tileW = ISOMETRIC_CONFIG.TILE_WIDTH;
    const tileH = ISOMETRIC_CONFIG.TILE_HEIGHT;

    const tileX = (worldX / (tileW / 2) + worldY / (tileH / 2)) / 2;
    const tileY = (worldY / (tileH / 2) - worldX / (tileW / 2)) / 2;

    return {
      x: Math.floor(tileX),
      y: Math.floor(tileY),
    };
  }

  /**
   * Convert tile position to world coordinates (ISOMETRIC - center of diamond)
   */
  tileToWorld(tileX: number, tileY: number): { x: number; y: number } {
    // Tile to isometric screen coordinates
    const tileW = ISOMETRIC_CONFIG.TILE_WIDTH;
    const tileH = ISOMETRIC_CONFIG.TILE_HEIGHT;

    return {
      x: (tileX - tileY) * (tileW / 2),
      y: (tileX + tileY) * (tileH / 2),
    };
  }

  /**
   * Serialize to JSON
   */
  toJSON(): WorldStateData {
    return {
      width: this.width,
      height: this.height,
      tileSize: this.tileSize,
      tiles: this.tiles.map((row) => row.map((tile) => ({ ...tile }))),
      seed: this.seed,
      timestamp: Date.now(),
    };
  }

  /**
   * Serialize (alias for toJSON)
   */
  serialize(): WorldStateData {
    return this.toJSON();
  }

  /**
   * Load from WorldStateData
   */
  loadFromData(data: WorldStateData): void {
    this.tiles = data.tiles.map((row) => row.map((tile) => ({ ...tile })));
  }

  /**
   * Deserialize from JSON
   */
  static fromJSON(data: WorldStateData): WorldState {
    const world = new WorldState(data.width, data.height, data.tileSize, data.seed);
    world.tiles = data.tiles.map((row) => row.map((tile) => ({ ...tile })));
    return world;
  }

  /**
   * Export to JSON string
   */
  export(): string {
    return JSON.stringify(this.toJSON(), null, 2);
  }

  /**
   * Import from JSON string
   */
  static import(json: string): WorldState | null {
    try {
      const data = JSON.parse(json) as WorldStateData;
      return WorldState.fromJSON(data);
    } catch (error) {
      console.error('Failed to import world state:', error);
      return null;
    }
  }

  /**
   * Clear all tiles
   */
  clear(): void {
    for (let y = 0; y < this.height; y++) {
      for (let x = 0; x < this.width; x++) {
        this.tiles[y][x] = { type: TileType.EMPTY };
      }
    }
  }

  /**
   * Count tiles by type
   */
  countTiles(type: TileType): number {
    let count = 0;
    for (let y = 0; y < this.height; y++) {
      for (let x = 0; x < this.width; x++) {
        if (this.tiles[y][x].type === type) {
          count++;
        }
      }
    }
    return count;
  }
}
