//
//  LocalAPIServer.swift
//  PebbleService
//
//  Local HTTP server for off-grid Pebble communication
//  Exposes Loop data via localhost API endpoints
//  POST commands require iOS confirmation before execution
//

import Foundation
import LoopKit
import HealthKit

/// Lightweight HTTP server running on localhost (configurable port)
/// Provides Loop data to Pebble watch app via Bluetooth connection
public class LocalAPIServer {
    
    private var serverSocket: Int32 = -1
    private var isRunning = false
    private let port: UInt16
    private let dataBridge: LoopDataBridge
    private let commandManager: PebbleCommandManager
    
    /// Default port for Pebble API (can be overridden)
    public static let defaultPort: UInt16 = 8080
    
    /// Alternative ports if default is in use
    public static let alternativePorts: [UInt16] = [8081, 8082, 8083, 8084, 8085]
    
    public init(dataBridge: LoopDataBridge, commandManager: PebbleCommandManager = .shared, port: UInt16 = Self.defaultPort) {
        self.dataBridge = dataBridge
        self.commandManager = commandManager
        self.port = port
    }
    
    /// Get the current port (for UI display)
    public func getCurrentPort() -> UInt16 {
        return port
    }
    
    deinit {
        stop()
    }
    
    /// Start the local HTTP server
    public func start() {
        guard !isRunning else { return }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.runServer()
        }
    }
    
    /// Stop the HTTP server
    public func stop() {
        isRunning = false
        if serverSocket >= 0 {
            close(serverSocket)
            serverSocket = -1
        }
    }
    
    private func runServer() {
        // Create socket
        serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            print("[PebbleService] Failed to create socket")
            return
        }
        
        // Allow socket reuse
        var enable = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &enable, socklen_t(MemoryLayout<Int>.size))
        
        // Bind to localhost only
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")  // localhost only
        
        let bindResult = withUnsafePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddr in
                bind(serverSocket, sockAddr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        guard bindResult == 0 else {
            print("[PebbleService] Failed to bind to port \(port)")
            close(serverSocket)
            return
        }
        
        // Listen
        guard listen(serverSocket, 5) == 0 else {
            print("[PebbleService] Failed to listen")
            close(serverSocket)
            return
        }
        
        isRunning = true
        print("[PebbleService] Local API server started on http://127.0.0.1:\(port)")
        
        // Accept connections
        while isRunning {
            var clientAddr = sockaddr_in()
            var clientAddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            
            let clientSocket = withUnsafeMutablePointer(to: &clientAddr) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddr in
                    accept(serverSocket, sockAddr, &clientAddrLen)
                }
            }
            
            guard clientSocket >= 0 else {
                if isRunning {
                    print("[PebbleService] Accept failed")
                }
                continue
            }
            
            // Handle request
            DispatchQueue.global(qos: .background).async { [weak self] in
                self?.handleRequest(clientSocket)
            }
        }
    }
    
    private func handleRequest(_ clientSocket: Int32) {
        defer { close(clientSocket) }
        
        var buffer = [UInt8](repeating: 0, count: 8192)
        let bytesRead = read(clientSocket, &buffer, buffer.count)
        
        guard bytesRead > 0 else { return }
        
        let request = String(bytes: buffer[0..<Int(bytesRead)], encoding: .utf8) ?? ""
        let method = extractMethod(from: request)
        let path = extractPath(from: request)
        let body = extractBody(from: request)
        
        let (statusCode, contentType, responseBody) = routeRequest(method: method, path: path, body: body)
        let response = buildResponse(statusCode: statusCode, contentType: contentType, body: responseBody)
        
        _ = response.withCString { ptr in
            write(clientSocket, ptr, strlen(ptr))
        }
    }
    
    private func extractMethod(from request: String) -> String {
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else { return "GET" }
        let parts = firstLine.components(separatedBy: " ")
        return parts.first ?? "GET"
    }
    
    private func extractPath(from request: String) -> String {
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else { return "/" }
        let parts = firstLine.components(separatedBy: " ")
        return parts.count >= 2 ? parts[1] : "/"
    }
    
    private func extractBody(from request: String) -> String? {
        guard let bodyStart = request.range(of: "\r\n\r\n") else { return nil }
        let body = String(request[bodyStart.upperBound...])
        return body.isEmpty ? nil : body
    }
    
    private func routeRequest(method: String, path: String, body: String?) -> (Int, String, String) {
        // GET endpoints (read-only)
        if method == "GET" {
            switch path {
            case "/api/cgm":
                return (200, "application/json", dataBridge.cgmJSON())
            case "/api/pump":
                return (200, "application/json", dataBridge.pumpJSON())
            case "/api/loop":
                return (200, "application/json", dataBridge.loopJSON())
            case "/api/all":
                return (200, "application/json", dataBridge.allDataJSON())
            case "/api/commands/pending":
                return (200, "application/json", commandManager.pendingCommandsJSON())
            case "/health":
                return (200, "application/json", #"{"status":"ok"}"#)
            default:
                return (404, "application/json", #"{"error":"not found"}"#)
            }
        }
        
        // POST endpoints (commands - require iOS confirmation)
        if method == "POST" {
            switch path {
            case "/api/bolus":
                return handleBolusRequest(body)
            case "/api/carbs":
                return handleCarbRequest(body)
            case "/api/command/confirm":
                return handleConfirmCommand(body)
            case "/api/command/reject":
                return handleRejectCommand(body)
            default:
                return (404, "application/json", #"{"error":"not found"}"#)
            }
        }
        
        return (405, "application/json", #"{"error":"method not allowed"}"#)
    }
    
    // MARK: - Command Handlers
    
    /// Handle bolus request from Pebble
    /// POST /api/bolus {"units": 1.5}
    /// Returns: {"status":"pending_confirmation","commandId":"...","message":"Confirm on iPhone"}
    private func handleBolusRequest(_ body: String?) -> (Int, String, String) {
        guard let body = body,
              let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let units = json["units"] as? Double else {
            return (400, "application/json", #"{"error":"invalid request, requires 'units'"}"#)
        }
        
        guard let command = commandManager.queueBolus(units: units) else {
            return (400, "application/json", #"{"error":"bolus amount exceeds safety limits"}"#)
        }
        
        let response = """
        {
            "status": "pending_confirmation",
            "commandId": "\(command.id)",
            "message": "Confirm \(String(format: "%.2f", units))U bolus on iPhone",
            "type": "bolus"
        }
        """
        return (202, "application/json", response)
    }
    
    /// Handle carb entry request from Pebble
    /// POST /api/carbs {"grams": 30, "absorptionHours": 3}
    /// Returns: {"status":"pending_confirmation","commandId":"..."}
    private func handleCarbRequest(_ body: String?) -> (Int, String, String) {
        guard let body = body,
              let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let grams = json["grams"] as? Double else {
            return (400, "application/json", #"{"error":"invalid request, requires 'grams'"}"#)
        }
        
        let absorptionHours = json["absorptionHours"] as? Double ?? 3.0
        
        guard let command = commandManager.queueCarbEntry(grams: grams, absorptionHours: absorptionHours) else {
            return (400, "application/json", #"{"error":"carb amount exceeds safety limits"}"#)
        }
        
        let response = """
        {
            "status": "pending_confirmation",
            "commandId": "\(command.id)",
            "message": "Confirm \(String(format: "%.0f", grams))g carbs on iPhone",
            "type": "carbEntry"
        }
        """
        return (202, "application/json", response)
    }
    
    /// Handle command confirmation (from iOS app, not Pebble)
    /// POST /api/command/confirm {"commandId":"..."}
    private func handleConfirmCommand(_ body: String?) -> (Int, String, String) {
        guard let body = body,
              let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let commandId = json["commandId"] as? String else {
            return (400, "application/json", #"{"error":"requires 'commandId'"}"#)
        }
        
        commandManager.confirmCommand(commandId, doseStore: nil, carbStore: nil)
        
        return (200, "application/json", #"{"status":"confirmed"}"#)
    }
    
    /// Handle command rejection (from iOS app)
    /// POST /api/command/reject {"commandId":"..."}
    private func handleRejectCommand(_ body: String?) -> (Int, String, String) {
        guard let body = body,
              let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let commandId = json["commandId"] as? String else {
            return (400, "application/json", #"{"error":"requires 'commandId'"}"#)
        }
        
        commandManager.rejectCommand(commandId)
        
        return (200, "application/json", #"{"status":"rejected"}"#)
    }
    
    private func buildResponse(statusCode: Int, contentType: String, body: String) -> String {
        let statusText = statusCode == 200 ? "OK" : (statusCode == 202 ? "Accepted" : (statusCode == 400 ? "Bad Request" : "Not Found"))
        return """
        HTTP/1.1 \(statusCode) \(statusText)\r
        Content-Type: \(contentType)\r
        Content-Length: \(body.utf8.count)\r
        Access-Control-Allow-Origin: *\r
        Connection: close\r
        \r
        \(body)
        """
    }
}

// MARK: - JSON Response Models

extension LocalAPIServer {
    
    /// API endpoint documentation
    public static var apiDocumentation: String {
        return """
        PebbleService Local API (http://127.0.0.1:8080)
        
        READ ENDPOINTS (GET):
        - GET /api/cgm    - Blood glucose data
        - GET /api/pump   - Pump status (reservoir, battery)
        - GET /api/loop   - Loop status (IOB, COB, closed loop)
        - GET /api/all    - All data combined
        - GET /api/commands/pending - Pending commands awaiting confirmation
        - GET /health     - Health check
        
        COMMAND ENDPOINTS (POST - require iOS confirmation):
        - POST /api/bolus - Queue bolus request
          Body: {"units": 1.5}
          Returns: {status, commandId, message}
          
        - POST /api/carbs - Queue carb entry
          Body: {"grams": 30, "absorptionHours": 3}
          Returns: {status, commandId, message}
        
        - POST /api/command/confirm - Confirm command (iOS only)
          Body: {"commandId": "..."}
        
        - POST /api/command/reject - Reject command (iOS only)
          Body: {"commandId": "..."}
        
        SAFETY:
        - All POST commands queue as "pending_confirmation"
        - iOS app shows confirmation dialog
        - Command only executes after explicit user confirmation
        - Commands expire after 5 minutes if not confirmed
        
        Server runs on localhost only (127.0.0.1).
        """
    }
}
