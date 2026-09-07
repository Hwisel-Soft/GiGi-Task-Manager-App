import SwiftUI

extension Color {
    init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h = String(h.dropFirst()) }
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

struct GColors {
    let primary: Color
    let primaryDark: Color
    let primaryLight: Color
    let pink: Color
    let pinkLight: Color
    let high: Color
    let highLight: Color
    let med: Color
    let medLight: Color
    let low: Color
    let lowLight: Color
    let bg: Color
    let card: Color
    let text: Color
    let sub: Color
    let muted: Color
    let border: Color
    let green: Color
    let greenLight: Color
    let purple: Color
    let purpleLight: Color

    static let light = GColors(
        primary:     Color(hex: "#3D5AFE"),
        primaryDark: Color(hex: "#2942CC"),
        primaryLight:Color(hex: "#EEF1FF"),
        pink:        Color(hex: "#FF6B9D"),
        pinkLight:   Color(hex: "#FFF0F5"),
        high:        Color(hex: "#C62828"), // darkened for 5.6:1 AA contrast
        highLight:   Color(hex: "#FEF2F2"),
        med:         Color(hex: "#9B5000"), // darkened for 5.7:1 AA contrast
        medLight:    Color(hex: "#FFF3E0"),
        low:         Color(hex: "#6B6B6B"), // darkened for 4.7:1 AA contrast
        lowLight:    Color(hex: "#F5F5F5"),
        bg:          Color(hex: "#F4F5FF"),
        card:        Color(hex: "#FFFFFF"),
        text:        Color(hex: "#0D0D2B"),
        sub:         Color(hex: "#4A4A6A"),
        muted:       Color(hex: "#6E6E8C"), // darkened for 4.6:1 AA contrast
        border:      Color(hex: "#EEEEF5"),
        green:       Color(hex: "#2E7D32"), // darkened for 5.0:1 AA contrast
        greenLight:  Color(hex: "#F0FAF0"),
        purple:      Color(hex: "#9C27B0"),
        purpleLight: Color(hex: "#F5EEFF")
    )

    static let dark = GColors(
        primary:     Color(hex: "#738FFF"),
        primaryDark: Color(hex: "#5270FF"),
        primaryLight:Color(.sRGB, red: 0.451, green: 0.561, blue: 1, opacity: 0.18),
        pink:        Color(hex: "#FF6B9D"),
        pinkLight:   Color(.sRGB, red: 1, green: 0.420, blue: 0.616, opacity: 0.15),
        high:        Color(hex: "#FF6B6B"),
        highLight:   Color(.sRGB, red: 1, green: 0.420, blue: 0.420, opacity: 0.15),
        med:         Color(hex: "#FFB347"),
        medLight:    Color(.sRGB, red: 1, green: 0.702, blue: 0.278, opacity: 0.15),
        low:         Color(hex: "#9E9E9E"),
        lowLight:    Color(.sRGB, red: 0.620, green: 0.620, blue: 0.620, opacity: 0.12),
        bg:          Color(hex: "#0E0F1F"),
        card:        Color(hex: "#181929"),
        text:        Color(hex: "#EEEEFF"),
        sub:         Color(hex: "#AAAAC8"),
        muted:       Color(hex: "#9090B8"), // lightened for 6.0:1 AA contrast on dark card
        border:      Color(hex: "#252640"),
        green:       Color(hex: "#66BB6A"),
        greenLight:  Color(.sRGB, red: 0.400, green: 0.733, blue: 0.416, opacity: 0.15),
        purple:      Color(hex: "#CE93D8"),
        purpleLight: Color(.sRGB, red: 0.808, green: 0.576, blue: 0.847, opacity: 0.15)
    )

    func priorityColor(_ p: Priority) -> Color {
        switch p { case .high: high; case .medium: med; case .low: low }
    }

    func priorityLightColor(_ p: Priority) -> Color {
        switch p { case .high: highLight; case .medium: medLight; case .low: lowLight }
    }
}
