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
        self._injectStrategy = AppStorage(wrappedValue: .lexicographic, "InjectStrategy-\(app.id)")
    }

    @AppStorage var useWeakReference: Bool
    @AppStorage var preferMainExecutable: Bool
    @AppStorage var injectStrategy: InjectorV3.Strategy

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker(NSLocalizedString("Injection Strategy", comment: ""), selection: $injectStrategy) {
                        ForEach(InjectorV3.Strategy.allCases, id: \.self) { strategy in
                            Text(strategy.localizedDescription).tag(strategy)
                        }
                    }
                    Toggle(NSLocalizedString("Prefer Main Executable", comment: ""), isOn: $preferMainExecutable)
                    Toggle(NSLocalizedString("Use Weak Reference", comment: ""), isOn: $useWeakReference)
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
