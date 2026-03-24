import SwiftUI

// MARK: - Color Tokens

extension Color {
    /// Primary brand orange
    static let brand = Color(hex: "FF6B2C")
    /// Darker orange for gradient endpoints
    static let brandDeep = Color(hex: "CC4A10")
    /// Lighter orange for glow halos
    static let brandGlow = Color(hex: "FF8C55")
    /// Warm highlight for premium accents
    static let brandWarm = Color(hex: "FFAD78")

    // Dark surface system — explicit whites for forced-dark contexts
    /// Primary text on dark backgrounds
    static let textPrimary = Color.white.opacity(0.92)
    /// Secondary/descriptive text on dark backgrounds
    static let textSecondary = Color.white.opacity(0.55)
    /// Tertiary/hint text
    static let textTertiary = Color.white.opacity(0.35)

    /// Raised surface — subtle white lift
    static let surfaceRaised = Color.white.opacity(0.06)
    /// Slightly more elevated surface
    static let surfaceElevated = Color.white.opacity(0.09)
    /// Subtle border for glass cards
    static let borderSubtle = Color.white.opacity(0.10)
    /// Glowing border tint
    static let borderGlow = Color(hex: "FF6B2C").opacity(0.35)

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Typography

enum DSFont {
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func heading(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static func label(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func mono(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
}

// MARK: - Spacing

enum DSSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

// MARK: - Glass Card

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.surfaceRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.borderSubtle, lineWidth: 0.5)
                    )
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 12) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Glow Border

struct GlowBorder: ViewModifier {
    var cornerRadius: CGFloat = 12
    var glowRadius: CGFloat = 12
    var glowOpacity: Double = 0.25

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.borderGlow, lineWidth: 1)
            )
            .shadow(color: Color.brand.opacity(glowOpacity), radius: glowRadius)
    }
}

extension View {
    func glowBorder(cornerRadius: CGFloat = 12, glowRadius: CGFloat = 12, glowOpacity: Double = 0.25) -> some View {
        modifier(GlowBorder(cornerRadius: cornerRadius, glowRadius: glowRadius, glowOpacity: glowOpacity))
    }
}

// MARK: - Brand Button Style

struct BrandButtonStyle: ButtonStyle {
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSFont.label(compact ? 12 : 13, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, compact ? DSSpacing.md : DSSpacing.lg)
            .padding(.vertical, compact ? 6 : 10)
            .background(
                LinearGradient(
                    colors: [Color.brand, Color.brandDeep],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(Capsule())
            .shadow(
                color: Color.brand.opacity(configuration.isPressed ? 0.2 : 0.5),
                radius: configuration.isPressed ? 4 : 8,
                y: 2
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Ghost-style button — outline only, no fill
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSFont.label(13))
            .foregroundColor(Color.textSecondary)
            .padding(.horizontal, DSSpacing.md)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

extension ButtonStyle where Self == BrandButtonStyle {
    static var brand: BrandButtonStyle { BrandButtonStyle() }
    static var brandCompact: BrandButtonStyle { BrandButtonStyle(compact: true) }
}

extension ButtonStyle where Self == GhostButtonStyle {
    static var ghost: GhostButtonStyle { GhostButtonStyle() }
}

// MARK: - Pill Badge

struct PillBadge: View {
    let granted: Bool
    let grantedText: String
    let pendingText: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundColor(granted ? .green : Color.brand)
            Text(granted ? grantedText : pendingText)
                .font(DSFont.label(12))
                .foregroundColor(granted ? .green : Color.brandWarm)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill((granted ? Color.green : Color.brand).opacity(0.12))
                .overlay(
                    Capsule()
                        .stroke((granted ? Color.green : Color.brand).opacity(0.2), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        Label {
            Text(title)
                .foregroundColor(Color.textTertiary)
        } icon: {
            Image(systemName: icon)
                .foregroundColor(Color.brand.opacity(0.6))
        }
        .font(DSFont.label(10, weight: .semibold))
        .textCase(.uppercase)
    }
}

// MARK: - Glow Circle (for onboarding illustrations)

struct GlowCircle: View {
    var size: CGFloat = 160
    var opacity: Double = 0.12

    var body: some View {
        Circle()
            .fill(Color.brand.opacity(opacity))
            .frame(width: size, height: size)
            .blur(radius: 40)
    }
}
