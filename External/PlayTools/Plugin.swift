//
//  Plugin.swift
//  PlayTools
//
//  Created by Isaac Marovitz on 13/09/2022.
//

import Foundation

@objc(Plugin)
public protocol Plugin: NSObjectProtocol {
    init()

    var screenCount: Int { get }
    var mousePoint: CGPoint { get }
    var windowFrame: CGRect { get }
    /// Pointer in the event window's content view, origin at the top-left, plus that view's size.
    /// False when the pointer is outside the content view.
    func contentPointer(_ point: UnsafeMutablePointer<CGPoint>, size: UnsafeMutablePointer<CGSize>) -> Bool
    var mainScreenFrame: CGRect { get }
    var isMainScreenEqualToFirst: Bool { get }
    var isFullscreen: Bool { get }
    var cmdPressed: Bool { get }

    func hideCursor()
    func hideCursorMove()
    func warpCursor()
    func unhideCursor()
    func terminateApplication()
    func setupKeyboard(keyboard: @escaping (UInt16, Bool, Bool, Bool) -> Bool,
                       swapMode: @escaping () -> Bool)
    func setupMouseMoved(_ mouseMoved: @escaping (CGFloat, CGFloat) -> Bool)
    func setupMouseButton(left: Bool, right: Bool, _ consumed: @escaping (Int, Bool) -> Bool)
    func setupScrollWheel(_ onMoved: @escaping (CGFloat, CGFloat) -> Bool)
    func urlForApplicationWithBundleIdentifier(_ value: String) -> URL?
    func setMenuBarVisible(_ value: Bool)
}
