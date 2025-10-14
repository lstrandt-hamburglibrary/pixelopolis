/**
 * GrowthSystem.ts
 * Handles building growth, upgrades, and abandonment
 */

import { WorldState } from '@/world/WorldState';
import { PowerSystem } from '@/systems/PowerSystem';
import { SIMULATION_CONFIG, CityStats } from '@/types';
import { canHaveBuildings, MAX_BUILDING_LEVEL } from './BuildingData';
import { rng } from '@/utils/RNG';
import { EventBus } from '@/utils/EventBus';

export class GrowthSystem {
  private worldState: WorldState;
  private powerSystem: PowerSystem;
  private cityStats: CityStats;

  constructor(worldState: WorldState, powerSystem: PowerSystem, cityStats: CityStats) {
    this.worldState = worldState;
    this.powerSystem = powerSystem;
    this.cityStats = cityStats;

    // Listen for simulation ticks
    EventBus.on('simulation:tick', this.onTick.bind(this));
  }

  /**
   * Handle simulation tick
   */
  private onTick(_tickCount: number): void {
    this.processGrowth();
  }

  /**
   * Process growth for all tiles
   */
  private processGrowth(): void {
    const width = this.worldState.getWidth();
    const height = this.worldState.getHeight();
    const deltaTime = SIMULATION_CONFIG.TICK_INTERVAL / 1000; // Convert to seconds

    const changedTiles: { x: number; y: number }[] = [];

    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        const tile = this.worldState.getTile(x, y);
        if (!tile || !canHaveBuildings(tile.type)) continue;

        const isPowered = this.powerSystem.isPowered(x, y);

        // Update unpowered time
        if (!tile.building) {
          tile.building = { level: 0, unpoweredTime: 0 };
        }

        if (!isPowered) {
          tile.building.unpoweredTime += deltaTime;
        } else {
          tile.building.unpoweredTime = 0;
        }

        // Abandonment: if unpowered for too long, downgrade
        if (
          tile.building.unpoweredTime >= SIMULATION_CONFIG.ABANDONMENT_TIME &&
          tile.building.level > 0
        ) {
          tile.building.level--;
          tile.building.unpoweredTime = 0;
          changedTiles.push({ x, y });
          EventBus.emit('building:abandoned', { x, y, type: tile.type, level: tile.building.level });
          continue;
        }

        // Only powered buildings can grow/upgrade
        if (!isPowered) continue;

        // Empty lot: try to spawn building
        if (tile.building.level === 0) {
          if (rng.next() < SIMULATION_CONFIG.GROWTH_CHANCE) {
            tile.building.level = 1;
            changedTiles.push({ x, y });
            EventBus.emit('building:spawned', { x, y, type: tile.type });
          }
        }
        // Existing building: try to upgrade
        else if (tile.building.level < MAX_BUILDING_LEVEL) {
          const upgradeChance =
            SIMULATION_CONFIG.UPGRADE_BASE_CHANCE *
            (this.cityStats.happiness >= 0.7
              ? SIMULATION_CONFIG.HAPPINESS_UPGRADE_MULTIPLIER
              : 1.0);

          if (rng.next() < upgradeChance) {
            tile.building.level++;
            changedTiles.push({ x, y });
            EventBus.emit('building:upgraded', { x, y, type: tile.type, level: tile.building.level });
          }
        }
      }
    }

    // Emit batch update event if any tiles changed
    if (changedTiles.length > 0) {
      EventBus.emit('buildings:changed', changedTiles);
    }
  }

  /**
   * Clean up
   */
  destroy(): void {
    EventBus.off('simulation:tick', this.onTick);
  }
}
