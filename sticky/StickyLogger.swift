import Foundation
import os

fileprivate let logSubsystem = "com.sticky.logging"

public enum StickyLogStyle {
    case verbose
    case general
    case schema
    case file
    case none
    
    var logsAllowed: [OSLog] {
        switch self {
        case .verbose: return [schemaLog, fileLog, generalLog]
        case .none: return []
        case .general: return [generalLog]
        case .schema: return [schemaLog]
        case .file: return [fileLog]
        }
    }
}

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

internal let schemaLog = OSLog(subsystem: logSubsystem, category: "SchemaUpdate")
internal let generalLog = OSLog(subsystem: logSubsystem, category: "General")
internal let fileLog = OSLog(subsystem: logSubsystem, category: "FileHandler")

internal func stickyLog(_ content: Any,
                      logAction: StickyLogAction = .info,
                      log: OSLog = OSLog(subsystem: "com.sticky.logging", category: "General")) {
    let logStyle = Sticky.shared.configuration.logStyle
    
    if logStyle.logsAllowed.contains(log) {
        if let message = content as? String {
            os_log("%@", log: log, type: logAction.osLogType, message)
        }
    }
}

internal enum StickyResult {
    case success
    case error(Error)
}

extension StickyResult: Equatable {
    static func == (lhs: StickyResult, rhs: StickyResult) -> Bool {
        switch (lhs, rhs) {
        case (.success, .success):
            return true
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

internal enum StickyError: Error, CustomStringConvertible, Equatable {
    case invalidJson
    case dataFileDoesNotExist(String)
    case noActionTaken
    case emptySchemaFile
    case invalidAction(String?)
    case unableToParseEntityName(String)
    case unableToProcessSchemaFile(String)
    
    var description: String {
        switch self {
        case .invalidJson:
            return "JSON is malformed or empty"
        case .dataFileDoesNotExist(let entity):
            return "Data file for \"\(entity)\" does not exist"
        case .noActionTaken:
            return "No action taken"
        case .emptySchemaFile:
            return "Malformed or empty schema file"
        case .invalidAction(let actionName):
            return "Invalid action \"\(actionName ?? "")\""
        case .unableToParseEntityName(let entityName):
            return "Unable to parse entity name for action \"\(entityName)\""
        case .unableToProcessSchemaFile(let fileName):
            return "Unable to parse json for \(fileName)"
        }
    }
    
    func outputToLog(_ log: OSLog = OSLog(subsystem: "com.sticky.logging", category: "General")) {
        stickyLog(description, logAction: .error, log: log)
    }
}
