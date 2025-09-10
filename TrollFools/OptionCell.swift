//
//  OptionCell.swift
//  TrollFools
//
//  Created by 82Flex on 2024/10/30.
//

import SwiftUI

struct OptionCell: View {
    let option: Option

    var iconName: String {
        if #available(iOS 16, *) {
            option == .attach ? "syringe" : "folder.badge.gear"
        } else {
            option == .attach ? "tray.and.arrow.down" : "folder.badge.gear"
        }
    }

    var tintColor: Color {
        option == .attach ? .green : .accentColor
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Image(systemName: iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .foregroundColor(tintColor)
                    .padding(.all, 40)
            }
            .background(
                tintColor
                    .opacity(0.1)
                    .clipShape(RoundedRectangle(
                        cornerRadius: 10,
                        style: .continuous
                    ))
            )

            Text(option == .attach
                ? NSLocalizedString("Inject", comment: "")
                : NSLocalizedString("Manage", comment: ""))
                .font(.headline)
                .foregroundColor(tintColor)
        }
    }
}
