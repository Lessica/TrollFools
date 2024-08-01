//
//  OptionView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import SwiftUI

private enum Option {
    case attach
    case detach
}

private struct OptionCell: View {
    let option: Option
    let injectType: Int

    var iconName: String {
        if #available(iOS 16.0, *) {
            option == .attach ? "syringe" : "xmark.bin"
        } else {
            option == .attach ? "tray.and.arrow.down" : "xmark.bin"
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
                                 ? injectType == 0 ? .accentColor : .green : .red)
                .padding(.all, 40)
            }
            .background(
                (option == .attach ? injectType == 0 ? Color.accentColor : Color.green : Color.red)
                    .opacity(0.1)
                    .clipShape(RoundedRectangle(
                        cornerRadius: 10,
                        style: .continuous
                    ))
            )

            Text(option == .attach 
                 ? NSLocalizedString(injectType == 0 ? "Manual Inject" : "Runtime Inject", comment: "")
                 : NSLocalizedString("Eject", comment: ""))
                .font(.headline)
                .foregroundColor(option == .attach
                                 ? injectType == 0 ? .accentColor : .green  : .red)
        }
    }
}

struct OptionView: View {
    let app: App
    

    @State var isImporterPresented = false
    @State var True = true
    @State var showAlert = false
    @State var isImporterSelected = false
    @State var injectType : Int
    @State var importerResult: Result<[URL], any Error>?

    init(_ app: App) {
        self.app = app
        injectType = 0
    }

    var body: some View {
        VStack {
            Spacer()

            NavigationLink(isActive: $isImporterSelected) {
                if let result = importerResult {
                    
                    switch result {
                    case .success(let urls):
                            
                        InjectView(app: app, urlList: urls
                            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent }),injectType: injectType)
                    case .failure(let message):
                        FailureView(title: NSLocalizedString("Error", comment: ""),
                                    message: message.localizedDescription)
                    }
                }
            } label: {
            }
            

            Button {
                injectType = 0
                isImporterPresented = true
            } label: {
                OptionCell(option: .attach, injectType: 0)
            }
            .accessibilityLabel(NSLocalizedString("Manual Inject", comment: ""))

            Spacer()
            Button {
                injectType = 1
                isImporterPresented = true
            } label: {
                OptionCell(option: .attach, injectType:  1)
            }
            .accessibilityLabel(NSLocalizedString("Runtime Inject", comment: ""))

            Spacer()
            
            NavigationLink {
                EjectListView(app)
            } label: {
                OptionCell(option: .detach, injectType:  0)
            }
            .accessibilityLabel(NSLocalizedString("Eject", comment: ""))

            Spacer()
        }
        .padding()
        .navigationTitle(app.name)
        
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [
                .init(filenameExtension: "dylib")!,
                .bundle,
                .framework,
                .package,
                .zip,
                .init(filenameExtension: "deb")!,
            ],
            allowsMultipleSelection: true
        ) {
            result in
            importerResult = result
            isImporterSelected = true
            
            
            
        }
        
        
    }
}
