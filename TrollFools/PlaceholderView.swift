//
//  PlaceholderView.swift
//  TrollFools
//
//  Created by 82Flex on 3/17/25.
//

import SwiftUI

struct PlaceholderView: View {
    var body: some View {
        Text(NSLocalizedString("Select an application to view details.", comment: ""))
            .font(.headline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding()
    }
}
