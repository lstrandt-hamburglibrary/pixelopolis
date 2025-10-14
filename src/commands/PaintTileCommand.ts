/**
 * PaintTileCommand.ts
 * Command for painting tiles (supports undo/redo)
 */

import { Command, Tile, TilePosition } from '@/types';
import { WorldState } from '@/world/WorldState';

export class PaintTileCommand implements Command {
  readonly name: string = 'PaintTile';

  private worldState: WorldState;
  private position: TilePosition;
  private oldTile: Tile;
  private newTile: Tile;

  constructor(worldState: WorldState, position: TilePosition, oldTile: Tile, newTile: Tile) {
    this.worldState = worldState;
    this.position = position;
    this.oldTile = { ...oldTile };
    this.newTile = { ...newTile };
  }

  execute(): void {
    this.worldState.setTile(this.position.x, this.position.y, this.newTile);
  }

  undo(): void {
    this.worldState.setTile(this.position.x, this.position.y, this.oldTile);
  }
}

/**
 * Batch paint command for painting multiple tiles at once
 */
export class BatchPaintCommand implements Command {
  readonly name: string = 'BatchPaint';

  private commands: PaintTileCommand[];

  constructor(commands: PaintTileCommand[]) {
    this.commands = commands;
  }

  execute(): void {
    for (const cmd of this.commands) {
      cmd.execute();
    }
  }

  undo(): void {
    // Undo in reverse order
    for (let i = this.commands.length - 1; i >= 0; i--) {
      this.commands[i].undo();
    }
  }

  /**
   * Get number of tiles in batch
   */
  getCount(): number {
    return this.commands.length;
  }
}
