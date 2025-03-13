//
//  DisclaimerView.swift
//  TrollFools
//
//  Created by 82Flex on 3/13/25.
//

import SwiftUI

struct DisclaimerView: View {
    @Binding var isDisclaimerHidden: Bool

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("""
                    本开源软件仅用于 iOS 逆向工程技术交流与学习目的，严禁任何非法或商业用途。用户在使用过程中应严格遵守所在地法律法规，因滥用造成的任何法律责任均与开发者/发布者无关。开发者不对软件功能的完整性、适用性及使用后果承担责任，亦不鼓励任何违反服务条款或侵害知识产权的行为。
                    """)

                    Text("""
                    This open-source software is provided solely for educational and technical exchange purposes in iOS reverse engineering studies. Any illegal or commercial use is strictly prohibited. Users must comply with all applicable local laws and regulations. The developer/publisher shall not be held liable for any legal consequences arising from misuse. No warranties are provided regarding the software’s completeness, fitness for purpose, or consequences of use. The developer does not endorse any actions that violate service terms or infringe intellectual property rights.
                    """)
                }
                .padding()
                .font(.body)
            }
            .navigationTitle("免责声明 / Disclaimer")
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        exit(EXIT_SUCCESS)
                    } label: {
                        VStack(spacing: 0) {
                            Text("退出")
                                .font(.body)
                                .fontWeight(.bold)
                            Text("Exit")
                                .font(.footnote)
                        }
                        .foregroundColor(.red)
                        .padding()
                    }
                }

                ToolbarItem(placement: .bottomBar) {
                    Button {
                        isDisclaimerHidden = true
                    } label: {
                        VStack(spacing: 0) {
                            Text("我已阅读并同意")
                                .font(.body)
                                .fontWeight(.bold)
                            Text("I Have Read and Agree")
                                .font(.footnote)
                        }
                        .foregroundColor(.accentColor)
                        .padding()
                    }
                }
            }
        }
    }
}
