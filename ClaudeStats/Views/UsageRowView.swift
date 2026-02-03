import SwiftUI

struct UsageRowView: View {
    let title: String
    let current: Int
    let limit: Int
    let percentage: Double

    var formattedCurrent: String {
        formatNumber(current)
    }

    var formattedLimit: String {
        formatNumber(limit)
    }

    var progressColor: Color {
        if percentage >= 0.9 {
            return .red
        } else if percentage >= 0.7 {
            return .orange
        } else {
            return .blue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(formattedCurrent) / \(formattedLimit)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressColor)
                        .frame(width: geometry.size.width * CGFloat(percentage), height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 4)
    }

    private func formatNumber(_ num: Int) -> String {
        if num >= 1_000_000 {
            return String(format: "%.1fM", Double(num) / 1_000_000)
        } else if num >= 1_000 {
            return String(format: "%.1fK", Double(num) / 1_000)
        }
        return "\(num)"
    }
}

#Preview {
    VStack {
        UsageRowView(title: "Messages", current: 750, limit: 1000, percentage: 0.75)
        UsageRowView(title: "Tokens", current: 450000, limit: 500000, percentage: 0.9)
    }
    .padding()
    .frame(width: 280)
}
