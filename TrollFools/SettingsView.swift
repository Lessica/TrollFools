//
//  SettingsView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/28.
//

import SwiftUI

struct SettingsView: View {
    let app: App

    init(_ app: App) {
        self.app = app
        self._useWeakReference = AppStorage(wrappedValue: true, "UseWeakReference-\(app.id)")
        self._preferMainExecutable = AppStorage(wrappedValue: false, "PreferMainExecutable-\(app.id)")
    }

    @AppStorage var useWeakReference: Bool
    @AppStorage var preferMainExecutable: Bool

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle(NSLocalizedString("Use Weak Reference", comment: ""), systemImage: "link", isOn: $useWeakReference)
                    Toggle(NSLocalizedString("Prefer Main Executable", comment: ""), systemImage: "doc.badge.gearshape", isOn: $preferMainExecutable)
                } header: {
                    Text(NSLocalizedString("Injection", comment: ""))
                } footer: {
                    Text(NSLocalizedString("If you do not know what these options mean, please do not change them.", comment: ""))
                }
            }
            .navigationTitle(NSLocalizedString("Advanced Settings", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
