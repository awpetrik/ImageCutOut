import SwiftUI

struct StatusBadgeView: View {
    var status: AssetStatus

    var body: some View {
        Text(statusLabel)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundStyle(statusColor)
            .cornerRadius(6)
    }

    private var statusLabel: String {
        switch status {
        case .pending: return "Pending"
        case .processing: return "Processing"
        case .done: return "Done"
        case .failed: return "Failed"
        case .needsReview: return "Needs Review"
        case .paused: return "Paused"
        }
    }

    private var statusColor: Color {
        switch status {
        case .pending: return .gray
        case .processing: return .blue
        case .done: return .green
        case .failed: return .red
        case .needsReview: return .orange
        case .paused: return .yellow
        }
    }
}
