//
//  IndexableScroller.swift
//  TrollFools
//
//  Created by 82Flex on 3/9/25.
//

import SwiftUI

struct IndexableScroller: View {
    let indexes: [String]
    let feedback = UISelectionFeedbackGenerator()

    @Binding var currentIndex: String?
    @GestureState private var dragLocation: CGPoint = .zero

    var body: some View {
        HStack {
            VStack(spacing: 0) {
                ForEach(indexes, id: \.self) { index in
                    Text(index)
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                        .padding(.trailing, 12)
                        .background(dragObserver(index))
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .updating($dragLocation) { value, state, _ in
                        state = value.location
                    }
            )

            Spacer()
        }
    }

    func dragObserver(_ index: String) -> some View {
        GeometryReader { geometry in
            dragObserver(index: index, geometry: geometry)
        }
    }

    func dragObserver(index: String, geometry: GeometryProxy) -> some View {
        if geometry.frame(in: .global).contains(dragLocation) {
            DispatchQueue.main.async {
                let previousIndex = currentIndex
                currentIndex = index
                if currentIndex != previousIndex {
                    feedback.selectionChanged()
                }
            }
        }
        return Rectangle().fill(.background).opacity(0.05)
    }
}

// MARK: - Preview

struct IndexableScroller_Previews: PreviewProvider {
    static var previews: some View {
        IndexableScroller(
            indexes: ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "#"],
            currentIndex: .constant(nil)
        )
    }
}
