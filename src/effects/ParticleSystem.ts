/**
 * ParticleSystem.ts
 * Simple particle effects for building spawn/upgrade
 */

import Phaser from 'phaser';
import { WorldState } from '@/world/WorldState';
import { EventBus } from '@/utils/EventBus';
import { TileType } from '@/types';

interface Particle {
  x: number;
  y: number;
  vx: number;
  vy: number;
  life: number;
  maxLife: number;
  color: number;
}

export class ParticleSystem {
  private worldState: WorldState;
  private graphics: Phaser.GameObjects.Graphics;
  private particles: Particle[] = [];

  constructor(scene: Phaser.Scene, worldState: WorldState) {
    this.worldState = worldState;

    // Create graphics for particles
    this.graphics = scene.add.graphics();
    this.graphics.setDepth(50);

    // Listen for building events
    EventBus.on('building:spawned', this.onBuildingSpawned.bind(this));
    EventBus.on('building:upgraded', this.onBuildingUpgraded.bind(this));
  }

  /**
   * Handle building spawned event
   */
  private onBuildingSpawned(data: { x: number; y: number; type: TileType }): void {
    this.createPoof(data.x, data.y, data.type);
  }

  /**
   * Handle building upgraded event
   */
  private onBuildingUpgraded(data: { x: number; y: number; type: TileType; level: number }): void {
    this.createPoof(data.x, data.y, data.type);
  }

  /**
   * Create a "poof" particle effect
   */
  private createPoof(tileX: number, tileY: number, type: TileType): void {
    const worldPos = this.worldState.tileToWorld(tileX, tileY);
    const tileSize = this.worldState.getTileSize();
    const centerX = worldPos.x + tileSize / 2;
    const centerY = worldPos.y + tileSize / 2;

    // Choose color based on tile type
    const color = this.getColorForType(type);

    // Create 8 particles in a burst
    const particleCount = 8;
    for (let i = 0; i < particleCount; i++) {
      const angle = (i / particleCount) * Math.PI * 2;
      const speed = 20 + Math.random() * 20;

      this.particles.push({
        x: centerX,
        y: centerY,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        life: 0.5, // 0.5 seconds
        maxLife: 0.5,
        color,
      });
    }
  }

  /**
   * Get particle color for tile type
   */
  private getColorForType(type: TileType): number {
    switch (type) {
      case TileType.RES:
        return 0x2ecc71; // Green
      case TileType.COM:
        return 0x3498db; // Blue
      case TileType.IND:
        return 0xf39c12; // Orange
      default:
        return 0xffffff; // White
    }
  }

  /**
   * Update particles
   */
  update(deltaTime: number): void {
    // Update particle positions and life
    for (let i = this.particles.length - 1; i >= 0; i--) {
      const p = this.particles[i];

      p.x += p.vx * deltaTime;
      p.y += p.vy * deltaTime;
      p.life -= deltaTime;

      // Remove dead particles
      if (p.life <= 0) {
        this.particles.splice(i, 1);
      }
    }

    // Render particles
    this.render();
  }

  /**
   * Render particles
   */
  private render(): void {
    this.graphics.clear();

    for (const p of this.particles) {
      const alpha = p.life / p.maxLife;
      const size = 2 + alpha * 2;

      this.graphics.fillStyle(p.color, alpha);
      this.graphics.fillCircle(p.x, p.y, size);
    }
  }

  /**
   * Clean up
   */
  destroy(): void {
    EventBus.off('building:spawned', this.onBuildingSpawned);
    EventBus.off('building:upgraded', this.onBuildingUpgraded);
    this.graphics.destroy();
    this.particles = [];
  }
}
