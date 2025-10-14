/**
 * GrowthToggleUI.ts
 * UI button for toggling growth simulation on/off
 */

import Phaser from 'phaser';
import { EventBus } from '@/utils/EventBus';

export class GrowthToggleUI {
  private scene: Phaser.Scene;
  private button!: Phaser.GameObjects.Rectangle;
  private buttonText!: Phaser.GameObjects.Text;
  private isActive: boolean = true; // Growth starts ON

  private readonly BUTTON_WIDTH = 120;
  private readonly BUTTON_HEIGHT = 40;
  private readonly BUTTON_X = 270; // Position after power overlay button
  private readonly BUTTON_Y = 10;

  constructor(scene: Phaser.Scene) {
    this.scene = scene;
    this.createButton();

    // Listen for growth toggle events
    EventBus.on('growth:toggled', this.onToggled.bind(this));
  }

  /**
   * Create the growth toggle button
   */
  private createButton(): void {
    // Background
    this.button = this.scene.add.rectangle(
      this.BUTTON_X,
      this.BUTTON_Y,
      this.BUTTON_WIDTH,
      this.BUTTON_HEIGHT,
      0x2ecc71, // Green (ON)
      1
    );
    this.button.setOrigin(0, 0);
    this.button.setInteractive({ useHandCursor: true });
    this.button.setScrollFactor(0);
    this.button.setDepth(100);

    // Text
    this.buttonText = this.scene.add.text(
      this.BUTTON_X + this.BUTTON_WIDTH / 2,
      this.BUTTON_Y + this.BUTTON_HEIGHT / 2,
      'Growth ON',
      {
        fontSize: '14px',
        color: '#ffffff',
        fontStyle: 'bold',
      }
    );
    this.buttonText.setOrigin(0.5);
    this.buttonText.setScrollFactor(0);
    this.buttonText.setDepth(101);

    // Click handler
    this.button.on('pointerdown', (_pointer: Phaser.Input.Pointer, _localX: number, _localY: number, event: Phaser.Types.Input.EventData) => {
      EventBus.emit('growth:toggle');
      event.stopPropagation();
    });

    // Hover effects
    this.button.on('pointerover', () => {
      this.button.setAlpha(0.8);
    });

    this.button.on('pointerout', () => {
      this.button.setAlpha(1);
    });

    // Initial visual
    this.updateVisual();
  }

  /**
   * Handle toggle event
   */
  private onToggled(isActive: boolean): void {
    this.isActive = isActive;
    this.updateVisual();
  }

  /**
   * Update button visual based on active state
   */
  private updateVisual(): void {
    if (this.isActive) {
      this.button.setFillStyle(0x2ecc71); // Green
      this.button.setStrokeStyle(3, 0xffffff);
      this.buttonText.setText('Growth ON');
    } else {
      this.button.setFillStyle(0xe74c3c); // Red
      this.button.setStrokeStyle(0);
      this.buttonText.setText('Growth OFF');
    }
  }

  /**
   * Destroy the UI
   */
  destroy(): void {
    EventBus.off('growth:toggled', this.onToggled);
    this.button.destroy();
    this.buttonText.destroy();
  }
}
