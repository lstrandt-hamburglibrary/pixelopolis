/**
 * RNG.ts
 * Deterministic random number generator using LCG (Linear Congruential Generator)
 */

export class RNG {
  private seed: number;
  private current: number;

  constructor(seed: number = Date.now()) {
    this.seed = seed;
    this.current = seed;
  }

  /**
   * Get the next random number (0-1)
   */
  next(): number {
    // LCG parameters (from Numerical Recipes)
    const a = 1664525;
    const c = 1013904223;
    const m = 2 ** 32;

    this.current = (a * this.current + c) % m;
    return this.current / m;
  }

  /**
   * Get random integer between min and max (inclusive)
   */
  nextInt(min: number, max: number): number {
    return Math.floor(this.next() * (max - min + 1)) + min;
  }

  /**
   * Get random float between min and max
   */
  nextFloat(min: number, max: number): number {
    return this.next() * (max - min) + min;
  }

  /**
   * Reset to initial seed
   */
  reset(): void {
    this.current = this.seed;
  }

  /**
   * Set a new seed
   */
  setSeed(seed: number): void {
    this.seed = seed;
    this.current = seed;
  }

  /**
   * Get current seed
   */
  getSeed(): number {
    return this.seed;
  }
}

// Singleton instance
export const rng = new RNG();
