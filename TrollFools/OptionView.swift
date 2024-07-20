//
//  OptionView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import SwiftUI

enum Option {
    case attach
    case detach
}

struct OptionCell: View {
    let option: Option

    var iconName: String {
        if #available(iOS 16.0, *) {
            option == .attach
                  ? "syringe" : "xmark.bin"
        } else {
            option == .attach
                  ? "tray.and.arrow.down" : "xmark.bin"
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Image(systemName: iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
                .foregroundColor(option == .attach
                                 ? .accentColor : .red)
                .padding(.all, 40)
            }
            .background(
                (option == .attach ? Color.accentColor : Color.red)
                    .opacity(0.1)
                    .clipShape(RoundedRectangle(
                        cornerRadius: 10,
                        style: .continuous
                    ))
            )

            Text(option == .attach 
                 ? NSLocalizedString("Inject", comment: "")
                 : NSLocalizedString("Eject", comment: ""))
                .font(.headline)
                .foregroundColor(option == .attach
                                 ? .accentColor : .red)
        }
    }
}

struct OptionView: View {
    let app: App

    @State var isImporterPresented = false
    @State var isImporterSelected = false

    @State var importerResult: Result<[URL], any Error>?

    init(_ app: App) {
        self.app = app
    }

    var body: some View {
        HStack {
            Spacer()

            NavigationLink(isActive: $isImporterSelected) {
                if let result = importerResult {
                    switch result {
                    case .success(let urls):
                        InjectView(app: app, urlList: urls
                            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent }))
                    case .failure(let message):
                        FailureView(title: NSLocalizedString("Error", comment: ""), 
                                    message: message.localizedDescription)
                    }
                }
            } label: { }

            Button {
                isImporterPresented = true
            } label: {
                OptionCell(option: .attach)
            }

            Spacer()
            
            NavigationLink {
                EjectListView(app)
            } label: {
                OptionCell(option: .detach)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle(app.name)
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [
                .init(filenameExtension: "dylib")!,
            ],
            allowsMultipleSelection: true
        ) {
            result in
            importerResult = result
            isImporterSelected = true
        }
    }
}
