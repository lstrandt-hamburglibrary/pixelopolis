/**
 * Config.ts
 * Global configuration for Pixelopolis
 */

export const Config = {
  // Game version
  VERSION: '0.1',

  // Game dimensions
  GAME_WIDTH: 1280,
  GAME_HEIGHT: 720,

  // Scaling
  SCALE_MODE: 'FIT' as const,
  AUTO_CENTER: true,

  // Background
  BACKGROUND_COLOR: '#1a1a1a',

  // Scene keys
  SCENES: {
    BOOT: 'BootScene',
    MAIN: 'MainScene',
    UI: 'UIScene',
  },

  // Events
  EVENTS: {
    INPUT_TAP: 'input:tap',
    INPUT_CLICK: 'input:click',
  },
} as const;
