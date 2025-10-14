/**
 * SaveIndicatorUI.ts
 * Shows "Saved ✓" indicator that fades out
 */

import Phaser from 'phaser';
import { EventBus } from '@/utils/EventBus';
import { SAVE_CONFIG } from '@/types';

export class SaveIndicatorUI {
  private scene: Phaser.Scene;
  private container: Phaser.GameObjects.Container;
  private text: Phaser.GameObjects.Text;
  private background: Phaser.GameObjects.Rectangle;
  private fadeTimer?: Phaser.Time.TimerEvent;

  constructor(scene: Phaser.Scene) {
    this.scene = scene;

    // Create container (top-right corner)
    this.container = scene.add.container(0, 0);
    this.container.setDepth(100);
    this.container.setScrollFactor(0);

    // Background
    this.background = scene.add.rectangle(0, 0, 120, 40, 0x000000, 0.7);
    this.background.setOrigin(0, 0);

    // Text
    this.text = scene.add.text(60, 20, 'Saved ✓', {
      fontSize: '16px',
      color: '#00ff00',
      fontStyle: 'bold',
    });
    this.text.setOrigin(0.5, 0.5);

    this.container.add([this.background, this.text]);

    // Position in top-right corner
    const camera = scene.cameras.main;
    this.container.setPosition(camera.width - 130, 10);

    // Start hidden
    this.container.setAlpha(0);

    // Listen for save events
    EventBus.on('save:completed', this.show.bind(this));
  }

  /**
   * Show the indicator and fade out
   */
  show(): void {
    // Cancel existing fade timer
    if (this.fadeTimer) {
      this.fadeTimer.destroy();
    }

    // Show immediately
    this.container.setAlpha(1);

    // Fade out after delay
    this.fadeTimer = this.scene.time.delayedCall(SAVE_CONFIG.INDICATOR_DURATION, () => {
      this.scene.tweens.add({
        targets: this.container,
        alpha: 0,
        duration: 500,
        ease: 'Power2',
      });
    });
  }

  /**
   * Clean up
   */
  destroy(): void {
    EventBus.off('save:completed', this.show);
    if (this.fadeTimer) {
      this.fadeTimer.destroy();
    }
    this.container.destroy();
  }
}
