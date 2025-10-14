/**
 * TileGridRenderer.ts
 * Efficient chunked tile rendering system
 */

import Phaser from 'phaser';
import { WorldState } from '@/world/WorldState';
import { TILE_COLORS, TilePosition, POWER_CONFIG, ISOMETRIC_CONFIG } from '@/types';
import { PowerSystem } from '@/systems/PowerSystem';

export class TileGridRenderer {
  private scene: Phaser.Scene;
  private worldState: WorldState;
  private powerSystem?: PowerSystem;
  private container: Phaser.GameObjects.Container;
  private tileGraphics: Map<string, Phaser.GameObjects.Graphics>;
  private gridGraphics: Phaser.GameObjects.Graphics;
  private highlightGraphics: Phaser.GameObjects.Graphics;
  private powerOverlayGraphics: Phaser.GameObjects.Graphics;
  private chunkSize: number = 8; // 8×8 tiles per chunk
  private powerOverlayVisible: boolean = false;

  constructor(scene: Phaser.Scene, worldState: WorldState) {
    this.scene = scene;
    this.worldState = worldState;

    // Create container for all tile graphics
    this.container = scene.add.container(0, 0);
    this.container.setDepth(0);

    // Map to store graphics objects for each chunk
    this.tileGraphics = new Map();

    // Create grid overlay
    this.gridGraphics = scene.add.graphics();
    this.gridGraphics.setDepth(1);

    // Create highlight graphics
    this.highlightGraphics = scene.add.graphics();
    this.highlightGraphics.setDepth(2);

    // Create power overlay graphics
    this.powerOverlayGraphics = scene.add.graphics();
    this.powerOverlayGraphics.setDepth(3);
    this.powerOverlayGraphics.setVisible(false);

    // Initial render
    this.renderAll();
    this.renderGrid();
  }

  /**
   * Set power system reference
   */
  setPowerSystem(powerSystem: PowerSystem): void {
    this.powerSystem = powerSystem;
  }


  /**
   * Render all chunks
   */
  renderAll(): void {
    const width = this.worldState.getWidth();
    const height = this.worldState.getHeight();
    const chunksX = Math.ceil(width / this.chunkSize);
    const chunksY = Math.ceil(height / this.chunkSize);

    for (let chunkY = 0; chunkY < chunksY; chunkY++) {
      for (let chunkX = 0; chunkX < chunksX; chunkX++) {
        this.renderChunk(chunkX, chunkY);
      }
    }
  }

  /**
   * Render a specific chunk (ISOMETRIC)
   */
  private renderChunk(chunkX: number, chunkY: number): void {
    const key = `${chunkX},${chunkY}`;

    // Remove existing graphics for this chunk
    const existing = this.tileGraphics.get(key);
    if (existing) {
      existing.destroy();
    }

    // Create new graphics for this chunk
    const graphics = this.scene.add.graphics();
    graphics.setDepth(0);

    // Render tiles in this chunk
    const startX = chunkX * this.chunkSize;
    const startY = chunkY * this.chunkSize;
    const endX = Math.min(startX + this.chunkSize, this.worldState.getWidth());
    const endY = Math.min(startY + this.chunkSize, this.worldState.getHeight());

    // Render in back-to-front order for proper layering
    for (let y = startY; y < endY; y++) {
      for (let x = startX; x < endX; x++) {
        const tile = this.worldState.getTile(x, y);
        if (tile) {
          this.renderIsometricTile(graphics, x, y, tile);
        }
      }
    }

    this.tileGraphics.set(key, graphics);
    this.container.add(graphics);
  }

  /**
   * Render a single isometric tile
   */
  private renderIsometricTile(
    graphics: Phaser.GameObjects.Graphics,
    tileX: number,
    tileY: number,
    tile: import('@/types').Tile
  ): void {
    const worldPos = this.worldState.tileToWorld(tileX, tileY);
    const tileW = ISOMETRIC_CONFIG.TILE_WIDTH;
    const tileH = ISOMETRIC_CONFIG.TILE_HEIGHT;

    // Diamond points
    const top = { x: worldPos.x, y: worldPos.y - tileH / 2 };
    const right = { x: worldPos.x + tileW / 2, y: worldPos.y };
    const bottom = { x: worldPos.x, y: worldPos.y + tileH / 2 };
    const left = { x: worldPos.x - tileW / 2, y: worldPos.y };

    // Draw diamond-shaped tile base
    const color = TILE_COLORS[tile.type];
    graphics.fillStyle(color, 1);
    graphics.beginPath();
    graphics.moveTo(top.x, top.y);
    graphics.lineTo(right.x, right.y);
    graphics.lineTo(bottom.x, bottom.y);
    graphics.lineTo(left.x, left.y);
    graphics.closePath();
    graphics.fillPath();

    // Add grass texture pattern for empty tiles
    if (tile.type === 0) { // EMPTY tile
      graphics.fillStyle(0x6fb040, 1); // Slightly darker green
      // Add some random-looking grass patches
      const seedX = tileX * 7 + tileY * 13;
      const seedY = tileX * 11 + tileY * 17;

      for (let i = 0; i < 3; i++) {
        const offsetX = ((seedX + i * 23) % 11) - 5;
        const offsetY = ((seedY + i * 19) % 7) - 3;
        graphics.fillRect(worldPos.x + offsetX, worldPos.y + offsetY, 2, 1);
      }
    }

    // Add subtle shading to edges for depth
    graphics.lineStyle(1, 0x000000, 0.15);
    graphics.strokePath();

    // Render building if it exists
    if (tile.building && tile.building.level > 0) {
      this.renderIsometricBuilding(graphics, worldPos.x, worldPos.y, tile.building.level, tile.type);
    }
    // Add trees to some empty tiles (deterministic based on position)
    else if (tile.type === 0) {
      const treeSeed = (tileX * 31 + tileY * 67) % 100;
      if (treeSeed < 15) { // 15% chance for a tree
        this.renderTree(graphics, worldPos.x, worldPos.y, treeSeed);
      }
    }
  }

  /**
   * Render a simple tree
   */
  private renderTree(
    graphics: Phaser.GameObjects.Graphics,
    centerX: number,
    centerY: number,
    seed: number
  ): void {
    const treeHeight = 8 + (seed % 4);
    const crownRadius = 4 + (seed % 3);

    // Tree trunk
    graphics.fillStyle(0x8b4513, 1); // Brown
    graphics.fillRect(centerX - 1, centerY - 2, 2, treeHeight);

    // Tree crown (circular)
    graphics.fillStyle(0x228b22, 1); // Forest green
    graphics.beginPath();
    graphics.arc(centerX, centerY - treeHeight, crownRadius, 0, Math.PI * 2);
    graphics.fillPath();

    // Highlight on crown
    graphics.fillStyle(0x32cd32, 0.6); // Lighter green
    graphics.beginPath();
    graphics.arc(centerX - 1, centerY - treeHeight - 1, crownRadius / 2, 0, Math.PI * 2);
    graphics.fillPath();
  }

  /**
   * Render isometric building with elevation
   */
  private renderIsometricBuilding(
    graphics: Phaser.GameObjects.Graphics,
    centerX: number,
    centerY: number,
    level: number,
    tileType: import('@/types').TileType
  ): void {
    const buildingHeight = level * ISOMETRIC_CONFIG.BUILDING_HEIGHT_PER_LEVEL;
    const buildingWidth = 20; // Width in isometric space
    const buildingDepth = 10; // Depth in isometric space
    const foundationHeight = 4; // Foundation/base height

    // Position foundation to sit directly on tile center
    const surfaceY = centerY; // Center of tile

    // Foundation corners (wider at base for convex look)
    const baseWidth = buildingWidth + 4;
    const baseDepth = buildingDepth + 2;
    const baseFront = { x: centerX, y: surfaceY + foundationHeight };
    const baseLeft = { x: centerX - baseWidth / 2, y: surfaceY + baseDepth / 2 + foundationHeight };
    const baseRight = { x: centerX + baseWidth / 2, y: surfaceY + baseDepth / 2 + foundationHeight };

    // Building corners at foundation top
    const groundFront = { x: centerX, y: surfaceY };
    const groundLeft = { x: centerX - buildingWidth / 2, y: surfaceY + buildingDepth / 2 };
    const groundRight = { x: centerX + buildingWidth / 2, y: surfaceY + buildingDepth / 2 };

    // Building corners at roof level
    const roofFront = { x: centerX, y: surfaceY - buildingHeight };
    const roofLeft = { x: centerX - buildingWidth / 2, y: surfaceY + buildingDepth / 2 - buildingHeight };
    const roofRight = { x: centerX + buildingWidth / 2, y: surfaceY + buildingDepth / 2 - buildingHeight };
    const roofBack = { x: centerX, y: surfaceY + buildingDepth - buildingHeight };

    // Draw FOUNDATION LEFT FACE (darkest)
    graphics.fillStyle(0x333333, 1);
    graphics.beginPath();
    graphics.moveTo(baseFront.x, baseFront.y);
    graphics.lineTo(baseLeft.x, baseLeft.y);
    graphics.lineTo(groundLeft.x, groundLeft.y);
    graphics.lineTo(groundFront.x, groundFront.y);
    graphics.closePath();
    graphics.fillPath();

    // Draw FOUNDATION RIGHT FACE (dark)
    graphics.fillStyle(0x555555, 1);
    graphics.beginPath();
    graphics.moveTo(baseFront.x, baseFront.y);
    graphics.lineTo(baseRight.x, baseRight.y);
    graphics.lineTo(groundRight.x, groundRight.y);
    graphics.lineTo(groundFront.x, groundFront.y);
    graphics.closePath();
    graphics.fillPath();

    // Draw LEFT FACE (darker)
    graphics.fillStyle(0x444444, 1);
    graphics.beginPath();
    graphics.moveTo(groundFront.x, groundFront.y);
    graphics.lineTo(groundLeft.x, groundLeft.y);
    graphics.lineTo(roofLeft.x, roofLeft.y);
    graphics.lineTo(roofFront.x, roofFront.y);
    graphics.closePath();
    graphics.fillPath();

    // Draw RIGHT FACE (lighter)
    graphics.fillStyle(0x666666, 1);
    graphics.beginPath();
    graphics.moveTo(groundFront.x, groundFront.y);
    graphics.lineTo(groundRight.x, groundRight.y);
    graphics.lineTo(roofRight.x, roofRight.y);
    graphics.lineTo(roofFront.x, roofFront.y);
    graphics.closePath();
    graphics.fillPath();

    // Draw TOP FACE (colored by zone type)
    const topColor = TILE_COLORS[tileType];
    graphics.fillStyle(topColor, 1);
    graphics.beginPath();
    graphics.moveTo(roofFront.x, roofFront.y);
    graphics.lineTo(roofLeft.x, roofLeft.y);
    graphics.lineTo(roofBack.x, roofBack.y);
    graphics.lineTo(roofRight.x, roofRight.y);
    graphics.closePath();
    graphics.fillPath();

    // Add edge outlines for depth
    graphics.lineStyle(1, 0x000000, 0.3);
    graphics.strokePath();

    // Draw windows on LEFT FACE (one window per floor)
    const windowSize = 3;
    graphics.fillStyle(0xffee66, 1); // Brighter yellow

    for (let lvl = 0; lvl < level; lvl++) {
      const floorY = surfaceY - lvl * ISOMETRIC_CONFIG.BUILDING_HEIGHT_PER_LEVEL - 8;
      const windowX = centerX - buildingWidth / 3;
      graphics.fillRect(windowX, floorY, windowSize, windowSize);
      // Add window frame
      graphics.lineStyle(1, 0x888888, 0.5);
      graphics.strokeRect(windowX, floorY, windowSize, windowSize);
    }

    // Draw windows on RIGHT FACE (one window per floor)
    for (let lvl = 0; lvl < level; lvl++) {
      const floorY = surfaceY - lvl * ISOMETRIC_CONFIG.BUILDING_HEIGHT_PER_LEVEL - 8;
      const windowX = centerX + buildingWidth / 3;
      graphics.fillRect(windowX, floorY, windowSize, windowSize);
      // Add window frame
      graphics.lineStyle(1, 0x888888, 0.5);
      graphics.strokeRect(windowX, floorY, windowSize, windowSize);
    }

    // Add a door on the foundation (level 1+ only)
    if (level >= 1) {
      graphics.fillStyle(0x8b4513, 1); // Brown door
      graphics.fillRect(centerX - 2, surfaceY - 4, 4, 6);
    }
  }

  /**
   * Update a single tile (re-renders the chunk it belongs to)
   */
  updateTile(tileX: number, tileY: number): void {
    const chunkX = Math.floor(tileX / this.chunkSize);
    const chunkY = Math.floor(tileY / this.chunkSize);
    this.renderChunk(chunkX, chunkY);
  }

  /**
   * Update multiple tiles efficiently (batch update)
   */
  updateTiles(tiles: { x: number; y: number }[]): void {
    // Get unique chunks
    const chunksToUpdate = new Set<string>();
    for (const tile of tiles) {
      const chunkX = Math.floor(tile.x / this.chunkSize);
      const chunkY = Math.floor(tile.y / this.chunkSize);
      chunksToUpdate.add(`${chunkX},${chunkY}`);
    }

    // Re-render each affected chunk
    for (const chunkKey of chunksToUpdate) {
      const [chunkX, chunkY] = chunkKey.split(',').map(Number);
      this.renderChunk(chunkX, chunkY);
    }
  }

  /**
   * Render isometric grid overlay
   */
  private renderGrid(): void {
    this.gridGraphics.clear();

    const width = this.worldState.getWidth();
    const height = this.worldState.getHeight();

    // Draw subtle grid lines
    this.gridGraphics.lineStyle(1, 0x333333, 0.3);

    // Draw vertical grid lines (constant X)
    for (let x = 0; x <= width; x++) {
      const start = this.worldState.tileToWorld(x, 0);
      const end = this.worldState.tileToWorld(x, height);
      this.gridGraphics.lineBetween(start.x, start.y, end.x, end.y);
    }

    // Draw horizontal grid lines (constant Y)
    for (let y = 0; y <= height; y++) {
      const start = this.worldState.tileToWorld(0, y);
      const end = this.worldState.tileToWorld(width, y);
      this.gridGraphics.lineBetween(start.x, start.y, end.x, end.y);
    }
  }

  /**
   * Highlight a tile under cursor (ISOMETRIC)
   */
  highlightTile(tilePos: TilePosition | null): void {
    this.highlightGraphics.clear();

    if (!tilePos || !this.worldState.isValidPosition(tilePos.x, tilePos.y)) {
      return;
    }

    const worldPos = this.worldState.tileToWorld(tilePos.x, tilePos.y);
    const tileW = ISOMETRIC_CONFIG.TILE_WIDTH;
    const tileH = ISOMETRIC_CONFIG.TILE_HEIGHT;

    // Draw highlight diamond
    this.highlightGraphics.lineStyle(3, 0xffffff, 0.9);

    const top = { x: worldPos.x, y: worldPos.y - tileH / 2 };
    const right = { x: worldPos.x + tileW / 2, y: worldPos.y };
    const bottom = { x: worldPos.x, y: worldPos.y + tileH / 2 };
    const left = { x: worldPos.x - tileW / 2, y: worldPos.y };

    this.highlightGraphics.beginPath();
    this.highlightGraphics.moveTo(top.x, top.y);
    this.highlightGraphics.lineTo(right.x, right.y);
    this.highlightGraphics.lineTo(bottom.x, bottom.y);
    this.highlightGraphics.lineTo(left.x, left.y);
    this.highlightGraphics.closePath();
    this.highlightGraphics.strokePath();
  }

  /**
   * Clear all rendering
   */
  destroy(): void {
    this.container.destroy();
    this.gridGraphics.destroy();
    this.highlightGraphics.destroy();
    this.tileGraphics.clear();
  }

  /**
   * Get the container for camera attachment
   */
  getContainer(): Phaser.GameObjects.Container {
    return this.container;
  }

  /**
   * Set visibility of grid overlay
   */
  setGridVisible(visible: boolean): void {
    this.gridGraphics.setVisible(visible);
  }

  /**
   * Toggle power overlay
   */
  togglePowerOverlay(): void {
    this.powerOverlayVisible = !this.powerOverlayVisible;
    if (this.powerOverlayVisible) {
      this.renderPowerOverlay();
    } else {
      this.powerOverlayGraphics.setVisible(false);
    }
  }

  /**
   * Set power overlay visibility
   */
  setPowerOverlayVisible(visible: boolean): void {
    this.powerOverlayVisible = visible;
    if (visible) {
      this.renderPowerOverlay();
    } else {
      this.powerOverlayGraphics.setVisible(false);
    }
  }

  /**
   * Get power overlay visibility
   */
  getPowerOverlayVisible(): boolean {
    return this.powerOverlayVisible;
  }

  /**
   * Render power overlay (ISOMETRIC)
   */
  renderPowerOverlay(): void {
    if (!this.powerSystem) return;

    this.powerOverlayGraphics.clear();
    this.powerOverlayGraphics.setVisible(true);

    const width = this.worldState.getWidth();
    const height = this.worldState.getHeight();
    const tileW = ISOMETRIC_CONFIG.TILE_WIDTH;
    const tileH = ISOMETRIC_CONFIG.TILE_HEIGHT;

    // Render power overlay for all tiles
    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        const tile = this.worldState.getTile(x, y);
        if (!tile) continue;

        // Check if tile needs power
        if (this.powerSystem.needsPower(tile.type)) {
          const isPowered = this.powerSystem.isPowered(x, y);
          const color = isPowered ? POWER_CONFIG.POWERED_TINT : POWER_CONFIG.UNPOWERED_TINT;

          const worldPos = this.worldState.tileToWorld(x, y);
          this.powerOverlayGraphics.fillStyle(color, POWER_CONFIG.OVERLAY_ALPHA);

          // Draw diamond overlay
          const top = { x: worldPos.x, y: worldPos.y - tileH / 2 };
          const right = { x: worldPos.x + tileW / 2, y: worldPos.y };
          const bottom = { x: worldPos.x, y: worldPos.y + tileH / 2 };
          const left = { x: worldPos.x - tileW / 2, y: worldPos.y };

          this.powerOverlayGraphics.beginPath();
          this.powerOverlayGraphics.moveTo(top.x, top.y);
          this.powerOverlayGraphics.lineTo(right.x, right.y);
          this.powerOverlayGraphics.lineTo(bottom.x, bottom.y);
          this.powerOverlayGraphics.lineTo(left.x, left.y);
          this.powerOverlayGraphics.closePath();
          this.powerOverlayGraphics.fillPath();
        }
      }
    }
  }

  /**
   * Update power overlay (called when power grid changes)
   */
  updatePowerOverlay(): void {
    if (this.powerOverlayVisible) {
      this.renderPowerOverlay();
    }
  }
}
