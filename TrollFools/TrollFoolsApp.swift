//
//  TrollFoolsApp.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import SwiftUI

let gTrollFoolsIdentifier = "wiki.qaq.TrollFools"
let gTrollFoolsErrorDomain = "\(gTrollFoolsIdentifier).error"

@main
struct TrollFoolsApp: SwiftUI.App {

    init() {
        try? FileManager.default.removeItem(at: InjectorV3.temporaryRoot)
    }

    var body: some Scene {
        WindowGroup {
            AppListView()
                .environmentObject(AppListModel())
        }
    }
}
