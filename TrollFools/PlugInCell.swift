//
//  PlugInCell.swift
//  TrollFools
//
//  Created by 82Flex on 2024/10/30.
//

import QuickLook
import SwiftUI

private let gDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

struct PlugInCell: View {
    @EnvironmentObject var ejectList: EjectListModel
    @Binding var quickLookExport: URL?
    let plugIn: InjectedPlugIn
    let replaceAction: () -> Void

    init(_ plugIn: InjectedPlugIn, quickLookExport: Binding<URL?>, onReplace: @escaping () -> Void) {
        self.plugIn = plugIn
        _quickLookExport = quickLookExport
        self.replaceAction = onReplace
    }

    @available(iOS 15, *)
    var highlightedName: AttributedString {
        let name = plugIn.url.lastPathComponent
        var attributedString = AttributedString(name)
        if let range = attributedString.range(of: ejectList.filter.searchKeyword, options: [.caseInsensitive, .diacriticInsensitive]) {
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
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading) {
                    if #available(iOS 15, *) {
                        Text(highlightedName)
                            .font(.headline)
                    } else {
                        Text(plugIn.url.lastPathComponent)
                            .font(.headline)
                    }
                    Text(gDateFormatter.string(from: plugIn.createdAt))
                        .font(.subheadline)
                }
                .opacity(plugIn.isEnabled ? 1.0 : 0.5)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                self.replaceAction()
            }
            
            Spacer()
            Toggle(isOn: .constant(plugIn.isEnabled)) { Text("") }
                .labelsHidden()
                .onTapGesture {
                    ejectList.toggleEnableState(for: plugIn)
                }
                .disabled(ejectList.isOperationInProgress)
        }
        .contextMenu {
            if #available(iOS 16.4, *) {
                ShareLink(item: plugIn.url) {
                    Label(NSLocalizedString("Export", comment: ""), systemImage: "square.and.arrow.up")
                }
            } else {
                Button {
                    exportPlugIn()
                } label: {
                    Label(NSLocalizedString("Export", comment: ""), systemImage: "square.and.arrow.up")
                }
            }
            Button {
                openInFilza()
            } label: {
                if isFilzaInstalled {
                    Label(NSLocalizedString("Show in Filza", comment: ""), systemImage: "scope")
                } else {
                    Label(NSLocalizedString("Filza (URL Scheme) Not Installed", comment: ""), systemImage: "xmark.octagon")
                }
            }
            .disabled(!isFilzaInstalled)
        }
    }

    private func exportPlugIn() {
        quickLookExport = plugIn.url
    }

    var isFilzaInstalled: Bool { ejectList.app.appList?.isFilzaInstalled ?? false }

    private func openInFilza() {
        ejectList.app.appList?.openInFilza(plugIn.url)
    }
}
