import Foundation

public func stickyLog(_ content: Any) {
    if Sticky.shared.configuration.logging {
        if let message = content as? String {
            NSLog("sticky_log_output:  \(message)")
        }
    }
}

public class Sticky {
    public static let shared = Sticky()
    
    internal var registeredNotifications: [Persistable.Type] = []
    
    internal var configuration: StickyConfiguration {
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
    }
    
    private func clearContentsOfDirectory() {
        FileHandler.clear()
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
                logging: configuration.logging
            )
        }
    }
}
