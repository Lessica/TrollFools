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

    var possibleApp: App? {
        [
            App(
                id: NSLocalizedString("A pure TrollStore software channel!", comment: ""),
                name: NSLocalizedString("AE86 TrollStore Channel", comment: ""),
                type: "User",
                teamID: "GXZ23M5TP2",
                url: URL(string: "https://t.me/ae86_ios")!,
                alternateIcon: .init(named: "ae86-ios")
            ),
            App(
                id: NSLocalizedString("Not the first, but the best phone call recorder with TrollStore.", comment: ""),
                name: NSLocalizedString("TrollRecorder", comment: ""),
                type: "User",
                teamID: "GXZ23M5TP2",
                url: URL(string: "https://havoc.app/package/trollrecorder")!,
                alternateIcon: .init(named: "tricon-default")
            ),
        ].randomElement()
    }

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

            VStack {
                Spacer()

                if !vm.hasTrollRecorder, let possibleApp {
                    Button {
                        UIApplication.shared.open(possibleApp.url)
                    } label: {
                        AppListCell(app: possibleApp)
                        .padding()
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .environmentObject(filter)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .foregroundColor(Color(.systemBackground))
                            .shadow(radius: 4))
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                withAnimation {
                    vm.hasTrollRecorder = true
                }
            }
        }
    }
}

#Preview {
    SuccessView(title: "Hello, World!")
}
