import Foundation

class FileHandler {
    var manager: FileManager
    
    init(manager: FileManager = FileManager.default) {
        self.manager = manager
    }
}
