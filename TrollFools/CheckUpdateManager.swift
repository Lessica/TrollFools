//
//  CheckUpdateManager.swift
//  TRApp
//
//  Created by 82Flex on 2024/11/9.
//

import Combine
import DpkgVersion
import Foundation

private let TTAAGG = "CheckUpdateManager"

/// 统一叫做 CheckUpdate
/// 不要用 Upgrade/Updates/CheckForUpdates/UpdateCheck
final class CheckUpdateManager {
    // MARK: - Singleton

    static let shared = CheckUpdateManager()

    // MARK: - Data Models

    struct LatestVersion: Codable {
        let tagName: String // "3.5.4-3287"
        let tipaAssetURLString: String
        let versionString: String // "3.5.4"
        let buildVersionString: String // "3287"
    }

    // MARK: - Published Properties

    let latestVersionSubject = CurrentValueSubject<LatestVersion?, Never>(nil)

    // MARK: - Private Storage Properties

    @CodableStorage(key: "ApplicationLastCheckUpdateAt", defaultValue: Date(timeIntervalSince1970: 0))
    private var lastCheckUpdateAt: Date {
        didSet {
            if lastCheckUpdateAt != oldValue {
                print("\(TTAAGG) : Check update at: \(lastCheckUpdateAt)")
            }
        }
    }

    @CodableStorage(key: "ApplicationLastCheckUpdateResult", defaultValue: nil)
    private var lastCheckUpdateResult: LatestVersion? {
        didSet {
            latestVersionSubject.send(lastCheckUpdateResult)
            if let lastCheckUpdateResult {
                print("\(TTAAGG) : Latest version: \(String(describing: lastCheckUpdateResult))")
            }
        }
    }

    @CodableStorage(key: "ApplicationBlockUpgradeAlertUntil", defaultValue: Date(timeIntervalSince1970: 0))
    private var blockCheckUpdateAlertUntil: Date {
        didSet {
            if blockCheckUpdateAlertUntil != oldValue {
                print("\(TTAAGG) : Block check update alert until: \(blockCheckUpdateAlertUntil)")
            }
        }
    }

    // MARK: - Public Properties

    /// 是否应该弹出更新提醒
    var shouldPopCheckUpdateAlert: Bool {
        blockCheckUpdateAlertUntil < Date()
    }

    /// 是否有新版本可用
    var isNewVersionAvailable: Bool {
        guard let upstreamVersionCompareKey else {
            return false
        }
        return Version.compare(upstreamVersionCompareKey, currentVersionCompareKey) > 0
    }

    // MARK: - Initialization

    private init() {
        latestVersionSubject.send(lastCheckUpdateResult)
        let trollStore = checkTrollStoreAvailability()
        print("\(TTAAGG) : TrollStore availability: \(trollStore)")
    }

    // MARK: - Public Methods

    /// 延迟更新提醒一周
    func delayCheckUpdateAlert() {
        blockCheckUpdateAlertUntil = Date(timeIntervalSinceNow: Constants.updateManagerAlertDelayDuration)
    }

    /// 如果需要的话检查更新
    /// - Parameter completion: 完成回调
    func checkUpdateIfNeeded(completion: ((LatestVersion?, Error?) -> Void)? = nil) {
        guard isCheckUpdateNeeded else {
            print("\(TTAAGG) : Check update is not needed.")
            if isNewVersionAvailable {
                completion?(lastCheckUpdateResult, nil)
            } else {
                completion?(nil, nil)
            }
            return
        }

        lastCheckUpdateAt = Date()
        performUpdateCheck(completion: completion)
    }

    /// 执行升级
    func executeUpgrade() {
        guard isNewVersionAvailable else { return }

        guard let upstreamProductURLString = lastCheckUpdateResult?.tipaAssetURLString,
              let upstreamProductURL = URL(string: upstreamProductURLString)
        else {
            return
        }

        let installURLString = Constants.trollStoreInstallURLScheme + upstreamProductURLString
        let installURL = URL(string: installURLString)

        if let installURL,
           UIApplication.shared.canOpenURL(installURL),
           checkTrollStoreAvailability()
        {
            UIApplication.shared.open(installURL)
        } else {
            UIApplication.shared.open(upstreamProductURL)
        }
    }

    // MARK: - Private Properties

    /// 是否需要检查更新
    private var isCheckUpdateNeeded: Bool {
        let updateCheckIntervalSinceNow = Date().timeIntervalSince(lastCheckUpdateAt)

        // 允许检查：自上次检查更新以来已经过去了 2 小时
        if abs(updateCheckIntervalSinceNow) > Constants.updateManagerCheckInterval {
            return true
        }

        // 允许检查：或自上次检查更新以来已经过去了 90 秒，但上次检查失败
        if abs(updateCheckIntervalSinceNow) > Constants.updateManagerRetryInterval, lastCheckUpdateResult == nil {
            return true
        }

        return false
    }

    /// 上游版本比较键
    private var upstreamVersionCompareKey: String? {
        guard let lastCheckUpdateResult else {
            return nil
        }
        return [lastCheckUpdateResult.versionString, lastCheckUpdateResult.buildVersionString].joined(separator: "-")
    }

    /// 当前版本比较键
    private var currentVersionCompareKey: String {
        // eg: "1.0-1"
        [Constants.gAppVersion, Constants.gAppBuildVersion].joined(separator: "-")
    }

    // MARK: - Private Methods

    /// 执行更新检查
    /// - Parameter completion: 完成回调
    private func performUpdateCheck(completion: ((LatestVersion?, Error?) -> Void)?) {
        let request = URLRequest(
            url: Constants.gUpdateCheckEndpoint,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData
        )

        URLSession.shared.dataTask(with: request) { [weak self] jsonData, _, error in
            self?.handleUpdateCheckResponse(jsonData: jsonData, error: error, completion: completion)
        }.resume()
    }

    /// 处理更新检查响应
    /// - Parameters:
    ///   - jsonData: 响应数据
    ///   - error: 错误
    ///   - completion: 完成回调
    private func handleUpdateCheckResponse(jsonData: Data?, error: Error?, completion: ((LatestVersion?, Error?) -> Void)?) {
        if let error {
            print("\(TTAAGG) : Check update failed: \(error)")
            completion?(nil, error)
            return
        }

        guard let jsonData else {
            print("\(TTAAGG) : Check update failed: No response data.")
            completion?(nil, error)
            return
        }

        guard let versionList = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: AnyHashable]] else {
            print("\(TTAAGG) : Check update failed: Invalid response data.")
            completion?(nil, error)
            return
        }

        if let latestVersion = parseLatestVersion(from: versionList) {
            lastCheckUpdateResult = latestVersion
            guard Version.compare(latestVersion.tagName, currentVersionCompareKey) > 0 else {
                print("\(TTAAGG) : No new version available. Current version is up to date.")
                completion?(nil, nil)
                return
            }
            completion?(latestVersion, nil)
        } else {
            print("\(TTAAGG) : Check update failed: No available version.")
            completion?(nil, nil)
        }
    }

    /// 解析最新版本信息
    /// - Parameter versionList: 版本列表
    /// - Returns: 最新版本信息
    private func parseLatestVersion(from versionList: [[String: AnyHashable]]) -> LatestVersion? {
        var latestTagName = "0"
        var latestPackageURLString: String?

        for versionDict in versionList {
            // 跳过预发布版本
            if let prerelease = versionDict["prerelease"] as? Bool, prerelease {
                continue
            }

            guard var tagName = versionDict["tag_name"] as? String else {
                continue
            }

            // 移除版本号前缀 "v"
            if tagName.hasPrefix("v") {
                tagName.removeFirst()
            }

            // 只处理更新的版本
            guard Version.compare(tagName, latestTagName) > 0 else {
                continue
            }

            // 查找 .tipa 文件
            guard let packageURLString = findTipaAssetURL(in: versionDict) else {
                continue
            }

            latestTagName = tagName
            latestPackageURLString = packageURLString
        }

        guard let latestPackageURLString else {
            return nil
        }

        return createLatestVersion(tagName: latestTagName, packageURLString: latestPackageURLString)
    }

    /// 在版本字典中查找 .tipa 文件的下载链接
    /// - Parameter versionDict: 版本字典
    /// - Returns: .tipa 文件的下载链接
    private func findTipaAssetURL(in versionDict: [String: AnyHashable]) -> String? {
        guard let assetList = versionDict["assets"] as? [[String: Any]] else {
            return nil
        }

        for assetDict in assetList {
            guard let assetName = assetDict["name"] as? String,
                  assetName.hasSuffix("tipa"),
                  let downloadURLString = assetDict["browser_download_url"] as? String
            else {
                continue
            }
            return downloadURLString
        }

        return nil
    }

    /// 创建最新版本对象
    /// - Parameters:
    ///   - tagName: 标签名
    ///   - packageURLString: 包下载链接
    /// - Returns: 最新版本对象
    private func createLatestVersion(tagName: String, packageURLString: String) -> LatestVersion? {
        var latestTagComponents = tagName.components(separatedBy: "-")
        if latestTagComponents.count == 1 {
            latestTagComponents.append("1")
        }

        guard let latestVersionString = latestTagComponents.first,
              let latestVersionBuild = latestTagComponents.last
        else {
            print("\(TTAAGG) : Check update failed: Invalid version.")
            return nil
        }

        return LatestVersion(
            tagName: tagName,
            tipaAssetURLString: packageURLString,
            versionString: latestVersionString,
            buildVersionString: latestVersionBuild
        )
    }

    /// 检查 TrollStore 可用性
    /// - Returns: TrollStore 是否可用
    private func checkTrollStoreAvailability() -> Bool {
        let applicationProxyForIdentifierSelector = NSSelectorFromString("applicationProxyForIdentifier:")
        guard let applicationProxyCls = NSClassFromString("LSApplicationProxy"),
              applicationProxyCls.responds(to: applicationProxyForIdentifierSelector)
        else {
            return false
        }

        let method = class_getClassMethod(applicationProxyCls, applicationProxyForIdentifierSelector)
        guard let method else {
            return false
        }

        typealias ApplicationProxyFunction = @convention(c) (AnyClass, Selector, NSString) -> Unmanaged<AnyObject>?
        let implementation = method_getImplementation(method)
        let function = unsafeBitCast(implementation, to: ApplicationProxyFunction.self)

        guard let applicationProxy = function(
            applicationProxyCls,
            applicationProxyForIdentifierSelector,
            Constants.trollStoreIdentifier as NSString
        )?.takeUnretainedValue() as? NSObject else {
            return false
        }

        guard let bundleURL = applicationProxy.value(forKey: "bundleURL") as? URL,
              let appBundle = Bundle(url: bundleURL),
              let urlTypes = appBundle.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]],
              !urlTypes.isEmpty
        else {
            return false
        }

        return true
    }
}
