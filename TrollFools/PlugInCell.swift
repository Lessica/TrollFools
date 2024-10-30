//
//  PlugInCell.swift
//  TrollFools
//
//  Created by 82Flex on 2024/10/30.
//

import SwiftUI

private let gDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

struct PlugInCell: View {
    @EnvironmentObject var vm: AppListModel
    @EnvironmentObject var filter: FilterOptions

    let plugIn: InjectedPlugIn

    @available(iOS 15.0, *)
    var highlightedName: AttributedString {
        let name = plugIn.url.lastPathComponent
        var attributedString = AttributedString(name)
        if let range = attributedString.range(of: filter.searchKeyword, options: [.caseInsensitive, .diacriticInsensitive]) {
            attributedString[range].foregroundColor = .accentColor
        }
        return attributedString
    }

    var iconName: String {
        let pathExt = plugIn.url.pathExtension.lowercased()
        if pathExt == "bundle" {
            return "archivebox"
        }
        if pathExt == "dylib" {
            return "bandage"
        }
        if pathExt == "framework" {
            return "shippingbox"
        }
        return "puzzlepiece"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading) {
                if #available(iOS 15.0, *) {
                    Text(highlightedName)
                        .font(.headline)
                } else {
                    Text(plugIn.url.lastPathComponent)
                        .font(.headline)
                }

                Text(gDateFormatter.string(from: plugIn.createdAt))
                    .font(.subheadline)
            }
        }
        .contextMenu {
            if isFilzaInstalled {
                Button {
                    openInFilza()
                } label: {
                    Label(NSLocalizedString("Show in Filza", comment: ""), systemImage: "scope")
                }
            }
        }
    }

    var isFilzaInstalled: Bool { vm.isFilzaInstalled }

    private func openInFilza() {
        vm.openInFilza(plugIn.url)
    }
}
