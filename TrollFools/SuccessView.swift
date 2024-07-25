//
//  SuccessView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import SwiftUI

struct SuccessView: View {
    let title: String

    @StateObject var vm = AppListModel.shared
    @StateObject var filter = FilterOptions()

    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)
                
                Text(title)
                    .font(.title)
                    .bold()
            }
            .padding()
            .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    SuccessView(title: "Hello, World!")
}
