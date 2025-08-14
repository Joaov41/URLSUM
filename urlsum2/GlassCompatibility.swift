import SwiftUI

// Applies SwiftUI glass effect on supported OS versions, otherwise no-op.
struct GlassBarEffect: ViewModifier {
    func body(content: Content) -> some View {
        #if swift(>=5.9)
        if #available(iOS 26.0, macOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: Rectangle())
        } else {
            content
        }
        #else
        content
        #endif
    }
}

struct GlassChipEffect: ViewModifier {
    let cornerRadius: CGFloat
    func body(content: Content) -> some View {
        #if swift(>=5.9)
        if #available(iOS 26.0, macOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            content
        }
        #else
        content
        #endif
    }
}

extension View {
    func glassBarIfAvailable() -> some View { modifier(GlassBarEffect()) }
    func glassChipIfAvailable(cornerRadius: CGFloat = 10) -> some View { modifier(GlassChipEffect(cornerRadius: cornerRadius)) }
}

