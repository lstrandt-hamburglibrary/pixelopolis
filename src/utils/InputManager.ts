/**
 * InputManager.ts
 * Unified input handling for mouse and touch
 */

import Phaser from 'phaser';
import { EventBus } from './EventBus';
import { Config } from './Config';

export class InputManager {
  private scene: Phaser.Scene;

  constructor(scene: Phaser.Scene) {
    this.scene = scene;
    this.setupInput();
  }

  /**
   * Set up mouse and touch input handlers
   */
  private setupInput(): void {
    // Handle pointer down (works for both mouse and touch)
    this.scene.input.on('pointerdown', (pointer: Phaser.Input.Pointer) => {
      const eventName = pointer.event?.type === 'touchstart'
        ? Config.EVENTS.INPUT_TAP
        : Config.EVENTS.INPUT_CLICK;

      EventBus.emit(eventName, {
        x: pointer.x,
        y: pointer.y,
        worldX: pointer.worldX,
        worldY: pointer.worldY,
      });
    });
  }

  /**
   * Clean up input handlers
   */
  destroy(): void {
    this.scene.input.off('pointerdown');
  }
}
