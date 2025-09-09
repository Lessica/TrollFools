//
//  App+Ads.swift
//  TrollFools
//
//  Created by Rachel on 9/9/2025.
//

import Foundation

extension App {
    static let advertisementApp: App = {
        [
            App(
                id: NSLocalizedString("Record your phone calls like never before.", comment: ""),
                name: NSLocalizedString("TrollRecorder", comment: ""),
                type: "System",
                teamID: "GXZ23M5TP2",
                url: URL(string: "https://havoc.app/package/trollrecorder")!,
                alternateIcon: .init(named: "tricon-default"),
                isAdvertisement: true
            ),
            App(
                id: NSLocalizedString("Bringing back the most advanced system and security analysis tool.", comment: ""),
                name: NSLocalizedString("Reveil", comment: ""),
                type: "System",
                teamID: "GXZ23M5TP2",
                url: URL(string: "https://havoc.app/package/reveil")!,
                alternateIcon: .init(named: "reveil-default"),
                isAdvertisement: true
            ),
            App(
                id: NSLocalizedString("An awesome music visualizer.", comment: ""),
                name: NSLocalizedString("Letterpress", comment: ""),
                type: "System",
                teamID: "GXZ23M5TP2",
                url: URL(string: "https://havoc.app/package/letterpress")!,
                alternateIcon: .init(named: "letter-default"),
                isAdvertisement: true
            ),
            App(
                id: NSLocalizedString("Full-Fledged Automation Framework for TrollStore.", comment: ""),
                name: NSLocalizedString("XXTouch Elite TS", comment: ""),
                type: "System",
                teamID: "GXZ23M5TP2",
                url: URL(string: "https://havoc.app/package/xxtouchelitets")!,
                alternateIcon: .init(named: "elite-default"),
                isAdvertisement: true
            ),
            App(
                id: NSLocalizedString("Fast, feature-rich VNC server for iOS: remote control made simple.", comment: ""),
                name: NSLocalizedString("TrollVNC", comment: ""),
                type: "System",
                teamID: "GXZ23M5TP2",
                url: URL(string: "https://havoc.app/package/trollvnc")!,
                alternateIcon: .init(named: "vnc-default"),
                isAdvertisement: true
            ),
        ].randomElement()!
    }()
}
