import SwiftUI

struct ProgressBarView: View {
    var value: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: proxy.size.width * CGFloat(min(max(value, 0), 1)))
            }
            .cornerRadius(4)
        }
        .frame(height: 6)
    }
}
