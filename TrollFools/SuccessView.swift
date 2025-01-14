//
//  SuccessView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import SwiftUI

struct SuccessView: View {

    let title: String
    let logFileURL: URL?

    @State private var isLogsPresented = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text(title)
                .font(.title)
                .bold()

            if logFileURL != nil {
                Button {
                    isLogsPresented = true
                } label: {
                    Label(NSLocalizedString("View Logs", comment: ""),
                          systemImage: "note.text")
                }
            }
        }
        .padding()
        .multilineTextAlignment(.center)
        .sheet(isPresented: $isLogsPresented) {
            if let logFileURL {
                LogsView(url: logFileURL)
            }
        }
    }
}

#Preview {
    SuccessView(
        title: "Hello, World!",
        logFileURL: nil
    )
}
