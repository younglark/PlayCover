//
//  Toucher.swift
//  PlayCoverInject
//

import Foundation
import UIKit

class Toucher {
    static weak var keyWindow: UIWindow?
    static weak var keyView: UIView?
    // For debug only
    static var logEnabled = false
    static var logFilePath =
    NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + "/toucher.log"
    static private var logCount = 0
    static var logFile: FileHandle?
    /**
     on invocations with phase "began", an int id is allocated, which can be used later to refer to this touch point.
     on invocations with phase "ended", id is set to nil representing the touch point is no longer valid.
     */
    static func touchcam(point: CGPoint, phase: UITouch.Phase, tid: inout Int?,
                         // Name info for debug use
                         actionName: String, keyName: String) {
        if phase == UITouch.Phase.began {
            if tid != nil {
                return
            }
            tid = -1
        } else if tid == nil {
            return
        }
        let currentId = tid!
        // Flutter hit-tests by entering the root isolate, which Dart only allows
        // on the platform thread. Callers on playcover.toucher block here so the
        // touch id is assigned before they continue.
        let updatedId = onMainThread { () -> Int in
            if phase == UITouch.Phase.began {
                keyWindow = screen.keyWindow
                keyView = keyWindow!.hitTest(point, with: nil)
            }
            return PTFakeMetaTouch.fakeTouchId(currentId, at: point, with: phase, in: keyWindow, on: keyView)
        }
        var recordId = currentId
        tid = updatedId
        writeLog(logMessage:
                "\(phase.rawValue.description) \(tid!.description) \(point.debugDescription)")
        if tid! < 0 {
            tid = nil
        } else {
            recordId = tid!
        }
        DebugModel.instance.record(point: point, phase: phase, tid: recordId,
                                   description: actionName + "(" + keyName + ")")
    }

    private static func onMainThread<T>(_ work: () -> T) -> T {
        if Thread.isMainThread {
            return work()
        }
        return DispatchQueue.main.sync(execute: work)
    }

    static func setupLogfile() {
        if FileManager.default.createFile(atPath: logFilePath, contents: nil, attributes: nil) {
            logFile = FileHandle(forWritingAtPath: logFilePath)
            Toast.showOver(msg: logFilePath)
        } else {
            Toast.showHint(title: "logFile creation failed")
            return
        }
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name(rawValue: "NSApplicationWillTerminateNotification"),
            object: nil,
            queue: OperationQueue.main
        ) { _ in
            try? logFile?.close()
        }
    }

    static func writeLog(logMessage: String) {
        if !logEnabled {
            return
        }
        guard let file = logFile else {
            setupLogfile()
            return
        }
        let message = "\(DispatchTime.now().rawValue) \(logMessage)\n"
        guard let data = message.data(using: .utf8) else {
            Toast.showHint(title: "log message is utf8 uncodable")
            return
        }
        logCount += 1
        // roll over
        if logCount > 60000 {
            file.seek(toFileOffset: 0)
            logCount = 0
        }
        file.write(data)
    }
}
