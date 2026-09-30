//
//  WidgetHelperViews.swift
//  FamCareWidget
//
//  Reusable SwiftUI components used across all three widget types:
//  - WellnessRingView: circular progress ring showing a percentage
//  - ProfileAvatarView: displays the user's profile photo or a fallback initial
//  - WellnessBarView: horizontal progress bar for member rows
//

import SwiftUI
import WidgetKit

// MARK: - Wellness Ring

/// A circular ring that shows a wellness percentage, matching the design mockup.
struct WellnessRingView: View {
    let score: Double  // 0.0–1.0
    let size: CGFloat
    let lineWidth: CGFloat
    let showLabel: Bool
    let fontSize: CGFloat
    
    init(score: Double, size: CGFloat = 60, lineWidth: CGFloat = 6,
         showLabel: Bool = true, fontSize: CGFloat = 14) {
        self.score = score
        self.size = size
        self.lineWidth = lineWidth
        self.showLabel = showLabel
        self.fontSize = fontSize
    }
    
    private var ringColor: Color {
        if score >= 0.7 { return Color(red: 0.18, green: 0.65, blue: 0.45) }  // green
        if score >= 0.4 { return Color.orange }
        return Color.red
    }
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(ringColor.opacity(0.2), lineWidth: lineWidth)
                .frame(width: size, height: size)
            
            // Foreground ring
            Circle()
                .trim(from: 0, to: CGFloat(min(score, 1.0)))
                .stroke(ringColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)
            
            // Percentage label
            if showLabel {
                Text("\(Int(score * 100))%")
                    .font(.system(size: fontSize, weight: .bold, design: .rounded))
                    .foregroundColor(ringColor)
            }
        }
    }
}

// MARK: - Profile Avatar

/// Displays the user's profile photo from the shared container,
/// or a colored circle with their initial as fallback.
struct ProfileAvatarView: View {
    let profileId: String
    let displayName: String
    let size: CGFloat
    
    private var initial: String {
        String(displayName.prefix(1)).uppercased()
    }
    
    private var avatarColor: Color {
        // Deterministic color based on profile ID hash
        let hash = abs(profileId.hashValue)
        let colors: [Color] = [
            Color(red: 0.18, green: 0.65, blue: 0.45),
            Color(red: 0.85, green: 0.40, blue: 0.35),
            Color(red: 0.30, green: 0.50, blue: 0.85),
            Color(red: 0.80, green: 0.55, blue: 0.20),
            Color(red: 0.55, green: 0.35, blue: 0.75),
        ]
        return colors[hash % colors.count]
    }
    
    var body: some View {
        if let imagePath = WidgetDataLoader.profileImagePath(for: profileId),
           let uiImage = UIImage(contentsOfFile: imagePath.path) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            // Fallback: colored circle with initial
            ZStack {
                Circle()
                    .fill(avatarColor.opacity(0.2))
                    .frame(width: size, height: size)
                Text(initial)
                    .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                    .foregroundColor(avatarColor)
            }
        }
    }
}

// MARK: - Wellness Bar

/// Horizontal progress bar showing a member's wellness score.
struct WellnessBarView: View {
    let score: Double
    let width: CGFloat
    
    private var barColor: Color {
        if score >= 0.7 { return Color(red: 0.18, green: 0.65, blue: 0.45) }
        if score >= 0.4 { return Color.orange }
        return Color(red: 0.85, green: 0.40, blue: 0.35)
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(barColor.opacity(0.15))
                    .frame(height: 6)
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(barColor)
                    .frame(width: max(0, geo.size.width * CGFloat(min(score, 1.0))), height: 6)
            }
        }
        .frame(width: width, height: 6)
    }
}

// MARK: - Vital Pill

/// A small pill badge showing a vital value (used in medium widget).
struct VitalPillView: View {
    let value: String
    let color: Color
    
    var body: some View {
        Text(value)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(0.8))
            )
    }
}

// MARK: - Widget Background Modifier

extension View {
    /// Applies the warm gradient background matching the design mockups.
    @ViewBuilder
    func widgetWarmBackground() -> some View {
        self.background(
            Color(red: 221/255.0, green: 247/255.0, blue: 252/255.0) // #DDF7FC
        )
    }
    
    /// Applies the dark background for Member Spotlight widget.
    @ViewBuilder
    func widgetDarkBackground() -> some View {
        self.background(
            Color(red: 0.15, green: 0.15, blue: 0.15)
        )
    }
    
    /// Applies the soft alert background for Care Alert widget.
    @ViewBuilder
    func widgetAlertBackground() -> some View {
        self.background(
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.94, blue: 0.90),
                    Color(red: 0.98, green: 0.88, blue: 0.82)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}
