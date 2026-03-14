//
//  LocalAPIServer.swift
//  PebbleService
//
//  Local HTTP server for off-grid Pebble communication
//  Exposes Loop data via localhost API endpoints
//

import Foundation
import LoopKit
import HealthKit

/// Lightweight HTTP server running on localhost:8080
/// Provides Loop data to Pebble watch app via Bluetooth connection
public class LocalAPIServer {
    
    private var serverSocket: Int32 = -1
    private var isRunning = false
    private let port: UInt16 = 8080
    private let dataBridge: LoopDataBridge
    
    public init(dataBridge: LoopDataBridge) {
        self.dataBridge = dataBridge
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
        
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(clientSocket, &buffer, buffer.count)
        
        guard bytesRead > 0 else { return }
        
        let request = String(bytes: buffer[0..<Int(bytesRead)], encoding: .utf8) ?? ""
        let path = extractPath(from: request)
        
        let (statusCode, contentType, body) = routeRequest(path)
        let response = buildResponse(statusCode: statusCode, contentType: contentType, body: body)
        
        _ = response.withCString { ptr in
            write(clientSocket, ptr, strlen(ptr))
        }
    }
    
    private func extractPath(from request: String) -> String {
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else { return "/" }
        let parts = firstLine.components(separatedBy: " ")
        return parts.count >= 2 ? parts[1] : "/"
    }
    
    private func routeRequest(_ path: String) -> (Int, String, String) {
        switch path {
        case "/api/cgm":
            return (200, "application/json", dataBridge.cgmJSON())
        case "/api/pump":
            return (200, "application/json", dataBridge.pumpJSON())
        case "/api/loop":
            return (200, "application/json", dataBridge.loopJSON())
        case "/api/all":
            return (200, "application/json", dataBridge.allDataJSON())
        case "/health":
            return (200, "application/json", #"{"status":"ok"}"#)
        default:
            return (404, "application/json", #"{"error":"not found"}"#)
        }
    }
    
    private func buildResponse(statusCode: Int, contentType: String, body: String) -> String {
        let statusText = statusCode == 200 ? "OK" : "Not Found"
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
        
        Endpoints:
        - GET /api/cgm    - Blood glucose data
        - GET /api/pump   - Pump status (reservoir, battery)
        - GET /api/loop   - Loop status (IOB, COB, closed loop)
        - GET /api/all    - All data combined
        - GET /health     - Health check
        
        All responses are JSON. Server runs on localhost only.
        """
    }
}
