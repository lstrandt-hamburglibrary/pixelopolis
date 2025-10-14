/**
 * EconomySystem.ts
 * Handles taxes, upkeep, and city statistics
 */

import { WorldState } from '@/world/WorldState';
import { PowerSystem } from '@/systems/PowerSystem';
import {
  CityStats,
  SIMULATION_CONFIG,
  ECONOMY_CONFIG,
  TileType,
} from '@/types';
import { getBuildingStats, canHaveBuildings } from './BuildingData';
import { EventBus } from '@/utils/EventBus';

export class EconomySystem {
  private worldState: WorldState;
  private powerSystem: PowerSystem;
  private cityStats: CityStats;
  private lastTaxTime: number = 0;

  constructor(worldState: WorldState, powerSystem: PowerSystem) {
    this.worldState = worldState;
    this.powerSystem = powerSystem;

    // Initialize city stats
    this.cityStats = {
      balance: ECONOMY_CONFIG.STARTING_BALANCE,
      population: 0,
      jobs: 0,
      shoppers: 0,
      happiness: SIMULATION_CONFIG.BASE_HAPPINESS,
    };

    // Listen for simulation ticks
    EventBus.on('simulation:tick', this.onTick.bind(this));
  }

  /**
   * Handle simulation tick
   */
  private onTick(tickCount: number): void {
    // Calculate stats every tick
    this.calculateStats();

    // Collect taxes every TAX_INTERVAL seconds
    const elapsedTime = tickCount * (SIMULATION_CONFIG.TICK_INTERVAL / 1000);
    if (elapsedTime - this.lastTaxTime >= SIMULATION_CONFIG.TAX_INTERVAL) {
      this.collectTaxes();
      this.lastTaxTime = elapsedTime;
    }

    // Emit stats update
    EventBus.emit('economy:updated', this.cityStats);
  }

  /**
   * Calculate city statistics
   */
  private calculateStats(): void {
    let population = 0;
    let jobs = 0;
    let shoppers = 0;

    const width = this.worldState.getWidth();
    const height = this.worldState.getHeight();

    // Count all buildings and their stats
    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        const tile = this.worldState.getTile(x, y);
        if (!tile || !canHaveBuildings(tile.type) || !tile.building) continue;

        const stats = getBuildingStats(tile.type, tile.building.level);
        population += stats.population;
        jobs += stats.jobs;
        shoppers += stats.shoppers;
      }
    }

    this.cityStats.population = population;
    this.cityStats.jobs = jobs;
    this.cityStats.shoppers = shoppers;

    // Calculate happiness
    this.calculateHappiness();
  }

  /**
   * Calculate happiness based on power capacity
   */
  private calculateHappiness(): void {
    const capacity = this.powerSystem.getCapacity();
    const demand = this.powerSystem.getDemand();

    let happiness = SIMULATION_CONFIG.BASE_HAPPINESS;

    // Add bonus if we have spare capacity
    if (capacity > 0 && demand > 0) {
      const spareCapacity = (capacity - demand) / capacity;
      if (spareCapacity >= SIMULATION_CONFIG.SPARE_CAPACITY_THRESHOLD) {
        happiness += SIMULATION_CONFIG.POWER_HAPPINESS_BONUS;
      }
    }

    // Clamp to [0, 1]
    this.cityStats.happiness = Math.max(0, Math.min(1, happiness));
  }

  /**
   * Collect taxes and pay upkeep
   */
  private collectTaxes(): void {
    // Income from buildings
    const income =
      this.cityStats.population * ECONOMY_CONFIG.TAX_PER_POPULATION +
      this.cityStats.shoppers * ECONOMY_CONFIG.TAX_PER_SHOPPER +
      this.cityStats.jobs * ECONOMY_CONFIG.TAX_PER_JOB;

    // Upkeep costs
    const roadCount = this.worldState.countTiles(TileType.ROAD);
    const plantCount = this.worldState.countTiles(TileType.POWER_PLANT);
    const upkeep =
      roadCount * ECONOMY_CONFIG.UPKEEP_PER_ROAD +
      plantCount * ECONOMY_CONFIG.UPKEEP_PER_PLANT;

    // Update balance
    const netIncome = income - upkeep;
    this.cityStats.balance += netIncome;

    // Ensure balance never goes NaN
    if (isNaN(this.cityStats.balance)) {
      this.cityStats.balance = 0;
    }

    // Emit tax collection event
    EventBus.emit('economy:taxes-collected', { income, upkeep, netIncome });
  }

  /**
   * Get current city stats
   */
  getCityStats(): CityStats {
    return { ...this.cityStats };
  }

  /**
   * Set city stats (for loading from save)
   */
  setCityStats(stats: CityStats): void {
    this.cityStats = { ...stats };
    EventBus.emit('economy:updated', this.cityStats);
  }

  /**
   * Clean up
   */
  destroy(): void {
    EventBus.off('simulation:tick', this.onTick);
  }
}
