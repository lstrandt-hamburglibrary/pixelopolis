/**
 * GameConfig.ts
 * Phaser game configuration
 */

import Phaser from 'phaser';
import { Config } from '@/utils/Config';

export const phaserConfig: Phaser.Types.Core.GameConfig = {
  type: Phaser.AUTO,
  width: Config.GAME_WIDTH,
  height: Config.GAME_HEIGHT,
  parent: 'game-container',
  backgroundColor: Config.BACKGROUND_COLOR,
  scale: {
    mode: Phaser.Scale.FIT,
    autoCenter: Phaser.Scale.CENTER_BOTH,
    width: Config.GAME_WIDTH,
    height: Config.GAME_HEIGHT,
  },
  physics: {
    default: 'arcade',
    arcade: {
      gravity: { x: 0, y: 0 },
      debug: false,
    },
  },
  input: {
    activePointers: 3, // Support multi-touch
  },
  render: {
    pixelArt: true,
    antialias: false,
  },
  fps: {
    target: 60,
    forceSetTimeOut: false,
  },
  // Scenes will be added in main.ts
  scene: [],
};
