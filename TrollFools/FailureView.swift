//
//  FailureView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import SwiftUI

struct FailureView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.red)

            Text(title)
                .font(.title)
                .bold()
                .multilineTextAlignment(.center)

            Text(message)
                .font(.title3)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    FailureView(title: "Hello, World!", message: "This is a failure.")
}
