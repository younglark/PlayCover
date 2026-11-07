//
//  TouchscreenMouseEventAdapter.swift
//  PlayTools
//
//  Created by 许沂聪 on 2023/9/16.
//

import Foundation
import UIKit

// Mouse events handler when cursor is free and keyboard mapping is on

public class TouchscreenMouseEventAdapter: MouseEventAdapter {

    static public func cursorPos() -> CGPoint? {
        guard let ak = AKInterface.shared else { return nil }
        var contentPoint = CGPoint.zero
        var contentSize = CGSize.zero
        // Title bar and areas outside the content view are not part of the scene.
        guard ak.contentPointer(&contentPoint, size: &contentSize) else { return nil }

        if screen.resizable && !screen.fullscreen {
            // Leave the outer edge to the system so the window can still be resized.
            let margin = CGFloat(10)
            if contentPoint.x < margin || contentPoint.y < margin ||
                contentPoint.x > contentSize.width - margin ||
                contentPoint.y > contentSize.height - margin {
                return nil
            }
        }

        let viewRect = screen.keyWindow?.bounds ?? screen.screenRect
        guard let mapped = uiPoint(contentPoint: contentPoint,
                                   contentSize: contentSize,
                                   viewSize: viewRect.size) else { return nil }
        return CGPoint(x: mapped.x + viewRect.minX, y: mapped.y + viewRect.minY)
    }

    /// Aspect-fit `viewSize` inside the content view and center it on both axes.
    /// When the aspects match, the bars are empty and this is a plain scale.
    /// Points in the bars return nil.
    static func uiPoint(contentPoint: CGPoint, contentSize: CGSize, viewSize: CGSize) -> CGPoint? {
        guard contentSize.width > 0, contentSize.height > 0,
              viewSize.width > 0, viewSize.height > 0 else { return nil }
        let scale = min(contentSize.width / viewSize.width, contentSize.height / viewSize.height)
        guard scale > 0 else { return nil }
        let displayedWidth = viewSize.width * scale
        let displayedHeight = viewSize.height * scale
        let offsetX = (contentSize.width - displayedWidth) / 2
        let offsetY = (contentSize.height - displayedHeight) / 2
        let x = contentPoint.x
        let y = contentPoint.y
        if x < offsetX || y < offsetY || x > offsetX + displayedWidth || y > offsetY + displayedHeight {
            return nil
        }
        return CGPoint(x: (x - offsetX) / scale, y: (y - offsetY) / scale)
    }

    /// Native system dialogs often ignore fake touches; pass real clicks through.
    static func shouldPassThroughNativeDialog(at point: CGPoint) -> Bool {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .filter { !$0.isHidden }
            .sorted { $0.windowLevel.rawValue > $1.windowLevel.rawValue }

        for window in windows {
            if let hit = window.hitTest(point, with: nil), isNativeDialogView(hit) {
                return true
            }
            if window.windowLevel.rawValue > UIWindow.Level.normal.rawValue,
               containsAlertController(window) {
                return true
            }
        }

        if let key = screen.keyWindow,
           let hit = key.hitTest(point, with: nil),
           isNativeDialogView(hit) {
            return true
        }
        return false
    }

    private static func isNativeDialogView(_ view: UIView) -> Bool {
        var current: UIView? = view
        while let node = current {
            if containsAlertController(node) {
                return true
            }
            let className = NSStringFromClass(type(of: node))
            if className.contains("UIAlert")
                || className.contains("UIInterfaceAction")
                || className.contains("_UIAlert")
                || className.contains("UIActivityView")
                || className.contains("UISheetPresentation") {
                return true
            }
            current = node.superview
        }
        return false
    }

    private static func containsAlertController(_ responder: UIResponder) -> Bool {
        var current: UIResponder? = responder
        while let node = current {
            if node is UIAlertController {
                return true
            }
            current = node.next
        }
        return false
    }

    public func handleScrollWheel(deltaX: CGFloat, deltaY: CGFloat) -> Bool {
        _ = ActionDispatcher.dispatch(key: KeyCodeNames.scrollWheelDrag, valueX: deltaX, valueY: deltaY)
        return false
    }

    public func handleMove(deltaX: CGFloat, deltaY: CGFloat) -> Bool {
        if ActionDispatcher.getDispatchPriority(key: KeyCodeNames.mouseMove) == .DRAGGABLE {
            return ActionDispatcher.dispatch(key: KeyCodeNames.mouseMove, valueX: deltaX, valueY: -deltaY)
        } else if ActionDispatcher.getDispatchPriority(key: KeyCodeNames.fakeMouse) == .DRAGGABLE {
            guard let pos = TouchscreenMouseEventAdapter.cursorPos() else { return false }
            if TouchscreenMouseEventAdapter.shouldPassThroughNativeDialog(at: pos) {
                return false
            }
            return ActionDispatcher.dispatch(key: KeyCodeNames.fakeMouse, valueX: pos.x, valueY: pos.y)
        }
        return false
    }

    public func handleLeftButton(pressed: Bool) -> Bool {
        let pos = TouchscreenMouseEventAdapter.cursorPos()
        if let pos = pos, TouchscreenMouseEventAdapter.shouldPassThroughNativeDialog(at: pos) {
            return false
        }
        if pressed {
            guard let pos = pos else { return false }
            return ActionDispatcher.dispatch(key: KeyCodeNames.fakeMouse, valueX: pos.x, valueY: pos.y)
        }
        // Lift even when the cursor has left the scene, so the touch does not stay down.
        return ActionDispatcher.dispatch(key: KeyCodeNames.fakeMouse, pressed: false)
    }

    public func handleOtherButton(id: Int, pressed: Bool) -> Bool {
        ActionDispatcher.dispatch(key: EditorMouseEventAdapter.getMouseButtonName(id),
                                  pressed: pressed)
    }

    public func cursorHidden() -> Bool {
        false
    }

}
