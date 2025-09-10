//
//  CodableStorage.swift
//  TRApp
//
//  Created by Lessica on 2024/3/22.
//

import Combine
import Foundation

private let jsonEncoder = JSONEncoder()
private let jsonDecoder = JSONDecoder()

protocol PersistReadWriteStorageProvider {
    func value(forKey: String) -> Data?
    func setValue(_ data: Data?, forKey: String)
}

class UserDefaultsStorageProvider: PersistReadWriteStorageProvider {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func value(forKey key: String) -> Data? {
        userDefaults.data(forKey: key)
    }

    func setValue(_ data: Data?, forKey key: String) {
        userDefaults.set(data, forKey: key)
    }
}

@propertyWrapper
struct CodableStorage<ValueB: Codable> {
    let primaryKey: String
    let secondaryKey: String?
    let defaultValue: ValueB
    var storage: PersistReadWriteStorageProvider

    init(key: String, defaultValue: ValueB, storage: PersistReadWriteStorageProvider = UserDefaultsStorageProvider()) {
        if key.contains("/") {
            let keyComps = key.components(separatedBy: "/")
            primaryKey = keyComps.first!
            secondaryKey = keyComps.last!
        } else {
            primaryKey = key
            secondaryKey = nil
        }
        self.defaultValue = defaultValue
        self.storage = storage
    }

    var wrappedValue: ValueB {
        get {
            guard let read = storage.value(forKey: primaryKey) else {
                return defaultValue
            }
            if let secondaryKey {
                if let objectList = try? jsonDecoder.decode([String: ValueB].self, from: read),
                   let object = objectList[secondaryKey]
                {
                    return object
                }
            } else if let object = try? jsonDecoder.decode(ValueB.self, from: read) {
                return object
            }
            return defaultValue
        }
        set {
            save(value: newValue)
        }
    }

    func save(value: ValueB) {
        do {
            let data: Data
            if let secondaryKey {
                var mutableObjectList: [String: ValueB] = if let read = storage.value(forKey: primaryKey) {
                    try jsonDecoder.decode([String: ValueB].self, from: read)
                } else {
                    [:]
                }
                mutableObjectList[secondaryKey] = value
                data = try jsonEncoder.encode(mutableObjectList)
            } else {
                data = try jsonEncoder.encode(value)
            }
            storage.setValue(data, forKey: primaryKey)
        } catch {
            storage.setValue(nil, forKey: primaryKey)
        }
    }
}
