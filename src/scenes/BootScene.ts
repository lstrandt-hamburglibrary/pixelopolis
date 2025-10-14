/**
 * BootScene.ts
 * Boot and preload scene
 */

import Phaser from 'phaser';
import { Config } from '@/utils/Config';

export class BootScene extends Phaser.Scene {
  constructor() {
    super({ key: Config.SCENES.BOOT });
  }

  preload(): void {
    // Update loading screen progress
    this.load.on('progress', (value: number) => {
      const loadingBarFill = document.getElementById('loading-bar-fill');
      if (loadingBarFill) {
        loadingBarFill.style.width = `${value * 100}%`;
      }
    });

    // Preload any assets here (none for now)
    // Future: this.load.image('logo', 'assets/logo.png');
  }

  create(): void {
    // Hide loading screen
    const loadingScreen = document.getElementById('loading-screen');
    if (loadingScreen) {
      loadingScreen.classList.add('hidden');
      setTimeout(() => {
        loadingScreen.style.display = 'none';
      }, 500);
    }

    // Start main game scenes
    this.scene.start(Config.SCENES.MAIN);
    this.scene.launch(Config.SCENES.UI);
  }
}
