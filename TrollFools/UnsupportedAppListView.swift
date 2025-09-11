//
//  UnsupportedAppListView.swift
//  TrollFools
//
//  Created by Z on 2025/9/12.
//

import SwiftUI

struct UnsupportedAppListView: View {
    let unsupportedApps: [App]
    @Binding var isPresented: Bool

    init(unsupportedApps: [App], isPresented: Binding<Bool>) {
        self.unsupportedApps = unsupportedApps
        self._isPresented = isPresented
    }
    
    var body: some View {
        NavigationView {
            List(unsupportedApps) { app in
                AppListCell(app: app)
            }
            .listStyle(.insetGrouped)
            .navigationTitle(NSLocalizedString("Unsupported Applications", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("Done", comment: "")) {
                        isPresented = false
                    }
                }
            }
        }
    }
}
