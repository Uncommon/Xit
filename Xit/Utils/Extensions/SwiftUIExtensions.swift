import Foundation
import SwiftUI
import AppKit

extension TextField where Label == EmptyView {
  
  init(text: Binding<String>) {
    self.init(text: text) { EmptyView() }
  }
}

private struct LiquidGlassSurface: ViewModifier
{
  let cornerRadius: CGFloat
  let padding: CGFloat
  @Environment(\.accessibilityReduceTransparency)
  private var reduceTransparency: Bool

  private var fallback: Bool
  {
    reduceTransparency || LiquidGlassAccessibility.shouldIncreaseContrast
  }

  func body(content: Content) -> some View
  {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    let strokeWidth = LiquidGlassAccessibility.shouldIncreaseContrast
        ? 1.0 : 0.5

    return content
      .padding(padding)
      .background {
        if fallback {
          shape.fill(Color(NSColor.xtLiquidGlassFallbackFill))
            .overlay(shape.stroke(Color(NSColor.xtLiquidGlassFallbackStroke),
                                  lineWidth: strokeWidth))
        }
        else {
          shape.fill(.thinMaterial)
            .overlay(shape.stroke(.primary.opacity(0.08),
                                  lineWidth: strokeWidth))
        }
      }
  }
}

extension View
{
  func liquidGlassSurface(
      cornerRadius: CGFloat = LiquidGlassTheme.cornerRadius,
      padding: CGFloat = LiquidGlassTheme.spacing) -> some View
  {
    modifier(LiquidGlassSurface(cornerRadius: cornerRadius, padding: padding))
  }
}
