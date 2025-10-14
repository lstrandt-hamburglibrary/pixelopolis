/**
 * BuildingData.ts
 * Building level statistics and configurations
 */

import { TileType, BuildingLevelStats } from '@/types';

/**
 * Building stats by tile type and level
 */
export const BUILDING_STATS: Record<TileType, Record<number, BuildingLevelStats>> = {
  [TileType.EMPTY]: {},
  [TileType.ROAD]: {},
  [TileType.POWER_PLANT]: {},

  // Residential buildings
  [TileType.RES]: {
    0: { population: 0, jobs: 0, shoppers: 0 }, // Empty lot
    1: { population: 10, jobs: 0, shoppers: 0 }, // Small house
    2: { population: 25, jobs: 0, shoppers: 0 }, // Apartment
    3: { population: 50, jobs: 0, shoppers: 0 }, // Tower
  },

  // Commercial buildings
  [TileType.COM]: {
    0: { population: 0, jobs: 0, shoppers: 0 }, // Empty lot
    1: { population: 0, jobs: 0, shoppers: 15 }, // Small shop
    2: { population: 0, jobs: 0, shoppers: 35 }, // Mall
    3: { population: 0, jobs: 0, shoppers: 70 }, // Mega mall
  },

  // Industrial buildings
  [TileType.IND]: {
    0: { population: 0, jobs: 0, shoppers: 0 }, // Empty lot
    1: { population: 0, jobs: 20, shoppers: 0 }, // Small factory
    2: { population: 0, jobs: 45, shoppers: 0 }, // Factory
    3: { population: 0, jobs: 90, shoppers: 0 }, // Industrial complex
  },
};

/**
 * Get building stats for a tile type and level
 */
export function getBuildingStats(tileType: TileType, level: number): BuildingLevelStats {
  const typeStats = BUILDING_STATS[tileType];
  if (!typeStats) {
    return { population: 0, jobs: 0, shoppers: 0 };
  }
  return typeStats[level] || { population: 0, jobs: 0, shoppers: 0 };
}

/**
 * Check if a tile type can have buildings
 */
export function canHaveBuildings(tileType: TileType): boolean {
  return tileType === TileType.RES || tileType === TileType.COM || tileType === TileType.IND;
}

/**
 * Get max level for buildings
 */
export const MAX_BUILDING_LEVEL = 3;
