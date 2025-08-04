/**
 * bookingLogger.js - Debug logging utility for the booking system
 *
 * Provides configurable debug logging that can be enabled/disabled at runtime.
 * Logs can be controlled via localStorage or global variables.
 */

class BookingLogger {
    constructor(module) {
        this.module = module;
        this.enabled = false;
        this.logLevels = {
            DEBUG: "debug",
            INFO: "info",
            WARN: "warn",
            ERROR: "error",
        };
        // Don't log anything by default unless explicitly enabled
        this.enabledLevels = new Set();
        // Track active timers and groups to prevent console errors
        this._activeTimers = new Set();
        this._activeGroups = [];

        // Check for debug configuration
        if (typeof window !== "undefined" && window.localStorage) {
            // Check localStorage first, then global variable
            this.enabled =
                window.localStorage.getItem("koha.booking.debug") === "true" ||
                window.KOHA_BOOKING_DEBUG === true;

            // Allow configuring specific log levels
            const levels = window.localStorage.getItem(
                "koha.booking.debug.levels"
            );
            if (levels) {
                this.enabledLevels = new Set(levels.split(","));
            }
        }
    }

    /**
     * Enable or disable debug logging
     * @param {boolean} enabled
     */
    setEnabled(enabled) {
        this.enabled = enabled;
        if (enabled) {
            // When enabling debug, include all levels
            this.enabledLevels = new Set(["debug", "info", "warn", "error"]);
        } else {
            // When disabling, clear all levels
            this.enabledLevels = new Set();
        }
        if (typeof window !== "undefined" && window.localStorage) {
            window.localStorage.setItem(
                "koha.booking.debug",
                enabled.toString()
            );
        }
    }

    /**
     * Set which log levels are enabled
     * @param {string[]} levels - Array of level names (debug, info, warn, error)
     */
    setLevels(levels) {
        this.enabledLevels = new Set(levels);
        if (typeof window !== "undefined" && window.localStorage) {
            window.localStorage.setItem(
                "koha.booking.debug.levels",
                levels.join(",")
            );
        }
    }

    /**
     * Core logging method
     * @param {string} level
     * @param {string} message
     * @param  {...any} args
     */
    log(level, message, ...args) {
        // Skip if this specific level is not enabled
        if (!this.enabledLevels.has(level)) return;

        const timestamp = new Date().toISOString();
        const prefix = `[${timestamp}] [${
            this.module
        }] [${level.toUpperCase()}]`;

        // Log to console with appropriate method
        console[level](prefix, message, ...args);

        // Store in buffer for export
        this._logBuffer = this._logBuffer || [];
        this._logBuffer.push({
            timestamp,
            module: this.module,
            level,
            message,
            args,
        });

        // Keep buffer size reasonable (last 1000 entries)
        if (this._logBuffer.length > 1000) {
            this._logBuffer = this._logBuffer.slice(-1000);
        }
    }

    // Convenience methods
    debug(message, ...args) {
        this.log("debug", message, ...args);
    }
    info(message, ...args) {
        this.log("info", message, ...args);
    }
    warn(message, ...args) {
        this.log("warn", message, ...args);
    }
    error(message, ...args) {
        this.log("error", message, ...args);
    }

    /**
     * Performance timing utilities
     */
    time(label) {
        if (!this.enabledLevels.has("debug")) return;
        const key = `[${this.module}] ${label}`;
        console.time(key);
        this._activeTimers.add(label);
        this._timers = this._timers || {};
        this._timers[label] = performance.now();
    }

    timeEnd(label) {
        if (!this.enabledLevels.has("debug")) return;
        // Only call console.timeEnd if we actually started this timer
        if (!this._activeTimers.has(label)) return;

        const key = `[${this.module}] ${label}`;
        console.timeEnd(key);
        this._activeTimers.delete(label);

        // Also log the duration
        if (this._timers && this._timers[label]) {
            const duration = performance.now() - this._timers[label];
            this.debug(`${label} completed in ${duration.toFixed(2)}ms`);
            delete this._timers[label];
        }
    }

    /**
     * Group related log entries
     */
    group(label) {
        if (!this.enabledLevels.has("debug")) return;
        console.group(`[${this.module}] ${label}`);
        this._activeGroups.push(label);
    }

    groupEnd() {
        if (!this.enabledLevels.has("debug")) return;
        // Only call console.groupEnd if we have an active group
        if (this._activeGroups.length === 0) return;

        console.groupEnd();
        this._activeGroups.pop();
    }

    /**
     * Export logs for bug reports
     */
    exportLogs() {
        return {
            module: this.module,
            enabled: this.enabled,
            enabledLevels: Array.from(this.enabledLevels),
            logs: this._logBuffer || [],
        };
    }

    /**
     * Clear log buffer
     */
    clearLogs() {
        this._logBuffer = [];
        this._activeTimers.clear();
        this._activeGroups = [];
    }
}

// Create singleton instances for each module
export const managerLogger = new BookingLogger("BookingManager");
export const calendarLogger = new BookingLogger("BookingCalendar");

// Expose debug utilities to browser console
if (typeof window !== "undefined") {
    const debugObj = {
        // Enable/disable all booking debug logs
        enable() {
            managerLogger.setEnabled(true);
            calendarLogger.setEnabled(true);
            console.log("Booking debug logging enabled");
        },

        disable() {
            managerLogger.setEnabled(false);
            calendarLogger.setEnabled(false);
            console.log("Booking debug logging disabled");
        },

        // Set specific log levels
        setLevels(levels) {
            managerLogger.setLevels(levels);
            calendarLogger.setLevels(levels);
            console.log(`Booking log levels set to: ${levels.join(", ")}`);
        },

        // Export all logs
        exportLogs() {
            return {
                manager: managerLogger.exportLogs(),
                calendar: calendarLogger.exportLogs(),
            };
        },

        // Clear all logs
        clearLogs() {
            managerLogger.clearLogs();
            calendarLogger.clearLogs();
            console.log("Booking logs cleared");
        },

        // Get current status
        status() {
            return {
                enabled: {
                    manager: managerLogger.enabled,
                    calendar: calendarLogger.enabled,
                },
                levels: {
                    manager: Array.from(managerLogger.enabledLevels),
                    calendar: Array.from(calendarLogger.enabledLevels),
                },
            };
        },
    };

    // Set on browser window
    window.BookingDebug = debugObj;

    // Only log availability message if debug is already enabled
    if (managerLogger.enabled || calendarLogger.enabled) {
        console.log("Booking debug utilities available at window.BookingDebug");
    }
}

// Additional setup for Node.js testing environment
if (typeof global !== "undefined" && typeof window === "undefined") {
    // We're in Node.js - set up global.window if it exists
    if (global.window) {
        const debugObj = {
            enable: () => {
                managerLogger.setEnabled(true);
                calendarLogger.setEnabled(true);
            },
            disable: () => {
                managerLogger.setEnabled(false);
                calendarLogger.setEnabled(false);
            },
            exportLogs: () => ({
                manager: managerLogger.exportLogs(),
                calendar: calendarLogger.exportLogs(),
            }),
            status: () => ({
                managerEnabled: managerLogger.enabled,
                calendarEnabled: calendarLogger.enabled,
            }),
        };
        global.window.BookingDebug = debugObj;
    }
}
