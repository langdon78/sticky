import Foundation
import os

internal enum StickyLogAction {
    case error
    case debug
    case info
    
    var osLogType: OSLogType {
        switch self {
        case .error: return .error
        case .debug: return .debug
        case .info: return .info
        }
    }
}

internal let schemaLog = OSLog(subsystem: "com.sticky.logging", category: "SchemaUpdate")
internal let generalLog = OSLog(subsystem: "com.sticky.logging", category: "General")

internal func stickyLog(_ content: Any,
                      logAction: StickyLogAction = .info,
                      log: OSLog = OSLog(subsystem: "com.sticky.logging", category: "General")) {
    if Sticky.shared.configuration.logging {
        if let message = content as? String {
            os_log("%@", log: log, type: logAction.osLogType, message)
        }
    }
}

internal enum StickyResult {
    case success
    case error(Error)
}

internal enum StickyError: Error, CustomStringConvertible {
    case invalidJson
    
    var description: String {
        switch self {
        case .invalidJson:
            return "JSON is malformed or empty"
        }
    }
}
