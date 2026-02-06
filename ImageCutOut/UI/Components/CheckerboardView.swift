import SwiftUI

struct CheckerboardView: View {
    var body: some View {
        GeometryReader { proxy in
            let cellSize = 12.0
            Canvas { context, size in
                let rows = Int(size.height / cellSize) + 1
                let cols = Int(size.width / cellSize) + 1
                for row in 0..<rows {
                    for col in 0..<cols {
                        let rect = CGRect(x: Double(col) * cellSize, y: Double(row) * cellSize, width: cellSize, height: cellSize)
                        let color = ((row + col) % 2 == 0) ? Color.gray.opacity(0.2) : Color.gray.opacity(0.1)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
    }
}
