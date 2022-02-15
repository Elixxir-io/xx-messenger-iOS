import UIKit
import Foundation

// https://github.com/ekazaev/ChatLayout

protocol KeyboardListenerDelegate: AnyObject {
    func keyboardDidHide(info: KeyboardInfo)
    func keyboardDidShow(info: KeyboardInfo)
    func keyboardWillShow(info: KeyboardInfo)
    func keyboardWillHide(info: KeyboardInfo)
    func keyboardDidChangeFrame(info: KeyboardInfo)
    func keyboardWillChangeFrame(info: KeyboardInfo)
}

extension KeyboardListenerDelegate {
    func keyboardDidHide(info: KeyboardInfo) {}
    func keyboardDidShow(info: KeyboardInfo) {}
    func keyboardWillHide(info: KeyboardInfo) {}
    func keyboardWillShow(info: KeyboardInfo) {}
    func keyboardWillChangeFrame(info: KeyboardInfo) {}
    func keyboardDidChangeFrame(info: KeyboardInfo) {}
}

final class KeyboardListener {
    static let shared = KeyboardListener()

    private(set) var keyboardRect: CGRect?
    private(set) var isKeyboardVisible: Bool = false

    private var delegates = NSHashTable<AnyObject>.weakObjects()

    private init() { subscribeToKeyboardNotifications() }

    func add(delegate: KeyboardListenerDelegate) {
        delegates.add(delegate)
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let info = KeyboardInfo(notification) else {
            return
        }

        keyboardRect = info.frameEnd
        isKeyboardVisible = true
        delegates.allObjects.compactMap { $0 as? KeyboardListenerDelegate }.forEach {
            $0.keyboardWillShow(info: info)
        }
    }

    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard let info = KeyboardInfo(notification) else { return }

        keyboardRect = info.frameEnd
        delegates.allObjects.compactMap { $0 as? KeyboardListenerDelegate }.forEach {
            $0.keyboardWillChangeFrame(info: info)
        }
    }

    @objc private func keyboardDidChangeFrame(_ notification: Notification) {
        guard let info = KeyboardInfo(notification) else { return }

        keyboardRect = info.frameEnd
        delegates.allObjects.compactMap { $0 as? KeyboardListenerDelegate }.forEach {
            $0.keyboardDidChangeFrame(info: info)
        }
    }

    @objc private func keyboardDidShow(_ notification: Notification) {
        guard let info = KeyboardInfo(notification) else { return }

        keyboardRect = info.frameEnd
        delegates.allObjects.compactMap { $0 as? KeyboardListenerDelegate }.forEach {
            $0.keyboardDidShow(info: info)
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let info = KeyboardInfo(notification) else { return }

        keyboardRect = info.frameEnd
        delegates.allObjects.compactMap { $0 as? KeyboardListenerDelegate }.forEach {
            $0.keyboardWillHide(info: info)
        }
    }

    @objc private func keyboardDidHide(_ notification: Notification) {
        guard let info = KeyboardInfo(notification) else { return }

        keyboardRect = info.frameEnd
        isKeyboardVisible = false
        delegates.allObjects.compactMap { $0 as? KeyboardListenerDelegate }.forEach {
            $0.keyboardDidHide(info: info)
        }
    }

    private func subscribeToKeyboardNotifications() {
        NotificationCenter.default
            .addObserver(self,
                         selector: #selector(keyboardWillShow(_:)),
                         name: UIResponder.keyboardWillShowNotification,
                         object: nil)
        NotificationCenter.default
            .addObserver(self,
                         selector: #selector(keyboardDidShow(_:)),
                         name: UIResponder.keyboardDidShowNotification,
                         object: nil)
        NotificationCenter.default
            .addObserver(self,
                         selector: #selector(keyboardWillHide(_:)),
                         name: UIResponder.keyboardWillHideNotification,
                         object: nil)
        NotificationCenter.default
            .addObserver(self,
                         selector: #selector(keyboardDidHide(_:)),
                         name: UIResponder.keyboardDidHideNotification,
                         object: nil)
        NotificationCenter.default
            .addObserver(self,
                         selector: #selector(keyboardWillChangeFrame(_:)),
                         name: UIResponder.keyboardWillChangeFrameNotification,
                         object: nil)
        NotificationCenter.default
            .addObserver(self,
                         selector: #selector(keyboardDidChangeFrame(_:)),
                         name: UIResponder.keyboardDidChangeFrameNotification,
                         object: nil)
    }

}

struct KeyboardInfo: Equatable {
    let isLocal: Bool
    let frameEnd: CGRect
    let frameBegin: CGRect
    let animationDuration: Double
    let animationCurve: UIView.AnimationCurve

    init?(_ notification: Notification) {
        guard let userInfo: NSDictionary = notification.userInfo as NSDictionary?,
              let keyboardAnimationCurve = (userInfo.object(forKey: UIResponder.keyboardAnimationCurveUserInfoKey) as? NSValue) as? Int,
              let keyboardAnimationDuration = (userInfo.object(forKey: UIResponder.keyboardAnimationDurationUserInfoKey) as? NSValue) as? Double,
              let keyboardIsLocal = (userInfo.object(forKey: UIResponder.keyboardIsLocalUserInfoKey) as? NSValue) as? Bool,
              let keyboardFrameBegin = (userInfo.object(forKey: UIResponder.keyboardFrameBeginUserInfoKey) as? NSValue)?.cgRectValue,
              let keyboardFrameEnd = (userInfo.object(forKey: UIResponder.keyboardFrameEndUserInfoKey) as? NSValue)?.cgRectValue else {
                  return nil
              }

        self.animationDuration = keyboardAnimationDuration
        var animationCurve = UIView.AnimationCurve.easeInOut
        NSNumber(value: keyboardAnimationCurve).getValue(&animationCurve)
        self.animationCurve = animationCurve
        self.isLocal = keyboardIsLocal
        self.frameBegin = keyboardFrameBegin
        self.frameEnd = keyboardFrameEnd
    }
}
