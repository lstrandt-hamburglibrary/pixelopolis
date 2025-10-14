/**
 * MainScene.ts
 * Main game scene with tile grid and brush system
 */

import Phaser from 'phaser';
import { Config } from '@/utils/Config';
import { EventBus } from '@/utils/EventBus';
import { WorldState } from '@/world/WorldState';
import { CommandQueue } from '@/commands/CommandQueue';
import { TileGridRenderer } from '@/rendering/TileGridRenderer';
import { CameraController } from '@/utils/CameraController';
import { BrushTool } from '@/tools/BrushTool';
import { BrushPaletteUI } from '@/ui/BrushPaletteUI';
import { PowerOverlayUI } from '@/ui/PowerOverlayUI';
import { GrowthToggleUI } from '@/ui/GrowthToggleUI';
import { SaveIndicatorUI } from '@/ui/SaveIndicatorUI';
import { SaveLoadUI } from '@/ui/SaveLoadUI';
import { BrushType, TILE_NAMES, SAVE_CONFIG } from '@/types';
import { PowerSystem } from '@/systems/PowerSystem';
import { SimulationSystem } from '@/simulation/SimulationSystem';
import { GrowthSystem } from '@/simulation/GrowthSystem';
import { EconomySystem } from '@/simulation/EconomySystem';
import { ParticleSystem } from '@/effects/ParticleSystem';
import { SaveSystem } from '@/systems/SaveSystem';

export class MainScene extends Phaser.Scene {
  // Core systems
  private worldState!: WorldState;
  private commandQueue!: CommandQueue;
  private gridRenderer!: TileGridRenderer;
  private cameraController!: CameraController;
  private brushTool!: BrushTool;
  private palette!: BrushPaletteUI;
  private powerOverlayUI!: PowerOverlayUI;
  private growthToggleUI!: GrowthToggleUI;
  private saveIndicatorUI!: SaveIndicatorUI;
  private saveLoadUI!: SaveLoadUI;
  private powerSystem!: PowerSystem;

  // Simulation systems
  private simulationSystem!: SimulationSystem;
  private growthSystem!: GrowthSystem;
  private economySystem!: EconomySystem;
  private particleSystem!: ParticleSystem;

  // Save system
  private autosaveTimer?: Phaser.Time.TimerEvent;

  // Input state
  private lastTileX: number = -1;
  private lastTileY: number = -1;
  private isRightMouseDown: boolean = false;

  // Tooltip
  private tooltipText?: Phaser.GameObjects.Text;

  constructor() {
    super({ key: Config.SCENES.MAIN });
  }

  create(): void {
    // Try to load saved game
    const saveData = SaveSystem.load();

    if (saveData) {
      // Load from save
      console.log('Loading saved game...');
      this.worldState = new WorldState(
        saveData.worldState.width,
        saveData.worldState.height,
        saveData.worldState.tileSize
      );
      this.worldState.loadFromData(saveData.worldState);
    } else {
      // Initialize new world state (64×64 tiles, 32px each)
      console.log('Creating new game...');
      this.worldState = new WorldState(64, 64, 32);
    }

    // Initialize command queue
    this.commandQueue = new CommandQueue();

    // Initialize power system
    this.powerSystem = new PowerSystem(this.worldState);

    // Initialize simulation systems
    this.simulationSystem = new SimulationSystem();
    this.economySystem = new EconomySystem(this.worldState, this.powerSystem);

    // Restore city stats if loading
    if (saveData) {
      this.economySystem.setCityStats(saveData.cityStats);
    }

    this.growthSystem = new GrowthSystem(
      this.worldState,
      this.powerSystem,
      this.economySystem.getCityStats()
    );

    // Initialize renderer
    this.gridRenderer = new TileGridRenderer(this, this.worldState);
    this.gridRenderer.setPowerSystem(this.powerSystem);

    // Initialize particle system
    this.particleSystem = new ParticleSystem(this, this.worldState);

    // Initialize camera controller
    this.cameraController = new CameraController(this);
    this.cameraController.setZoomLimits(0.5, 2.0);

    // Center camera on world (isometric - center is at 0,0)
    // The middle tile in isometric space
    const midTileX = this.worldState.getWidth() / 2;
    const midTileY = this.worldState.getHeight() / 2;
    const centerPos = this.worldState.tileToWorld(midTileX, midTileY);
    this.cameraController.centerOn(centerPos.x, centerPos.y);

    // Initialize brush tool
    this.brushTool = new BrushTool(this.worldState, this.commandQueue);

    // Initialize UI
    this.palette = new BrushPaletteUI(this);
    this.powerOverlayUI = new PowerOverlayUI(this);
    this.growthToggleUI = new GrowthToggleUI(this);
    this.saveIndicatorUI = new SaveIndicatorUI(this);
    this.saveLoadUI = new SaveLoadUI(this);

    // Set initial brush on the tool to match palette
    this.brushTool.setBrushType(this.palette.getSelectedBrush());
    EventBus.emit('brush:changed', this.palette.getSelectedBrush());

    // Create tooltip
    this.createTooltip();

    // Set up input handlers
    this.setupInput();

    // Listen for brush selection events
    EventBus.on('brush:selected', this.onBrushSelected.bind(this));
    EventBus.on('power-overlay:toggle-requested', this.onPowerOverlayToggle.bind(this));

    // Listen for building changes
    EventBus.on('buildings:changed', this.onBuildingsChanged.bind(this));

    // Set up save system
    this.setupSaveSystem();

    // Send world state reference to UI scene
    EventBus.emit('world:loaded', {
      worldState: this.worldState,
      commandQueue: this.commandQueue,
      brushTool: this.brushTool,
      powerSystem: this.powerSystem,
    });
  }

  /**
   * Set up input handlers
   */
  private setupInput(): void {
    // Mouse down
    this.input.on('pointerdown', (pointer: Phaser.Input.Pointer) => {
      if (pointer.rightButtonDown()) {
        // Right mouse: start camera pan
        this.isRightMouseDown = true;
        this.cameraController.startDrag(pointer);
      } else if (pointer.leftButtonDown()) {
        // Left mouse: start painting (if not over UI)
        if (!this.isPointerOverUI(pointer)) {
          this.brushTool.startPaint();
          this.tryPaintAtPointer(pointer);
        }
      }
    });

    // Mouse move
    this.input.on('pointermove', (pointer: Phaser.Input.Pointer) => {
      // Update camera pan
      if (this.isRightMouseDown) {
        this.cameraController.updateDrag(pointer);
      }

      // Update tile highlight and paint
      this.updateHighlight(pointer);

      // Continue painting if brush is active
      if (this.brushTool.getIsPainting()) {
        this.tryPaintAtPointer(pointer);
      }
    });

    // Mouse up
    this.input.on('pointerup', (pointer: Phaser.Input.Pointer) => {
      if (pointer.button === 2) {
        // Right mouse released
        this.isRightMouseDown = false;
        this.cameraController.stopDrag();
      } else if (pointer.button === 0) {
        // Left mouse released
        this.brushTool.stopPaint();
      }
    });

    // Keyboard shortcuts
    this.input.keyboard?.on('keydown-Z', (event: KeyboardEvent) => {
      if (event.ctrlKey || event.metaKey) {
        // Ctrl+Z: Undo
        if (this.commandQueue.canUndo()) {
          this.commandQueue.undo();
          this.gridRenderer.renderAll();
          this.powerSystem.recalculate();
          this.gridRenderer.updatePowerOverlay();
          EventBus.emit('power:updated');
        }
      }
    });

    this.input.keyboard?.on('keydown-Y', (event: KeyboardEvent) => {
      if (event.ctrlKey || event.metaKey) {
        // Ctrl+Y: Redo
        if (this.commandQueue.canRedo()) {
          this.commandQueue.redo();
          this.gridRenderer.renderAll();
          this.powerSystem.recalculate();
          this.gridRenderer.updatePowerOverlay();
          EventBus.emit('power:updated');
        }
      }
    });

    // Number keys for brush selection
    this.input.keyboard?.on('keydown-ONE', () => this.palette.selectBrush(BrushType.ROAD));
    this.input.keyboard?.on('keydown-TWO', () => this.palette.selectBrush(BrushType.RES));
    this.input.keyboard?.on('keydown-THREE', () => this.palette.selectBrush(BrushType.COM));
    this.input.keyboard?.on('keydown-FOUR', () => this.palette.selectBrush(BrushType.IND));
    this.input.keyboard?.on('keydown-FIVE', () => this.palette.selectBrush(BrushType.POWER_PLANT));
    this.input.keyboard?.on('keydown-SIX', () => this.palette.selectBrush(BrushType.ERASER));

    // Power overlay toggle
    this.input.keyboard?.on('keydown-P', () => {
      this.gridRenderer.togglePowerOverlay();
      EventBus.emit('power-overlay:toggled', this.gridRenderer.getPowerOverlayVisible());
    });
  }

  /**
   * Check if pointer is over UI
   */
  private isPointerOverUI(pointer: Phaser.Input.Pointer): boolean {
    // Check if pointer is over brush palette (left side)
    // Buttons: 6 buttons × 40px height + 5 gaps × 10px = 240px + 50px = 290px total
    // Starting at y=60, ending at y=350
    if (pointer.x < 120 && pointer.y >= 60 && pointer.y < 360) {
      return true;
    }
    // Check if pointer is over power overlay button (top)
    if (pointer.x >= 140 && pointer.x < 270 && pointer.y >= 10 && pointer.y < 60) {
      return true;
    }
    // Check if pointer is over save/load buttons (left side, below stats)
    // 4 buttons × 30px height + 3 gaps × 5px = 120px + 15px = 135px total
    // Starting at x=10, y=160, width=100px
    if (pointer.x >= 10 && pointer.x < 110 && pointer.y >= 160 && pointer.y < 295) {
      return true;
    }
    return false;
  }

  /**
   * Create tooltip
   */
  private createTooltip(): void {
    this.tooltipText = this.add.text(0, 0, '', {
      fontSize: '14px',
      color: '#ffffff',
      backgroundColor: '#000000',
      padding: { x: 8, y: 4 },
    });
    this.tooltipText.setDepth(200);
    this.tooltipText.setScrollFactor(0);
    this.tooltipText.setVisible(false);
  }

  /**
   * Update tile highlight and tooltip
   */
  private updateHighlight(pointer: Phaser.Input.Pointer): void {
    const worldPoint = this.cameras.main.getWorldPoint(pointer.x, pointer.y);
    const tilePos = this.worldState.worldToTile(worldPoint.x, worldPoint.y);

    if (this.worldState.isValidPosition(tilePos.x, tilePos.y)) {
      this.gridRenderer.highlightTile(tilePos);
      this.updateTooltip(tilePos, pointer);
    } else {
      this.gridRenderer.highlightTile(null);
      this.hideTooltip();
    }
  }

  /**
   * Update tooltip with tile information
   */
  private updateTooltip(tilePos: { x: number; y: number }, pointer: Phaser.Input.Pointer): void {
    if (!this.tooltipText) return;

    const tile = this.worldState.getTile(tilePos.x, tilePos.y);
    if (!tile) {
      this.hideTooltip();
      return;
    }

    const tileName = TILE_NAMES[tile.type];

    // Check power status
    const isPowered = this.powerSystem.isPowered(tilePos.x, tilePos.y);
    const needsPower = this.powerSystem.needsPower(tile.type);

    let tooltipText = tileName;
    if (needsPower) {
      tooltipText += isPowered ? ' (Powered)' : ' (Unpowered)';
    }

    this.tooltipText.setText(tooltipText);
    this.tooltipText.setPosition(pointer.x + 15, pointer.y + 15);
    this.tooltipText.setVisible(true);
  }

  /**
   * Hide tooltip
   */
  private hideTooltip(): void {
    if (this.tooltipText) {
      this.tooltipText.setVisible(false);
    }
  }

  /**
   * Try to paint at pointer position
   */
  private tryPaintAtPointer(pointer: Phaser.Input.Pointer): void {
    const worldPoint = this.cameras.main.getWorldPoint(pointer.x, pointer.y);
    const tilePos = this.worldState.worldToTile(worldPoint.x, worldPoint.y);

    // Only paint if we've moved to a new tile
    if (tilePos.x !== this.lastTileX || tilePos.y !== this.lastTileY) {
      const painted = this.brushTool.paint(tilePos);
      if (painted) {
        this.gridRenderer.updateTile(tilePos.x, tilePos.y);
        // Recalculate power grid
        this.powerSystem.recalculate();
        this.gridRenderer.updatePowerOverlay();
        EventBus.emit('power:updated');
      }
      this.lastTileX = tilePos.x;
      this.lastTileY = tilePos.y;
    }
  }

  /**
   * Handle brush selection
   */
  private onBrushSelected(brushType: BrushType): void {
    this.brushTool.setBrushType(brushType);
    EventBus.emit('brush:changed', brushType);
  }

  /**
   * Handle power overlay toggle request
   */
  private onPowerOverlayToggle(): void {
    this.gridRenderer.togglePowerOverlay();
    EventBus.emit('power-overlay:toggled', this.gridRenderer.getPowerOverlayVisible());
  }

  /**
   * Handle buildings changed event
   */
  private onBuildingsChanged(tiles: { x: number; y: number }[]): void {
    this.gridRenderer.updateTiles(tiles);
  }

  /**
   * Set up save system with autosave and manual controls
   */
  private setupSaveSystem(): void {
    // Set up autosave timer
    this.autosaveTimer = this.time.addEvent({
      delay: SAVE_CONFIG.AUTOSAVE_INTERVAL,
      callback: this.performSave.bind(this),
      loop: true,
    });

    // Listen for manual save/load/export/import events
    EventBus.on('save:manual', this.performSave.bind(this));
    EventBus.on('load:manual', this.performLoad.bind(this));
    EventBus.on('export:manual', this.performExport.bind(this));
    EventBus.on('import:file', this.performImport.bind(this));
  }

  /**
   * Perform save operation
   */
  private performSave(): void {
    const worldStateData = this.worldState.serialize();
    const cityStats = this.economySystem.getCityStats();
    SaveSystem.save(worldStateData, cityStats);
  }

  /**
   * Perform load operation
   */
  private performLoad(): void {
    const saveData = SaveSystem.load();
    if (!saveData) {
      console.warn('No save data found');
      return;
    }

    // Reload the scene to apply loaded data
    this.scene.restart();
  }

  /**
   * Perform export operation
   */
  private performExport(): void {
    const worldStateData = this.worldState.serialize();
    const cityStats = this.economySystem.getCityStats();
    SaveSystem.downloadJSON(worldStateData, cityStats);
  }

  /**
   * Perform import operation
   */
  private performImport(jsonString: string): void {
    const saveData = SaveSystem.importJSON(jsonString);
    if (!saveData) {
      console.error('Failed to import save data');
      return;
    }

    // Save imported data to localStorage
    SaveSystem.save(saveData.worldState, saveData.cityStats);

    // Reload the scene to apply imported data
    this.scene.restart();
  }

  /**
   * Update simulation and effects
   */
  update(time: number, delta: number): void {
    // Update simulation system with current time
    this.simulationSystem.update(time);

    // Update particles with delta in seconds
    this.particleSystem.update(delta / 1000);
  }

  /**
   * Clean up on shutdown
   */
  shutdown(): void {
    // Save on exit
    this.performSave();

    // Clean up event listeners
    EventBus.off('brush:selected', this.onBrushSelected);
    EventBus.off('power-overlay:toggle-requested', this.onPowerOverlayToggle);
    EventBus.off('buildings:changed', this.onBuildingsChanged);
    EventBus.off('save:manual', this.performSave);
    EventBus.off('load:manual', this.performLoad);
    EventBus.off('export:manual', this.performExport);
    EventBus.off('import:file', this.performImport);

    // Clean up systems
    this.gridRenderer.destroy();
    this.palette.destroy();
    this.powerOverlayUI.destroy();
    this.growthToggleUI.destroy();
    this.saveIndicatorUI.destroy();
    this.saveLoadUI.destroy();
    this.simulationSystem.destroy();
    this.growthSystem.destroy();
    this.economySystem.destroy();
    this.particleSystem.destroy();

    // Clean up autosave timer
    if (this.autosaveTimer) {
      this.autosaveTimer.destroy();
    }
  }
}
