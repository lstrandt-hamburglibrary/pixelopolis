/**
 * SimulationSystem.ts
 * Fixed-step simulation loop at 10 Hz
 */

import { SIMULATION_CONFIG } from '@/types';
import { EventBus } from '@/utils/EventBus';

export class SimulationSystem {
  private isRunning: boolean = true;
  private tickCount: number = 0;
  private accumulator: number = 0;
  private lastTime: number = 0;

  constructor() {
    // Listen for growth toggle events
    EventBus.on('growth:toggle', this.onGrowthToggle.bind(this));
  }

  /**
   * Update simulation with delta time
   * Called from scene update loop
   */
  update(time: number): void {
    if (!this.isRunning) return;

    // Initialize lastTime on first update
    if (this.lastTime === 0) {
      this.lastTime = time;
      return;
    }

    // Calculate delta time in seconds
    const deltaTime = (time - this.lastTime) / 1000;
    this.lastTime = time;

    // Accumulate time
    this.accumulator += deltaTime;

    // Fixed-step update at TICK_INTERVAL
    const tickInterval = SIMULATION_CONFIG.TICK_INTERVAL / 1000; // Convert to seconds
    while (this.accumulator >= tickInterval) {
      this.tick();
      this.accumulator -= tickInterval;
    }
  }

  /**
   * Single simulation tick
   */
  private tick(): void {
    this.tickCount++;

    // Emit tick event with tick count
    EventBus.emit('simulation:tick', this.tickCount);
  }

  /**
   * Get current tick count
   */
  getTickCount(): number {
    return this.tickCount;
  }

  /**
   * Get elapsed time in seconds
   */
  getElapsedTime(): number {
    return this.tickCount * (SIMULATION_CONFIG.TICK_INTERVAL / 1000);
  }

  /**
   * Check if simulation is running
   */
  isSimulationRunning(): boolean {
    return this.isRunning;
  }

  /**
   * Toggle simulation on/off
   */
  toggleRunning(): void {
    this.isRunning = !this.isRunning;
    EventBus.emit('growth:toggled', this.isRunning);
  }

  /**
   * Set simulation running state
   */
  setRunning(running: boolean): void {
    if (this.isRunning !== running) {
      this.isRunning = running;
      EventBus.emit('growth:toggled', this.isRunning);
    }
  }

  /**
   * Handle growth toggle request
   */
  private onGrowthToggle(): void {
    this.toggleRunning();
  }

  /**
   * Reset simulation
   */
  reset(): void {
    this.tickCount = 0;
    this.accumulator = 0;
    this.lastTime = 0;
  }

  /**
   * Clean up
   */
  destroy(): void {
    EventBus.off('growth:toggle', this.onGrowthToggle);
  }
}
