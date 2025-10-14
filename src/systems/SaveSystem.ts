/**
 * SaveSystem.ts
 * Handles save/load with versioning and migration
 */

import { EventBus } from '@/utils/EventBus';
import { SaveData, SAVE_VERSION, SAVE_CONFIG, WorldStateData, CityStats } from '@/types';

export class SaveSystem {
  /**
   * Save game data to localStorage
   */
  static save(worldState: WorldStateData, cityStats: CityStats): boolean {
    try {
      const saveData: SaveData = {
        version: SAVE_VERSION,
        timestamp: Date.now(),
        seed: worldState.seed,
        worldState,
        cityStats,
      };

      localStorage.setItem(SAVE_CONFIG.STORAGE_KEY, JSON.stringify(saveData));
      EventBus.emit('save:completed');
      return true;
    } catch (error) {
      console.error('Failed to save game:', error);
      EventBus.emit('save:failed', error);
      return false;
    }
  }

  /**
   * Load game data from localStorage
   */
  static load(): SaveData | null {
    try {
      const data = localStorage.getItem(SAVE_CONFIG.STORAGE_KEY);
      if (!data) return null;

      const saveData = JSON.parse(data) as SaveData;

      // Migrate if necessary
      const migratedData = this.migrate(saveData);

      return migratedData;
    } catch (error) {
      console.error('Failed to load game:', error);
      return null;
    }
  }

  /**
   * Check if a save exists
   */
  static hasSave(): boolean {
    return localStorage.getItem(SAVE_CONFIG.STORAGE_KEY) !== null;
  }

  /**
   * Delete save data
   */
  static deleteSave(): void {
    localStorage.removeItem(SAVE_CONFIG.STORAGE_KEY);
  }

  /**
   * Export save data as JSON string
   */
  static exportJSON(worldState: WorldStateData, cityStats: CityStats): string {
    const saveData: SaveData = {
      version: SAVE_VERSION,
      timestamp: Date.now(),
      seed: worldState.seed,
      worldState,
      cityStats,
    };
    return JSON.stringify(saveData, null, 2);
  }

  /**
   * Import save data from JSON string
   */
  static importJSON(jsonString: string): SaveData | null {
    try {
      const saveData = JSON.parse(jsonString) as SaveData;

      // Validate basic structure
      if (!saveData.version || !saveData.worldState || !saveData.cityStats) {
        throw new Error('Invalid save data format');
      }

      // Migrate if necessary
      return this.migrate(saveData);
    } catch (error) {
      console.error('Failed to import JSON:', error);
      return null;
    }
  }

  /**
   * Download save as JSON file
   */
  static downloadJSON(worldState: WorldStateData, cityStats: CityStats): void {
    const json = this.exportJSON(worldState, cityStats);
    const blob = new Blob([json], { type: 'application/json' });
    const url = URL.createObjectURL(blob);

    const a = document.createElement('a');
    a.href = url;
    a.download = `pixelopolis_save_${Date.now()}.json`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }

  /**
   * Migrate save data to current version
   */
  static migrate(saveData: SaveData): SaveData {
    let data = { ...saveData };

    // Migration chain - run each migration in sequence
    if (data.version < 1) {
      data = this.migrateToV1(data);
    }

    // Future migrations go here:
    // if (data.version < 2) {
    //   data = this.migrateToV2(data);
    // }

    return data;
  }

  /**
   * Migration to version 1 (no-op, illustrative example)
   */
  private static migrateToV1(saveData: SaveData): SaveData {
    // This is a no-op migration for demonstration
    // In a real scenario, this would transform older data structures
    console.log('Migrating save data to version 1...');

    return {
      ...saveData,
      version: 1,
    };
  }

  /**
   * Example future migration to version 2
   */
  // private static migrateToV2(saveData: SaveData): SaveData {
  //   console.log('Migrating save data to version 2...');
  //
  //   // Example: Add new field with default value
  //   return {
  //     ...saveData,
  //     version: 2,
  //     // newField: defaultValue,
  //   };
  // }
}
