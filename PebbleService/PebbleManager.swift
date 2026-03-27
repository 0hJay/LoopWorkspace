//
//  PebbleManager.swift
//  PebbleService
//
//  Main interface for Pebble smartwatch integration
//  Manages local API server, data updates, and command confirmation
//

import Foundation
import LoopKit
import os.log

/// Manages Pebble smartwatch integration for Loop
/// Runs local HTTP server to expose CGM/pump data to Pebble via Bluetooth
/// Supports bolus and carb commands with iOS confirmation
public class PebbleManager {
    
    public static let shared = PebbleManager()
    
    private let log = OSLog(category: "PebbleManager")
    private let dataBridge = LoopDataBridge()
    public let commandManager = PebbleCommandManager.shared
    private var apiServer: LocalAPIServer!
    
    // MARK: - Configuration
    
    /// API port for local HTTP server (default: 8080)
    /// User-configurable via Settings UI
    private var configuredPort: UInt16 = LocalAPIServer.defaultPort
    
    /// Persisted key for port configuration
    private let portUserDefaultsKey = "PebbleAPIPort"
    
    private var isStarted = false
    
    private init() {
        // Load saved port from UserDefaults
        if let savedPort = UserDefaults.standard.object(forKey: portUserDefaultsKey) as? UInt16 {
            configuredPort = savedPort
        }
    }
    
    /// Initialize API server with configured port (lazy initialization)
    private func initializeAPIServer() {
        apiServer = LocalAPIServer(dataBridge: dataBridge, commandManager: commandManager, port: configuredPort)
    }
    
    // MARK: - Public Interface
    
    /// Start Pebble integration with current port configuration
    /// Begins local HTTP server for off-grid communication
    public func start() {
        guard !isStarted else {
            log.info("PebbleManager already started")
            return
        }
        
        // Initialize API server with configured port if not already done
        if apiServer == nil {
            initializeAPIServer()
        }
        
        log.info("Starting Pebble integration on port \(configuredPort)")
        apiServer.start()
        isStarted = true
        
        log.info("Pebble integration started - API available at http://127.0.0.1:\(configuredPort)")
        log.info(LocalAPIServer.apiDocumentation)
    }
    
    /// Stop Pebble integration
    public func stop() {
        guard isStarted else { return }
        
        log.info("Stopping Pebble integration")
        apiServer.stop()
        isStarted = false
    }
    
    /// Restart Pebble integration (useful after port change)
    public func restart() {
        stop()
        // Clear the API server so it reinitializes with new port
        apiServer = nil
        start()
    }
    
    /// Update data from WatchContext
    /// Called by LoopDataManager when new data arrives
    public func updateContext(_ context: WatchContext) {
        dataBridge.updateFromWatchContext(context)
        log.debug("Updated Pebble data from WatchContext")
    }
    
    /// Update CGM data directly
    public func updateGlucose(value: Double, unit: String, trend: String?, date: Date?) {
        dataBridge.updateGlucose(value: value, unit: unit, trend: trend, date: date)
    }
    
    /// Update insulin data directly
    public func updateInsulin(iob: Double?, cob: Double?, reservoir: Double?, reservoirPercent: Double?) {
        dataBridge.updateInsulin(iob: iob, cob: cob, reservoir: reservoir, reservoirPercent: reservoirPercent)
    }
    
    /// Update pump status directly
    public func updatePump(battery: Double?) {
        dataBridge.updatePump(battery: battery)
    }
    
    /// Update loop status directly
    public func updateLoopStatus(isClosedLoop: Bool?, lastRun: Date?, recommendedBolus: Double?, predicted: [Double]?) {
        dataBridge.updateLoopStatus(
            isClosedLoop: isClosedLoop,
            lastRun: lastRun,
            recommendedBolus: recommendedBolus,
            predicted: predicted
        )
    }
    
    // MARK: - Status
    
    /// Check if Pebble integration is running
    public var isRunning: Bool {
        return isStarted
    }
    
    /// Get API documentation
    public var apiDocs: String {
        return LocalAPIServer.apiDocumentation
    }
    
    // MARK: - Command Configuration
    
    /// Set maximum bolus allowed from Pebble
    public var maxBolus: Double {
        get { commandManager.maxBolus }
        set { commandManager.maxBolus = newValue }
    }
    
    /// Set maximum carbs allowed per entry from Pebble
    public var maxCarbs: Double {
        get { commandManager.maxCarbs }
        set { commandManager.maxCarbs = newValue }
    }
    
    /// Set delegate for command confirmation UI
    public var confirmationDelegate: PebbleCommandConfirmationDelegate? {
        get { commandManager.confirmationDelegate }
        set { commandManager.confirmationDelegate = newValue }
    }
    
    // MARK: - Port Configuration
    
    /// Get current API port
    public func getCurrentPort() -> UInt16 {
        return configuredPort
    }
    
    /// Set API port (requires restart to take effect)
    /// - Parameters:
    ///   - port: New port number (must be 1024-65535)
    ///   - restartNow: If true, restarts server immediately; if false, applies on next start
    public func setPort(_ port: UInt16, restartNow: Bool = false) -> Bool {
        // Validate port range
        guard port >= 1024 && port <= 65535 else {
            log.error("Invalid port number: \(port). Must be between 1024 and 65535")
            return false
        }
        
        // Save to UserDefaults
        UserDefaults.standard.set(port, forKey: portUserDefaultsKey)
        
        if port != configuredPort {
            let oldPort = configuredPort
            configuredPort = port
            
            log.info("Pebble API port changed from \(oldPort) to \(port)")
            
            if restartNow && isStarted {
                restart()
            }
        }
        
        return true
    }
    
    /// Get list of alternative ports for UI dropdown
    public static func getAvailablePorts() -> [UInt16] {
        return [LocalAPIServer.defaultPort] + LocalAPIServer.alternativePorts
    }
}

// MARK: - Integration with LoopDataManager

extension PebbleManager {
    
    /// Connect to LoopDataManager and receive updates
    /// Call this from LoopDataManager when WatchContext updates
    public func connectToLoopData() {
        log.info("PebbleManager connected to Loop data")
    }
}
