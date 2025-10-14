/**
 * PowerSystem.ts
 * Manages power grid: capacity, demand, and distribution
 */

import { WorldState } from '@/world/WorldState';
import {
  TileType,
  TilePosition,
  PowerGridState,
  PowerStatus,
  POWER_CONFIG,
  POWER_CONSUMING_TILES,
} from '@/types';

export class PowerSystem {
  private worldState: WorldState;
  private gridState: PowerGridState;

  constructor(worldState: WorldState) {
    this.worldState = worldState;
    this.gridState = {
      capacity: 0,
      demand: 0,
      plants: [],
      poweredTiles: new Set(),
    };

    // Initial calculation
    this.recalculate();
  }

  /**
   * Recalculate entire power grid
   * Called when tiles change
   */
  recalculate(): void {
    // Find all power plants
    this.gridState.plants = this.findPowerPlants();

    // Calculate capacity (200 per plant)
    this.gridState.capacity = this.gridState.plants.length * POWER_CONFIG.POWER_PER_PLANT;

    // Calculate powered tiles
    this.gridState.poweredTiles.clear();
    this.gridState.demand = 0;

    // For each power-consuming tile, check if it's powered
    const width = this.worldState.getWidth();
    const height = this.worldState.getHeight();

    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        const tile = this.worldState.getTile(x, y);
        if (!tile) continue;

        // Check if tile consumes power
        if (POWER_CONSUMING_TILES.includes(tile.type)) {
          // Check if within range of any power plant
          if (this.isWithinPowerRange(x, y)) {
            this.gridState.poweredTiles.add(`${x},${y}`);
            this.gridState.demand++;
          }
        }
      }
    }
  }

  /**
   * Find all power plant positions
   */
  private findPowerPlants(): TilePosition[] {
    const plants: TilePosition[] = [];
    const width = this.worldState.getWidth();
    const height = this.worldState.getHeight();

    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        const tile = this.worldState.getTile(x, y);
        if (tile && tile.type === TileType.POWER_PLANT) {
          plants.push({ x, y });
        }
      }
    }

    return plants;
  }

  /**
   * Check if a tile is within power range of any plant
   * Uses Manhattan distance
   */
  private isWithinPowerRange(tileX: number, tileY: number): boolean {
    for (const plant of this.gridState.plants) {
      const distance = this.manhattanDistance(tileX, tileY, plant.x, plant.y);
      if (distance <= POWER_CONFIG.POWER_RADIUS) {
        return true;
      }
    }
    return false;
  }

  /**
   * Calculate Manhattan distance between two points
   */
  private manhattanDistance(x1: number, y1: number, x2: number, y2: number): number {
    return Math.abs(x1 - x2) + Math.abs(y1 - y2);
  }

  /**
   * Check if a specific tile is powered
   */
  isPowered(x: number, y: number): boolean {
    return this.gridState.poweredTiles.has(`${x},${y}`);
  }

  /**
   * Get power status for a tile
   */
  getPowerStatus(x: number, y: number): PowerStatus {
    const isPowered = this.isPowered(x, y);

    if (!isPowered || this.gridState.plants.length === 0) {
      return { isPowered: false };
    }

    // Find nearest plant
    let nearestDistance = Infinity;
    for (const plant of this.gridState.plants) {
      const distance = this.manhattanDistance(x, y, plant.x, plant.y);
      if (distance < nearestDistance) {
        nearestDistance = distance;
      }
    }

    return {
      isPowered: true,
      nearestPlantDistance: nearestDistance,
    };
  }

  /**
   * Get current power grid state
   */
  getGridState(): PowerGridState {
    return {
      ...this.gridState,
      poweredTiles: new Set(this.gridState.poweredTiles),
      plants: [...this.gridState.plants],
    };
  }

  /**
   * Get capacity
   */
  getCapacity(): number {
    return this.gridState.capacity;
  }

  /**
   * Get demand
   */
  getDemand(): number {
    return this.gridState.demand;
  }

  /**
   * Get all power plant positions
   */
  getPowerPlants(): TilePosition[] {
    return [...this.gridState.plants];
  }

  /**
   * Get all powered tile positions
   */
  getPoweredTiles(): Set<string> {
    return new Set(this.gridState.poweredTiles);
  }

  /**
   * Check if a tile needs power (is a power-consuming type)
   */
  needsPower(tileType: TileType): boolean {
    return POWER_CONSUMING_TILES.includes(tileType);
  }
}
