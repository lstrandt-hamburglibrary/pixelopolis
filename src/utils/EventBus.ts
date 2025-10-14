/**
 * EventBus.ts
 * Simple event bus for inter-scene communication
 */

type EventCallback = (...args: any[]) => void;

class EventBusClass {
  private events: Map<string, EventCallback[]>;

  constructor() {
    this.events = new Map();
  }

  /**
   * Subscribe to an event
   * @param event Event name
   * @param callback Callback function
   */
  on(event: string, callback: EventCallback): void {
    if (!this.events.has(event)) {
      this.events.set(event, []);
    }
    this.events.get(event)!.push(callback);
  }

  /**
   * Unsubscribe from an event
   * @param event Event name
   * @param callback Callback function to remove
   */
  off(event: string, callback: EventCallback): void {
    const callbacks = this.events.get(event);
    if (callbacks) {
      const index = callbacks.indexOf(callback);
      if (index > -1) {
        callbacks.splice(index, 1);
      }
    }
  }

  /**
   * Emit an event
   * @param event Event name
   * @param args Arguments to pass to callbacks
   */
  emit(event: string, ...args: any[]): void {
    const callbacks = this.events.get(event);
    if (callbacks) {
      callbacks.forEach((callback) => callback(...args));
    }
  }

  /**
   * Remove all listeners for an event or all events
   * @param event Optional event name (if omitted, clears all)
   */
  clear(event?: string): void {
    if (event) {
      this.events.delete(event);
    } else {
      this.events.clear();
    }
  }
}

// Export singleton instance
export const EventBus = new EventBusClass();
