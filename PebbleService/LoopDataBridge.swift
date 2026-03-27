//
//  LoopDataBridge.swift
//  PebbleService
//
//  Bridges LoopKit data to Pebble API responses
//  Formats WatchContext data for JSON consumption
//

import Foundation
import LoopKit
import HealthKit

/// Provides formatted JSON data from Loop's data stores
public class LoopDataBridge {
    
    private let glucoseFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1
        return formatter
    }()
    
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    // Current data (updated by LoopDataManager)
    private var currentGlucose: Double?
    private var glucoseUnit: String = "mg/dL"
    private var glucoseTrend: String?
    private var glucoseDate: Date?
    private var iob: Double?
    private var cob: Double?
    private var reservoirLevel: Double?
    private var reservoirPercentage: Double?
    private var batteryPercentage: Double?
    private var isClosedLoop: Bool?
    private var lastLoopRun: Date?
    private var recommendedBolus: Double?
    private var predictedGlucose: [Double]?
    
    public init() {}
    
    // MARK: - Data Update Methods
    
    /// Update CGM data
    public func updateGlucose(value: Double, unit: String, trend: String?, date: Date?) {
        self.currentGlucose = value
        self.glucoseUnit = unit
        self.glucoseTrend = trend
        self.glucoseDate = date
    }
    
    /// Update insulin data
    public func updateInsulin(iob: Double?, cob: Double?, reservoir: Double?, reservoirPercent: Double?) {
        self.iob = iob
        self.cob = cob
        self.reservoirLevel = reservoir
        self.reservoirPercentage = reservoirPercent
    }
    
    /// Update pump status
    public func updatePump(battery: Double?) {
        self.batteryPercentage = battery
    }
    
    /// Update loop status
    public func updateLoopStatus(isClosedLoop: Bool?, lastRun: Date?, recommendedBolus: Double?, predicted: [Double]?) {
        self.isClosedLoop = isClosedLoop
        self.lastLoopRun = lastRun
        self.recommendedBolus = recommendedBolus
        self.predictedGlucose = predicted
    }
    
    /// Update from WatchContext (main data source)
    public func updateFromWatchContext(_ context: WatchContext) {
        let unit = context.displayGlucoseUnit ?? .milligramsPerDeciliter
        
        if let glucose = context.glucose {
            self.currentGlucose = glucose.doubleValue(for: unit)
            self.glucoseUnit = unit.unitString
        }
        
        self.glucoseTrend = context.glucoseTrend?.symbol
        self.glucoseDate = context.glucoseDate
        self.iob = context.iob
        self.cob = context.cob
        self.reservoirLevel = context.reservoir
        self.reservoirPercentage = context.reservoirPercentage
        self.batteryPercentage = context.batteryPercentage
        self.isClosedLoop = context.isClosedLoop
        self.lastLoopRun = context.loopLastRunDate
        self.recommendedBolus = context.recommendedBolusDose
        self.predictedGlucose = context.predictedGlucose?.values.map { $0.doubleValue(for: unit) }
    }
    
    // MARK: - JSON Response Methods
    
    /// CGM data JSON
    public func cgmJSON() -> String {
        let glucoseStr = currentGlucose != nil ? "\(currentGlucose!)" : "null"
        let trendStr = glucoseTrend != nil ? "\"\(glucoseTrend!)\"" : "null"
        let dateStr = glucoseDate != nil ? "\"\(dateFormatter.string(from: glucoseDate!))\"" : "null"
        
        return """
        {
          "glucose": \(glucoseStr),
          "unit": "\(glucoseUnit)",
          "trend": \(trendStr),
          "date": \(dateStr),
          "isStale": \(isGlucoseStale())
        }
        """
    }
    
    /// Pump status JSON
    public func pumpJSON() -> String {
        let reservoirStr = reservoirLevel != nil ? "\(reservoirLevel!)" : "null"
        let reservoirPctStr = reservoirPercentage != nil ? "\(reservoirPercentage!)" : "null"
        let batteryStr = batteryPercentage != nil ? "\(batteryPercentage!)" : "null"
        
        return """
        {
          "reservoir": \(reservoirStr),
          "reservoirPercent": \(reservoirPctStr),
          "battery": \(batteryStr)
        }
        """
    }
    
    /// Loop status JSON
    public func loopJSON() -> String {
        let iobStr = iob != nil ? "\(iob!)" : "null"
        let cobStr = cob != nil ? "\(cob!)" : "null"
        let closedLoopStr = isClosedLoop.map { "\($0)" } ?? "null"
        let lastRunStr = lastLoopRun != nil ? "\"\(dateFormatter.string(from: lastLoopRun!))\"" : "null"
        let bolusStr = recommendedBolus != nil ? "\(recommendedBolus!)" : "null"
        let predictedStr = formatPredictedGlucose()
        
        return """
        {
          "isClosedLoop": \(closedLoopStr),
          "lastRun": \(lastRunStr),
          "iob": \(iobStr),
          "cob": \(cobStr),
          "recommendedBolus": \(bolusStr),
          "predictedGlucose": \(predictedStr)
        }
        """
    }
    
    /// All data combined JSON
    public func allDataJSON() -> String {
        let glucose = extractGlucoseJSON()
        let pump = extractPumpJSON()
        let loop = extractLoopJSON()
        
        return """
        {
          "timestamp": "\(dateFormatter.string(from: Date()))",
          "cgm": \(glucose),
          "pump": \(pump),
          "loop": \(loop)
        }
        """
    }
    
    // MARK: - Helper Methods
    
    private func isGlucoseStale() -> Bool {
        guard let date = glucoseDate else { return true }
        return Date().timeIntervalSince(date) > 15 * 60 // 15 minutes
    }
    
    private func formatPredictedGlucose() -> String {
        guard let values = predictedGlucose, !values.isEmpty else {
            return "[]"
        }
        // Return first 12 values (1 hour of 5-minute intervals)
        let limited = Array(values.prefix(12))
        return "[\(limited.map { "\($0)" }.joined(separator: ","))]"
    }
    
    private func extractGlucoseJSON() -> String {
        let glucoseStr = currentGlucose != nil ? "\(currentGlucose!)" : "null"
        let trendStr = glucoseTrend != nil ? "\"\(glucoseTrend!)\"" : "null"
        let dateStr = glucoseDate != nil ? "\"\(dateFormatter.string(from: glucoseDate!))\"" : "null"
        
        return """
        {"glucose":\(glucoseStr),"unit":"\(glucoseUnit)","trend":\(trendStr),"date":\(dateStr),"isStale":\(isGlucoseStale())}
        """
    }
    
    private func extractPumpJSON() -> String {
        let reservoirStr = reservoirLevel != nil ? "\(reservoirLevel!)" : "null"
        let batteryStr = batteryPercentage != nil ? "\(batteryPercentage!)" : "null"
        
        return """
        {"reservoir":\(reservoirStr),"battery":\(batteryStr)}
        """
    }
    
    private func extractLoopJSON() -> String {
        let iobStr = iob != nil ? "\(iob!)" : "null"
        let cobStr = cob != nil ? "\(cob!)" : "null"
        let closedLoopStr = isClosedLoop.map { "\($0)" } ?? "null"
        let bolusStr = recommendedBolus != nil ? "\(recommendedBolus!)" : "null"
        
        return """
        {"isClosedLoop":\(closedLoopStr),"iob":\(iobStr),"cob":\(cobStr),"recommendedBolus":\(bolusStr)}
        """
    }
}

// MARK: - GlucoseTrend Extension

extension GlucoseTrend {
    /// Arrow symbol for Pebble display
    var symbol: String {
        switch self {
        case .upUpUp: return "↑↑↑"
        case .upUp: return "↑↑"
        case .up: return "↑"
        case .flat: return "→"
        case .down: return "↓"
        case .downDown: return "↓↓"
        case .downDownDown: return "↓↓↓"
        @unknown default: return "?"
        }
    }
}
