//
//  PebbleManager.swift
//  PebbleService
//
//  Main interface for Pebble smartwatch integration
//  Manages local API server and data updates
//

import Foundation
import LoopKit
import os.log

/// Manages Pebble smartwatch integration for Loop
/// Runs local HTTP server to expose CGM/pump data to Pebble via Bluetooth
public class PebbleManager {
    
    public static let shared = PebbleManager()
    
    private let log = OSLog(category: "PebbleManager")
    private let dataBridge = LoopDataBridge()
    private lazy var apiServer = LocalAPIServer(dataBridge: dataBridge)
    
    private var isStarted = false
    
    private init() {}
    
    // MARK: - Public Interface
    
    /// Start Pebble integration
    /// Begins local HTTP server for off-grid communication
    public func start() {
        guard !isStarted else {
            log.info("PebbleManager already started")
            return
        }
        
        log.info("Starting Pebble integration")
        apiServer.start()
        isStarted = true
        
        log.info("Pebble integration started - API available at http://127.0.0.1:8080")
    }
    
    /// Stop Pebble integration
    public func stop() {
        guard isStarted else { return }
        
        log.info("Stopping Pebble integration")
        apiServer.stop()
        isStarted = false
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
}

// MARK: - Integration with LoopDataManager

extension PebbleManager {
    
    /// Connect to LoopDataManager and receive updates
    /// Call this from LoopDataManager when WatchContext updates
    public func connectToLoopData() {
        // This will be called by LoopDataManager
        // When WatchContext is updated, call updateContext()
        log.info("PebbleManager connected to Loop data")
    }
}
