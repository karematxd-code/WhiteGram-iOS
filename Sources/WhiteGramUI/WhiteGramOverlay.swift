#if canImport(UIKit)
import UIKit
import WhiteGramCore
import GhostMode
import Gifts
import Upgrader
import ProfileSync

/// Floating draggable HUD button that provides instant access to WhiteGram features.
public final class WhiteGramFloatingButton: UIView {
    
    private let titleLabel = UILabel()
    private let sparkDot = UIView()
    private var initialCenter = CGPoint.zero
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupGestures()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupGestures()
    }
    
    private func setupUI() {
        backgroundColor = UIColor(red: 17/255.0, green: 24/255.0, blue: 39/255.0, alpha: 0.95)
        layer.cornerRadius = 28
        layer.borderWidth = 2.0
        layer.borderColor = UIColor.white.withAlphaComponent(0.9).cgColor
        
        // Shadow for depth
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.5
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 8
        
        // "W" Logo
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "W"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 24, weight: .black)
        titleLabel.textAlignment = .center
        addSubview(titleLabel)
        
        // Cyan spark accent dot
        sparkDot.translatesAutoresizingMaskIntoConstraints = false
        sparkDot.backgroundColor = UIColor(red: 143/255.0, green: 240/255.0, blue: 220/255.0, alpha: 1.0)
        sparkDot.layer.cornerRadius = 3.5
        sparkDot.clipsToBounds = true
        addSubview(sparkDot)
        
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor, constant: -2),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            sparkDot.widthAnchor.constraint(equalToConstant: 7),
            sparkDot.heightAnchor.constraint(equalToConstant: 7),
            sparkDot.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            sparkDot.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -13)
        ])
    }
    
    private func setupGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }
    
    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard let superview = self.superview else { return }
        let translation = recognizer.translation(in: superview)
        
        switch recognizer.state {
        case .began:
            initialCenter = center
            UIView.animate(withDuration: 0.15) {
                self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                self.alpha = 1.0
            }
        case .changed:
            center = CGPoint(x: initialCenter.x + translation.x, y: initialCenter.y + translation.y)
        case .ended, .cancelled:
            UIView.animate(withDuration: 0.15) {
                self.transform = .identity
            }
            snapToEdge()
        default:
            break
        }
    }
    
    private func snapToEdge() {
        guard let superview = self.superview else { return }
        let safeArea = superview.safeAreaInsets
        let midX = superview.bounds.midX
        
        let targetX: CGFloat = (center.x < midX) ? (safeArea.left + 36) : (superview.bounds.width - safeArea.right - 36)
        let minY = safeArea.top + 36
        let maxY = superview.bounds.height - safeArea.bottom - 46
        let targetY = min(max(center.y, minY), maxY)
        
        UIView.animate(
            withDuration: 0.35,
            delay: 0,
            usingSpringWithDamping: 0.75,
            initialSpringVelocity: 0.5,
            options: [.curveEaseOut],
            animations: {
                self.center = CGPoint(x: targetX, y: targetY)
            },
            completion: nil
        )
    }
    
    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        
        UIView.animate(withDuration: 0.1, animations: {
            self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.transform = .identity
            }
            WhiteGramOverlayManager.presentWhiteGramSettings()
        }
    }
}

/// Global manager for WhiteGram overlay elements and presentation.
@objc(WhiteGramOverlayManager)
public final class WhiteGramOverlayManager: NSObject {
    
    private static var floatingButton: WhiteGramFloatingButton?
    
    @objc public static func startOverlay() {
        DispatchQueue.main.async {
            // Seed mock gifts if needed for instant shelf & upgrader preview
            GiftStorage.shared.seedInitialDataIfNeeded(for: 777000)
            
            guard let window = findKeyWindow() else {
                WhiteGramLog.info("WhiteGramOverlayManager: Key window not yet available, will retry.")
                return
            }
            
            if floatingButton?.superview != nil {
                return
            }
            
            let btnWidth: CGFloat = 56
            let btnHeight: CGFloat = 56
            let safeArea = window.safeAreaInsets
            let initialX = window.bounds.width - safeArea.right - btnWidth - 16
            let initialY = window.bounds.height - safeArea.bottom - btnHeight - 120
            
            let btn = WhiteGramFloatingButton(frame: CGRect(x: initialX, y: initialY, width: btnWidth, height: btnHeight))
            window.addSubview(btn)
            floatingButton = btn
            WhiteGramLog.info("WhiteGramOverlayManager: Floating button successfully attached to window.")
        }
    }
    
    @objc public static func presentWhiteGramSettings() {
        DispatchQueue.main.async {
            guard let topVC = findTopViewController() else {
                WhiteGramLog.error("WhiteGramOverlayManager: Unable to find top view controller.")
                return
            }
            
            // If settings is already presented, don't re-present
            if topVC is WhiteGramSettingsController || (topVC as? UINavigationController)?.topViewController is WhiteGramSettingsController {
                return
            }
            
            let settingsVC = WhiteGramSettingsController()
            let nav = UINavigationController(rootViewController: settingsVC)
            nav.modalPresentationStyle = .pageSheet
            
            if #available(iOS 15.0, *) {
                if let sheet = nav.sheetPresentationController {
                    sheet.detents = [.medium(), .large()]
                    sheet.prefersGrabberVisible = true
                    sheet.preferredCornerRadius = 24
                }
            }
            
            topVC.present(nav, animated: true)
        }
    }
    
    private static func findKeyWindow() -> UIWindow? {
        if #available(iOS 15.0, *) {
            for scene in UIApplication.shared.connectedScenes {
                if let windowScene = scene as? UIWindowScene {
                    for window in windowScene.windows {
                        if window.isKeyWindow { return window }
                    }
                    if let first = windowScene.windows.first { return first }
                }
            }
        }
        return UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first
    }
    
    private static func findTopViewController(base: UIViewController? = nil) -> UIViewController? {
        let baseVC = base ?? findKeyWindow()?.rootViewController
        if let nav = baseVC as? UINavigationController {
            return findTopViewController(base: nav.visibleViewController)
        }
        if let tab = baseVC as? UITabBarController {
            return findTopViewController(base: tab.selectedViewController)
        }
        if let presented = baseVC?.presentedViewController {
            return findTopViewController(base: presented)
        }
        return baseVC
    }
}
#endif
