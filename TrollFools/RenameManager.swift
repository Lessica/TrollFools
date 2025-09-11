import Foundation
import Combine
import SwiftUI

final class RenameManager: ObservableObject {
    @Published var plugInRenames: [String: String] {
        didSet {
            storage.wrappedValue = plugInRenames
        }
    }
    
    private var storage: CodableStorage<[String: String]>

    init(appId: String) {
        let initialStorage = CodableStorage<[String: String]>(key: "PlugInRenames-\(appId)", defaultValue: [:])
        self.storage = initialStorage
        self.plugInRenames = initialStorage.wrappedValue
    }
}
