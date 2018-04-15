import Foundation

public func stickyLog(_ content: Any) {
    if Sticky.shared.configuration.logging {
        if let message = content as? String {
            NSLog("sticky_log_output:  \(message)")
        }
    }
}

public class Sticky {
    let userDefaultsSchemaVersionKey = "schemaVersion"
    
    public static let shared = Sticky()
    
    public var currentSchemaVersion: Int {
        get {
            return UserDefaults.standard.integer(forKey: userDefaultsSchemaVersionKey)
        }
        set {
            stickyLog("Version changed from \(currentSchemaVersion) to \(newValue)")
            UserDefaults.standard.set(newValue, forKey: userDefaultsSchemaVersionKey)
        }
    }
    
    public var configuration: StickyConfiguration {
        return configurationSettings.configuration
    }
    private var configurationSettings: StickyConfigurationSettings {
        didSet {
            if case .custom(let config) = configurationSettings {
                if config.clearDirectory {
                    clearContentsOfDirectory()
                }
            }
            stickyLog("PATH= \(Sticky.shared.configuration.localDirectory.path)")
        }
    }
    
    private init(with configurationSettings: StickyConfigurationSettings = .default) {
        self.configurationSettings = configurationSettings
    }
    
    public static func configure(with config: StickyConfigurationSettings) {
        Sticky.shared.configurationSettings = config
        if let rollback = config.configuration.rollbackToSchemaVersion {
            Sticky.shared.incrementSchemaVersion(to: rollback)
        }
    }
    
    private func clearContentsOfDirectory() {
        FileHandler.clear()
    }
    
    internal func incrementSchemaVersion(to version: Int) {
        currentSchemaVersion = version
    }
}

public enum StickyConfigurationSettings {
    case `default`
    case custom(StickyConfiguration)
    
    var configuration: StickyConfiguration {
        switch self {
        case .default:
            return StickyConfiguration()
        case .custom(let configuration):
            return StickyConfiguration(
                localDirectory: configuration.localDirectory,
                preloadCache: configuration.preloadCache,
                fileExtensionName: configuration.fileExtensionName,
                clearDirectory: configuration.clearDirectory,
                async: configuration.async,
                logging: configuration.logging,
                rollbackToSchemaVersion: configuration.rollbackToSchemaVersion
            )
        }
    }
}
