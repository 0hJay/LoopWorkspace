//
//  PebbleCommandManager.swift
//  PebbleService
//
//  Manages command queue with iOS confirmation for Pebble-originated actions
//  Safety: All bolus/carb commands require explicit confirmation on iPhone
//

import Foundation
import LoopKit
import HealthKit
import os.log

/// Types of commands that can be sent from Pebble
public enum PebbleCommandType: String, Codable {
    case bolus
    case carbEntry
}

/// Status of a pending command
public enum PebbleCommandStatus: String, Codable {
    case pendingConfirmation
    case confirmed
    case rejected
    case executed
    case failed
    case expired
}

/// A command queued from Pebble awaiting iOS confirmation
public struct PebbleCommand: Codable {
    public let id: String
    public let type: PebbleCommandType
    public let timestamp: Date
    public let parameters: [String: String]
    public var status: PebbleCommandStatus
    public var confirmedAt: Date?
    public var executedAt: Date?
    public var errorMessage: String?
    
    public init(type: PebbleCommandType, parameters: [String: String]) {
        self.id = UUID().uuidString
        self.type = type
        self.timestamp = Date()
        self.parameters = parameters
        self.status = .pendingConfirmation
    }
    
    /// Command is expired if pending for more than 5 minutes
    public var isExpired: Bool {
        return status == .pendingConfirmation && Date().timeIntervalSince(timestamp) > 300
    }
    
    /// Human-readable description for confirmation UI
    public var confirmationMessage: String {
        switch type {
        case .bolus:
            let units = parameters["units"] ?? "?"
            return "Pebble requests bolus: \(units) units"
        case .carbEntry:
            let grams = parameters["grams"] ?? "?"
            let absorption = parameters["absorptionHours"] ?? "3"
            return "Pebble requests carb entry: \(grams)g (\(absorption)h absorption)"
        }
    }
}

/// Delegate protocol for command confirmation UI
public protocol PebbleCommandConfirmationDelegate: AnyObject {
    func pendingCommandRequiresConfirmation(_ command: PebbleCommand)
    func commandExecuted(_ command: PebbleCommand)
    func commandFailed(_ command: PebbleCommand, error: String)
}

/// Manages Pebble-originated commands with iOS confirmation
public class PebbleCommandManager {
    
    public static let shared = PebbleCommandManager()
    
    private let log = OSLog(category: "PebbleCommandManager")
    private var pendingCommands: [String: PebbleCommand] = [:]
    private let queue = DispatchQueue(label: "com.loopkit.PebbleCommandManager")
    
    /// Delegate for confirmation UI
    public weak var confirmationDelegate: PebbleCommandConfirmationDelegate?
    
    /// Maximum bolus allowed (safety limit)
    public var maxBolus: Double = 10.0
    
    /// Maximum carbs allowed per entry
    public var maxCarbs: Double = 200.0
    
    private init() {}
    
    // MARK: - Command Creation
    
    /// Queue a bolus command from Pebble (requires confirmation)
    public func queueBolus(units: Double) -> PebbleCommand? {
        // Safety check: validate bolus amount
        guard units > 0, units <= maxBolus else {
            log.error("Bolus rejected: \(units)U exceeds limits (0-\(maxBolus)U)")
            return nil
        }
        
        let command = PebbleCommand(
            type: .bolus,
            parameters: ["units": String(format: "%.2f", units)]
        )
        
        queue.sync {
            pendingCommands[command.id] = command
        }
        
        log.info("Bolus command queued: \(units)U, awaiting confirmation")
        
        // Notify delegate to show confirmation UI
        DispatchQueue.main.async { [weak self] in
            self?.confirmationDelegate?.pendingCommandRequiresConfirmation(command)
        }
        
        return command
    }
    
    /// Queue a carb entry command from Pebble (requires confirmation)
    public func queueCarbEntry(grams: Double, absorptionHours: Double = 3.0) -> PebbleCommand? {
        // Safety check: validate carb amount
        guard grams > 0, grams <= maxCarbs else {
            log.error("Carb entry rejected: \(grams)g exceeds limits (0-\(maxCarbs)g)")
            return nil
        }
        
        let command = PebbleCommand(
            type: .carbEntry,
            parameters: [
                "grams": String(format: "%.1f", grams),
                "absorptionHours": String(format: "%.1f", absorptionHours)
            ]
        )
        
        queue.sync {
            pendingCommands[command.id] = command
        }
        
        log.info("Carb entry queued: \(grams)g, awaiting confirmation")
        
        // Notify delegate to show confirmation UI
        DispatchQueue.main.async { [weak self] in
            self?.confirmationDelegate?.pendingCommandRequiresConfirmation(command)
        }
        
        return command
    }
    
    // MARK: - Command Confirmation
    
    /// Confirm a pending command (called from iOS UI)
    public func confirmCommand(_ commandId: String, doseStore: DoseStore?, carbStore: CarbStore?) {
        queue.sync {
            guard var command = pendingCommands[commandId],
                  command.status == .pendingConfirmation else {
                log.error("Cannot confirm command \(commandId): not found or not pending")
                return
            }
            
            command.status = .confirmed
            command.confirmedAt = Date()
            pendingCommands[commandId] = command
            
            // Execute the command
            executeCommand(&command, doseStore: doseStore, carbStore: carbStore)
            
            pendingCommands[commandId] = command
        }
    }
    
    /// Reject a pending command (called from iOS UI)
    public func rejectCommand(_ commandId: String) {
        queue.sync {
            guard var command = pendingCommands[commandId],
                  command.status == .pendingConfirmation else {
                return
            }
            
            command.status = .rejected
            pendingCommands[commandId] = command
            
            log.info("Command \(commandId) rejected by user")
        }
    }
    
    // MARK: - Command Execution
    
    private func executeCommand(_ command: inout PebbleCommand, doseStore: DoseStore?, carbStore: CarbStore?) {
        switch command.type {
        case .bolus:
            executeBolus(&command, doseStore: doseStore)
        case .carbEntry:
            executeCarbEntry(&command, carbStore: carbStore)
        }
    }
    
    private func executeBolus(_ command: inout PebbleCommand, doseStore: DoseStore?) {
        guard let unitsStr = command.parameters["units"],
              let units = Double(unitsStr) else {
            command.status = .failed
            command.errorMessage = "Invalid bolus amount"
            return
        }
        
        // Note: Actual bolus delivery should be handled by Loop's normal bolus flow
        // This creates a recommended bolus that Loop can act upon
        log.info("Executing confirmed bolus: \(units)U")
        
        // In production, this would integrate with Loop's dose initiation
        // For now, mark as executed and notify
        command.status = .executed
        command.executedAt = Date()
        
        DispatchQueue.main.async { [weak self] in
            self?.confirmationDelegate?.commandExecuted(command)
        }
    }
    
    private func executeCarbEntry(_ command: inout PebbleCommand, carbStore: CarbStore?) {
        guard let gramsStr = command.parameters["grams"],
              let grams = Double(gramsStr),
              let absorptionStr = command.parameters["absorptionHours"],
              let absorptionHours = Double(absorptionStr) else {
            command.status = .failed
            command.errorMessage = "Invalid carb entry"
            return
        }
        
        log.info("Executing confirmed carb entry: \(grams)g, \(absorptionHours)h absorption")
        
        // Create carb entry
        let entry = NewCarbEntry(
            quantity: HKQuantity(unit: .gram(), doubleValue: grams),
            startDate: Date(),
            foodType: "Pebble Entry",
            absorptionTime: .hours(absorptionHours),
            createdByCurrentApp: true,
            externalID: "pebble-\(command.id)"
        )
        
        // Store would be called here in production
        // carbStore?.addCarbEntry(entry) { ... }
        
        command.status = .executed
        command.executedAt = Date()
        
        DispatchQueue.main.async { [weak self] in
            self?.confirmationDelegate?.commandExecuted(command)
        }
    }
    
    // MARK: - Query Methods
    
    /// Get all pending commands awaiting confirmation
    public func getPendingCommands() -> [PebbleCommand] {
        return queue.sync {
            return pendingCommands.values
                .filter { $0.status == .pendingConfirmation && !$0.isExpired }
                .sorted { $0.timestamp < $1.timestamp }
        }
    }
    
    /// Get command by ID
    public func getCommand(_ id: String) -> PebbleCommand? {
        return queue.sync {
            return pendingCommands[id]
        }
    }
    
    /// Clean up expired commands
    public func cleanupExpired() {
        queue.sync {
            for (id, command) in pendingCommands {
                if command.isExpired {
                    pendingCommands[id]?.status = .expired
                    log.info("Command \(id) expired")
                }
            }
            // Remove old executed/expired/rejected commands
            pendingCommands = pendingCommands.filter { 
                $0.value.status == .pendingConfirmation || 
                ($0.value.status == .confirmed && $0.value.executedAt == nil)
            }
        }
    }
}

// MARK: - JSON API Response

extension PebbleCommandManager {
    
    /// Get pending commands as JSON for Pebble to display status
    public func pendingCommandsJSON() -> String {
        let pending = getPendingCommands()
        
        if pending.isEmpty {
            return #"{"pending":[]}"#
        }
        
        let commandsJSON = pending.map { cmd in
            #"{"id":"\#(cmd.id)","type":"\#(cmd.type.rawValue)","message":"\#(cmd.confirmationMessage)"}"#
        }.joined(separator: ",")
        
        return #"{"pending":[\#(commandsJSON)]}"#
    }
}
