/**
 * BrushTool.ts
 * Handles tile painting with drag support
 */

import { BrushType, BrushConfig, TilePosition, BRUSH_TO_TILE } from '@/types';
import { WorldState } from '@/world/WorldState';
import { CommandQueue } from '@/commands/CommandQueue';
import { PaintTileCommand, BatchPaintCommand } from '@/commands/PaintTileCommand';

export class BrushTool {
  private worldState: WorldState;
  private commandQueue: CommandQueue;
  private config: BrushConfig;

  // Painting state
  private isPainting: boolean = false;
  private paintedTiles: Set<string> = new Set(); // Tracks tiles painted in current stroke
  private currentBatch: PaintTileCommand[] = [];

  constructor(
    worldState: WorldState,
    commandQueue: CommandQueue,
    initialBrush: BrushType = BrushType.ROAD
  ) {
    this.worldState = worldState;
    this.commandQueue = commandQueue;
    this.config = {
      type: initialBrush,
      size: 1,
    };
  }

  /**
   * Set brush type
   */
  setBrushType(type: BrushType): void {
    this.config.type = type;
  }

  /**
   * Get current brush type
   */
  getBrushType(): BrushType {
    return this.config.type;
  }

  /**
   * Get current brush config
   */
  getConfig(): BrushConfig {
    return { ...this.config };
  }

  /**
   * Start painting
   */
  startPaint(): void {
    this.isPainting = true;
    this.paintedTiles.clear();
    this.currentBatch = [];
  }

  /**
   * Paint at tile position
   */
  paint(tilePos: TilePosition): boolean {
    if (!this.isPainting) return false;
    if (!this.worldState.isValidPosition(tilePos.x, tilePos.y)) return false;

    // Check if we've already painted this tile in current stroke
    const tileKey = `${tilePos.x},${tilePos.y}`;
    if (this.paintedTiles.has(tileKey)) return false;

    // Get the tile type to paint
    const newTileType = BRUSH_TO_TILE[this.config.type];
    if (newTileType === null) return false;

    // Get current tile
    const oldTile = this.worldState.getTile(tilePos.x, tilePos.y);
    if (!oldTile) return false;

    // Don't paint if it's already the same type
    if (oldTile.type === newTileType) return false;

    // Create paint command
    const newTile = { ...oldTile, type: newTileType };
    const command = new PaintTileCommand(this.worldState, tilePos, oldTile, newTile);

    // Add to current batch
    this.currentBatch.push(command);

    // Execute immediately (for visual feedback)
    command.execute();

    // Mark as painted
    this.paintedTiles.add(tileKey);

    return true;
  }

  /**
   * Stop painting and commit batch command
   */
  stopPaint(): void {
    if (!this.isPainting) return;

    this.isPainting = false;

    // If we painted any tiles, create a batch command
    if (this.currentBatch.length > 0) {
      // We already executed the commands, so we need to undo them first
      // Then add the batch command to history
      for (let i = this.currentBatch.length - 1; i >= 0; i--) {
        this.currentBatch[i].undo();
      }

      // Now execute the batch command through the command queue
      const batchCommand = new BatchPaintCommand(this.currentBatch);
      this.commandQueue.execute(batchCommand);
    }

    this.currentBatch = [];
    this.paintedTiles.clear();
  }

  /**
   * Check if currently painting
   */
  getIsPainting(): boolean {
    return this.isPainting;
  }


  /**
   * Cancel current paint operation
   */
  cancel(): void {
    // Undo all changes in current batch
    for (let i = this.currentBatch.length - 1; i >= 0; i--) {
      this.currentBatch[i].undo();
    }

    this.isPainting = false;
    this.currentBatch = [];
    this.paintedTiles.clear();
  }
}
