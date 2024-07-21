//
//  TrollFoolsApp.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import SwiftUI

let kTrollFoolsErrorDomain = "wiki.qaq.TrollFools.error"

struct TrollFoolsApp: SwiftUI.App {
    var body: some Scene {
        WindowGroup {
            AppListView()
        }
    }
}
