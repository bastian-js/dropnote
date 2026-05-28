import SwiftUI
import AppKit

extension NSCursor {
    // macOS uses this private cursor for NW-SE window corner resize (bottom-right handle).
    // Gracefully falls back to crosshair if Apple ever removes it.
    static var diagonalResize: NSCursor {
        let sel = NSSelectorFromString("_windowResizeNorthWestSouthEastCursor")
        if NSCursor.responds(to: sel),
           let c = NSCursor.perform(sel)?.takeUnretainedValue() as? NSCursor {
            return c
        }
        return .crosshair
    }
}

private let minPopoverWidth: CGFloat = 240
private let maxPopoverWidth: CGFloat = 800
private let minPopoverHeight: CGFloat = 300
private let maxPopoverHeight: CGFloat = 900

struct ResizeHandle: View {
    let currentSize: CGSize
    let onResize: (CGSize) -> Void
    let onResizeEnd: (CGSize) -> Void

    @State private var dragStartSize: CGSize = .zero
    @State private var isDragging = false

    var body: some View {
        grip
            .foregroundColor(Color.secondary.opacity(isDragging ? 0.55 : 0.25))
            .frame(width: 18, height: 18)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .global)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            dragStartSize = currentSize
                        }
                        let size = clampedSize(
                            width: dragStartSize.width + value.translation.width,
                            height: dragStartSize.height + value.translation.height
                        )
                        onResize(size)
                    }
                    .onEnded { value in
                        isDragging = false
                        let size = clampedSize(
                            width: dragStartSize.width + value.translation.width,
                            height: dragStartSize.height + value.translation.height
                        )
                        onResizeEnd(size)
                    }
            )
            .onHover { hovering in
                if hovering { NSCursor.diagonalResize.push() } else { NSCursor.pop() }
            }
    }

    private func clampedSize(width: CGFloat, height: CGFloat) -> CGSize {
        CGSize(
            width: max(minPopoverWidth, min(maxPopoverWidth, width)),
            height: max(minPopoverHeight, min(maxPopoverHeight, height))
        )
    }

    // Three-dot diagonal grip (macOS resize corner style)
    private var grip: some View {
        Canvas { ctx, _ in
            let dots: [(CGFloat, CGFloat)] = [(10, 14), (14, 10), (14, 14)]
            for (x, y) in dots {
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3)),
                    with: .foreground
                )
            }
        }
        .frame(width: 18, height: 18)
    }
}
