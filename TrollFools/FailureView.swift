//
//  FailureView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import SwiftUI

struct FailureView: View {

    let title: String
    let error: Error?

    var logFileURL: URL? {
        (error as? NSError)?.userInfo[NSURLErrorKey] as? URL
    }

    @State private var isLogsPresented = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.red)

            Text(title)
                .font(.title)
                .bold()

            if let error {
                Text(error.localizedDescription)
                    .font(.title3)
            }

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
    FailureView(
        title: "Hello, World!",
        error: nil
    )
}
