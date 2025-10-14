/**
 * main.ts
 * Entry point for Pixelopolis
 */

import Phaser from 'phaser';
import { phaserConfig } from '@/config/GameConfig';
import { BootScene } from '@/scenes/BootScene';
import { MainScene } from '@/scenes/MainScene';
import { UIScene } from '@/scenes/UIScene';

/**
 * Initialize and start the game
 */
function startGame(): void {
  // Add scenes to configuration
  const config: Phaser.Types.Core.GameConfig = {
    ...phaserConfig,
    scene: [BootScene, MainScene, UIScene],
  };

  // Create the game instance
  const game = new Phaser.Game(config);

  // Handle window resize
  window.addEventListener('resize', () => {
    game.scale.refresh();
  });

  // Pause/resume on tab visibility change
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
      // Tab is hidden - pause the game
      game.scene.getScenes(true).forEach((scene) => {
        scene.scene.pause();
      });
    } else {
      // Tab is visible - resume the game
      game.scene.getScenes(true).forEach((scene) => {
        scene.scene.resume();
      });
    }
  });

  // Expose game instance for debugging
  if (typeof window !== 'undefined') {
    (window as any).game = game;
  }

  // Log startup message
  console.log('🏙️ Pixelopolis initialized');
  console.log(`Resolution: ${config.width}x${config.height}`);
  console.log(`Scale mode: ${config.scale?.mode}`);
}

// Start the game when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', startGame);
} else {
  startGame();
}
