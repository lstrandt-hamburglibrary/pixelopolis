/**
 * CameraController.ts
 * Handles camera pan and zoom with touch/mouse support
 */

import Phaser from 'phaser';

export class CameraController {
  private scene: Phaser.Scene;
  private camera: Phaser.Cameras.Scene2D.Camera;
  private isDragging: boolean = false;
  private dragStartX: number = 0;
  private dragStartY: number = 0;
  private cameraStartX: number = 0;
  private cameraStartY: number = 0;

  private minZoom: number = 0.5;
  private maxZoom: number = 2.0;
  private zoomSpeed: number = 0.1;

  // Pinch zoom state
  private isPinching: boolean = false;
  private initialPinchDistance: number = 0;
  private initialZoom: number = 1.0;

  constructor(scene: Phaser.Scene) {
    this.scene = scene;
    this.camera = scene.cameras.main;

    this.setupControls();
  }

  /**
   * Set up camera controls
   */
  private setupControls(): void {
    // Mouse wheel zoom
    this.scene.input.on('wheel', (_pointer: any, _gameObjects: any[], _deltaX: number, deltaY: number) => {
      this.handleWheelZoom(deltaY);
    });

    // Touch/pinch zoom
    this.scene.input.on('pointermove', (_pointer: Phaser.Input.Pointer) => {
      if (this.scene.input.pointer2.isDown) {
        this.handlePinchZoom();
      }
    });

    // Touch release
    this.scene.input.on('pointerup', () => {
      this.isPinching = false;
    });
  }

  /**
   * Start camera drag (call on right mouse or single touch)
   */
  startDrag(pointer: Phaser.Input.Pointer): void {
    this.isDragging = true;
    this.dragStartX = pointer.x;
    this.dragStartY = pointer.y;
    this.cameraStartX = this.camera.scrollX;
    this.cameraStartY = this.camera.scrollY;
  }

  /**
   * Update camera drag
   */
  updateDrag(pointer: Phaser.Input.Pointer): void {
    if (!this.isDragging) return;

    const deltaX = pointer.x - this.dragStartX;
    const deltaY = pointer.y - this.dragStartY;

    this.camera.scrollX = this.cameraStartX - deltaX / this.camera.zoom;
    this.camera.scrollY = this.cameraStartY - deltaY / this.camera.zoom;
  }

  /**
   * Stop camera drag
   */
  stopDrag(): void {
    this.isDragging = false;
  }

  /**
   * Check if currently dragging
   */
  getIsDragging(): boolean {
    return this.isDragging;
  }

  /**
   * Handle mouse wheel zoom
   */
  private handleWheelZoom(deltaY: number): void {
    const zoomDelta = deltaY > 0 ? -this.zoomSpeed : this.zoomSpeed;
    this.zoom(zoomDelta);
  }

  /**
   * Handle pinch zoom
   */
  private handlePinchZoom(): void {
    const pointer1 = this.scene.input.pointer1;
    const pointer2 = this.scene.input.pointer2;

    if (!pointer1.isDown || !pointer2.isDown) {
      return;
    }

    const distance = Phaser.Math.Distance.Between(
      pointer1.x,
      pointer1.y,
      pointer2.x,
      pointer2.y
    );

    if (!this.isPinching) {
      this.isPinching = true;
      this.initialPinchDistance = distance;
      this.initialZoom = this.camera.zoom;
    } else {
      const scale = distance / this.initialPinchDistance;
      const newZoom = Phaser.Math.Clamp(
        this.initialZoom * scale,
        this.minZoom,
        this.maxZoom
      );
      this.camera.setZoom(newZoom);
    }
  }

  /**
   * Zoom by delta
   */
  private zoom(delta: number): void {
    const newZoom = Phaser.Math.Clamp(
      this.camera.zoom + delta,
      this.minZoom,
      this.maxZoom
    );
    this.camera.setZoom(newZoom);
  }

  /**
   * Set zoom level
   */
  setZoom(zoom: number): void {
    const clampedZoom = Phaser.Math.Clamp(zoom, this.minZoom, this.maxZoom);
    this.camera.setZoom(clampedZoom);
  }

  /**
   * Get current zoom
   */
  getZoom(): number {
    return this.camera.zoom;
  }

  /**
   * Pan to position
   */
  panTo(x: number, y: number): void {
    this.camera.scrollX = x;
    this.camera.scrollY = y;
  }

  /**
   * Center camera on position
   */
  centerOn(x: number, y: number): void {
    this.camera.centerOn(x, y);
  }

  /**
   * Get camera bounds
   */
  getBounds(): { x: number; y: number; width: number; height: number } {
    return {
      x: this.camera.scrollX,
      y: this.camera.scrollY,
      width: this.camera.width / this.camera.zoom,
      height: this.camera.height / this.camera.zoom,
    };
  }

  /**
   * Set zoom limits
   */
  setZoomLimits(min: number, max: number): void {
    this.minZoom = min;
    this.maxZoom = max;
  }

  /**
   * Reset camera to default position and zoom
   */
  reset(): void {
    this.camera.setZoom(1.0);
    this.camera.scrollX = 0;
    this.camera.scrollY = 0;
  }
}
