/**
 * UIScene.ts
 * UI overlay scene with HUD
 */

import Phaser from 'phaser';
import { Config } from '@/utils/Config';
import { EventBus } from '@/utils/EventBus';
import { WorldState } from '@/world/WorldState';
import { BrushTool } from '@/tools/BrushTool';
import { CommandQueue } from '@/commands/CommandQueue';
import { PowerSystem } from '@/systems/PowerSystem';
import { BRUSH_NAMES, BrushType, CityStats } from '@/types';

export class UIScene extends Phaser.Scene {
  private fpsText!: Phaser.GameObjects.Text;
  private brushText!: Phaser.GameObjects.Text;
  private statsText!: Phaser.GameObjects.Text;
  private powerText!: Phaser.GameObjects.Text;
  private economyText!: Phaser.GameObjects.Text;

  // References from MainScene
  private worldState?: WorldState;
  private commandQueue?: CommandQueue;
  private powerSystem?: PowerSystem;
  private cityStats?: CityStats;

  constructor() {
    super({ key: Config.SCENES.UI });
  }

  create(): void {
    // Version text (top-left)
    this.add.text(10, 10, `v${Config.VERSION}`, {
      fontSize: '16px',
      color: '#ffffff',
      fontStyle: 'bold',
    });

    // FPS text (below version)
    this.fpsText = this.add.text(10, 30, 'FPS: --', {
      fontSize: '16px',
      color: '#ffffff',
    });

    // Brush info (top-right)
    this.brushText = this.add.text(Config.GAME_WIDTH - 10, 10, 'Brush: Road', {
      fontSize: '16px',
      color: '#ffffff',
      fontStyle: 'bold',
    });
    this.brushText.setOrigin(1, 0);

    // Stats (top-right, below brush)
    this.statsText = this.add.text(Config.GAME_WIDTH - 10, 30, '', {
      fontSize: '14px',
      color: '#ffffff',
    });
    this.statsText.setOrigin(1, 0);

    // Power stats (top-right, below stats)
    this.powerText = this.add.text(Config.GAME_WIDTH - 10, 50, '', {
      fontSize: '14px',
      color: '#f1c40f',
      fontStyle: 'bold',
    });
    this.powerText.setOrigin(1, 0);

    // Economy stats (top-right, below power)
    this.economyText = this.add.text(Config.GAME_WIDTH - 10, 70, '', {
      fontSize: '14px',
      color: '#2ecc71',
    });
    this.economyText.setOrigin(1, 0);

    // Help text (bottom-left)
    this.add.text(10, Config.GAME_HEIGHT - 80, this.getHelpText(), {
      fontSize: '12px',
      color: '#aaaaaa',
    });

    // Listen for events
    EventBus.on('world:loaded', this.onWorldLoaded.bind(this));
    EventBus.on('brush:changed', this.onBrushChanged.bind(this));
    EventBus.on('power:updated', this.onPowerUpdated.bind(this));
    EventBus.on('economy:updated', this.onEconomyUpdated.bind(this));
  }

  /**
   * Handle world loaded event
   */
  private onWorldLoaded(data: {
    worldState: WorldState;
    brushTool: BrushTool;
    commandQueue: CommandQueue;
    powerSystem: PowerSystem;
  }): void {
    this.worldState = data.worldState;
    this.commandQueue = data.commandQueue;
    this.powerSystem = data.powerSystem;
    this.updatePowerDisplay();
  }

  /**
   * Handle brush changed event
   */
  private onBrushChanged(brushType: BrushType): void {
    this.brushText.setText(`Brush: ${BRUSH_NAMES[brushType]}`);
  }

  /**
   * Handle power updated event
   */
  private onPowerUpdated(): void {
    this.updatePowerDisplay();
  }

  /**
   * Handle economy updated event
   */
  private onEconomyUpdated(stats: CityStats): void {
    this.cityStats = stats;
    this.updateEconomyDisplay();
  }

  /**
   * Update power capacity/demand display
   */
  private updatePowerDisplay(): void {
    if (!this.powerSystem) return;

    const capacity = this.powerSystem.getCapacity();
    const demand = this.powerSystem.getDemand();
    this.powerText.setText(`Power - Capacity: ${capacity} / Demand: ${demand}`);
  }

  /**
   * Update economy display
   */
  private updateEconomyDisplay(): void {
    if (!this.cityStats) return;

    const balance = Math.floor(this.cityStats.balance);
    const happiness = (this.cityStats.happiness * 100).toFixed(0);
    const lines = [
      `$ ${balance}`,
      `Pop: ${this.cityStats.population} | Jobs: ${this.cityStats.jobs} | Shoppers: ${this.cityStats.shoppers}`,
      `Happiness: ${happiness}%`,
    ];
    this.economyText.setText(lines.join('\n'));
  }

  /**
   * Get help text
   */
  private getHelpText(): string {
    return [
      'Controls:',
      'Left Click/Drag: Paint | Right Click/Drag: Pan Camera',
      'Mouse Wheel: Zoom | 1-6: Select Brush | P: Power Overlay',
      'Ctrl+Z: Undo | Ctrl+Y: Redo',
    ].join('\n');
  }

  update(): void {
    // Update FPS display
    const fps = Math.round(this.game.loop.actualFps);
    this.fpsText.setText(`FPS: ${fps}`);

    // Update stats if world state is available
    if (this.worldState && this.commandQueue) {
      const undoCount = this.commandQueue.getHistorySize();
      const statsLines = [`History: ${undoCount} actions`];
      this.statsText.setText(statsLines.join('\n'));
    }

    // Update power display
    this.updatePowerDisplay();
  }

  /**
   * Clean up on shutdown
   */
  shutdown(): void {
    EventBus.off('world:loaded', this.onWorldLoaded);
    EventBus.off('brush:changed', this.onBrushChanged);
    EventBus.off('power:updated', this.onPowerUpdated);
    EventBus.off('economy:updated', this.onEconomyUpdated);
  }
}
