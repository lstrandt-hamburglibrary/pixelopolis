/**
 * SaveLoadUI.ts
 * Manual Save/Load/Export/Import buttons
 */

import Phaser from 'phaser';
import { EventBus } from '@/utils/EventBus';

export class SaveLoadUI {
  private scene: Phaser.Scene;
  private container: Phaser.GameObjects.Container;
  private fileInput?: HTMLInputElement;

  constructor(scene: Phaser.Scene) {
    this.scene = scene;

    // Create container (top-left, below stats)
    this.container = scene.add.container(10, 160);
    this.container.setDepth(100);
    this.container.setScrollFactor(0);

    this.createButtons();
    this.createFileInput();
  }

  /**
   * Create buttons
   */
  private createButtons(): void {
    const buttonConfig = {
      fontSize: '14px',
      color: '#ffffff',
      backgroundColor: '#333333',
      padding: { x: 10, y: 6 },
    };

    const buttons = [
      { label: 'Save', y: 0, event: 'save:manual' },
      { label: 'Load', y: 35, event: 'load:manual' },
      { label: 'Export', y: 70, event: 'export:manual' },
      { label: 'Import', y: 105, event: 'import:manual' },
    ];

    for (const btn of buttons) {
      // Background
      const bg = this.scene.add.rectangle(0, btn.y, 100, 30, 0x333333);
      bg.setOrigin(0, 0);
      bg.setInteractive({ useHandCursor: true });

      // Text
      const text = this.scene.add.text(50, btn.y + 15, btn.label, buttonConfig);
      text.setOrigin(0.5, 0.5);

      // Hover effect
      bg.on('pointerover', () => {
        bg.setFillStyle(0x555555);
      });

      bg.on('pointerout', () => {
        bg.setFillStyle(0x333333);
      });

      // Click handler
      bg.on('pointerdown', () => {
        if (btn.event === 'import:manual') {
          // Special handling for import - trigger file input
          this.fileInput?.click();
        } else {
          EventBus.emit(btn.event);
        }
      });

      this.container.add([bg, text]);
    }
  }

  /**
   * Create hidden file input for import
   */
  private createFileInput(): void {
    this.fileInput = document.createElement('input');
    this.fileInput.type = 'file';
    this.fileInput.accept = '.json';
    this.fileInput.style.display = 'none';
    document.body.appendChild(this.fileInput);

    this.fileInput.addEventListener('change', (event) => {
      const file = (event.target as HTMLInputElement).files?.[0];
      if (!file) return;

      const reader = new FileReader();
      reader.onload = (e) => {
        const json = e.target?.result as string;
        EventBus.emit('import:file', json);
      };
      reader.readAsText(file);

      // Reset input so same file can be selected again
      this.fileInput!.value = '';
    });
  }

  /**
   * Clean up
   */
  destroy(): void {
    if (this.fileInput) {
      document.body.removeChild(this.fileInput);
    }
    this.container.destroy();
  }
}
