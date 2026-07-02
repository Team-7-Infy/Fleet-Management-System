import SwiftUI

struct ActivityRow: View {
    let activity: Activity

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "car.fill")
                .font(.system(size: 16))
                .foregroundStyle(AppColor.brand)
                .frame(width: 36, height: 36)
                .background(Color.gray.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.subtitle) // vehicle
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)
                
                HStack(spacing: 8) {
                    Text(activity.title)
                        .font(.system(size: 12))
                        .foregroundStyle(AppColor.textSecondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: activity.status == .completed ? FleetIcon.checkmark : "pause.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(activity.status.color)
                    Text(activity.status == .completed ? "Completed" : "In Progress")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(activity.status.color)
                    
                    if let timeStr = formattedTime {
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.gray)
                        
                        Image(systemName: "stopwatch")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.gray)
                        Text(timeStr)
                            .font(.system(size: 10))
                            .foregroundStyle(Color.gray)
                    }
                    
                    Text("•")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.gray)
                    
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.gray)
                    Text(activity.date, style: .time)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.gray)
                }
            }
            
            Spacer()
            
            Image(systemName: FleetIcon.chevronRight)
                .foregroundStyle(Color.gray)
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.vertical, 8)
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
