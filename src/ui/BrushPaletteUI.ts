/**
 * BrushPaletteUI.ts
 * UI component for brush selection palette
 */

import Phaser from 'phaser';
import { BrushType, BRUSH_NAMES, BRUSH_COLORS } from '@/types';
import { EventBus } from '@/utils/EventBus';

interface BrushButton {
  background: Phaser.GameObjects.Rectangle;
  text: Phaser.GameObjects.Text;
  type: BrushType;
}

export class BrushPaletteUI {
  private scene: Phaser.Scene;
  private buttons: Map<BrushType, BrushButton> = new Map();
  private selectedBrush: BrushType;

  private readonly BUTTON_WIDTH = 100;
  private readonly BUTTON_HEIGHT = 40;
  private readonly BUTTON_SPACING = 10;
  private readonly START_X = 10;
  private readonly START_Y = 60;

  constructor(scene: Phaser.Scene, initialBrush: BrushType = BrushType.ROAD) {
    this.scene = scene;
    this.selectedBrush = initialBrush;

    this.createPalette();
  }

  /**
   * Create the brush palette UI
   */
  private createPalette(): void {
    const brushes = [
      BrushType.ROAD,
      BrushType.RES,
      BrushType.COM,
      BrushType.IND,
      BrushType.POWER_PLANT,
      BrushType.ERASER,
    ];

    brushes.forEach((brushType, index) => {
      this.createButton(brushType, index);
    });

    // Update selection visual
    this.updateSelection();
  }

  /**
   * Create a single brush button
   */
  private createButton(brushType: BrushType, index: number): void {
    const x = this.START_X;
    const y = this.START_Y + index * (this.BUTTON_HEIGHT + this.BUTTON_SPACING);

    // Background
    const background = this.scene.add.rectangle(
      x,
      y,
      this.BUTTON_WIDTH,
      this.BUTTON_HEIGHT,
      BRUSH_COLORS[brushType],
      1
    );
    background.setOrigin(0, 0);
    background.setInteractive({ useHandCursor: true });
    background.setScrollFactor(0);
    background.setDepth(100);

    // Text
    const text = this.scene.add.text(
      x + this.BUTTON_WIDTH / 2,
      y + this.BUTTON_HEIGHT / 2,
      BRUSH_NAMES[brushType],
      {
        fontSize: '14px',
        color: '#ffffff',
        fontStyle: 'bold',
      }
    );
    text.setOrigin(0.5);
    text.setScrollFactor(0);
    text.setDepth(101);

    // Store button
    const button: BrushButton = {
      background,
      text,
      type: brushType,
    };
    this.buttons.set(brushType, button);

    // Click handler
    background.on('pointerdown', (_pointer: Phaser.Input.Pointer, _localX: number, _localY: number, event: Phaser.Types.Input.EventData) => {
      this.selectBrush(brushType);
      event.stopPropagation();
    });

    // Hover effects
    background.on('pointerover', () => {
      if (brushType !== this.selectedBrush) {
        background.setAlpha(0.8);
      }
    });

    background.on('pointerout', () => {
      background.setAlpha(1);
    });
  }

  /**
   * Select a brush
   */
  selectBrush(brushType: BrushType): void {
    this.selectedBrush = brushType;
    this.updateSelection();

    // Emit event
    EventBus.emit('brush:selected', brushType);
  }

  /**
   * Update visual selection state
   */
  private updateSelection(): void {
    this.buttons.forEach((button, type) => {
      if (type === this.selectedBrush) {
        // Selected: add border
        button.background.setStrokeStyle(4, 0xffffff);
      } else {
        // Not selected: no border
        button.background.setStrokeStyle(0);
      }
    });
  }

  /**
   * Get currently selected brush
   */
  getSelectedBrush(): BrushType {
    return this.selectedBrush;
  }

  /**
   * Set visibility
   */
  setVisible(visible: boolean): void {
    this.buttons.forEach((button) => {
      button.background.setVisible(visible);
      button.text.setVisible(visible);
    });
  }

  /**
   * Destroy the palette
   */
  destroy(): void {
    this.buttons.forEach((button) => {
      button.background.destroy();
      button.text.destroy();
    });
    this.buttons.clear();
  }
}
