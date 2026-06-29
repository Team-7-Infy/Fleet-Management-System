import SwiftUI

struct ActivityRow: View {
    let activity: Activity

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: activity.status == .completed ? AppIcon.checkmark : "pause.fill")
                .foregroundStyle(activity.status.color)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(activity.status.color.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(activity.date, style: .time)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(activity.status.color)
                    Spacer()
                }
                
                Text(activity.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)
                    
                if let timeStr = formattedTime {
                    Text("Worked for \(timeStr)")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
    
    private var formattedTime: String? {
        guard let elapsed = activity.elapsedTime, elapsed > 0 else { return nil }
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60
        let seconds = Int(elapsed) % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

#Preview {
    ActivityRow(activity: PreviewData.activities[0])
        .padding()
}
