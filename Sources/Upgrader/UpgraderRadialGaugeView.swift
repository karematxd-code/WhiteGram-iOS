import Foundation
#if canImport(UIKit)
import UIKit
import CoreGraphics
import QuartzCore
#endif

#if canImport(UIKit)
/// A high-performance, CoreAnimation-driven radial gauge view used in the WhiteGram Upgrader.
/// Renders a circular background track, a dynamic winning arc, precision tick marks,
/// an animated indicator needle with cubic easing, and a live counter percentage label.
public final class UpgraderRadialGaugeView: UIView {
    
    // MARK: - Configuration
    
    public struct Configuration {
        public var lineWidth: CGFloat = 18.0
        public var trackColor: UIColor = UIColor(white: 0.18, alpha: 0.35)
        public var winningGradientColors: [UIColor] = [
            UIColor(red: 0.12, green: 0.74, blue: 0.98, alpha: 1.0), // Electric Cyan
            UIColor(red: 0.48, green: 0.25, blue: 0.98, alpha: 1.0), // Deep Violet
            UIColor(red: 0.96, green: 0.32, blue: 0.65, alpha: 1.0)  // Neon Rose
        ]
        public var needleColor: UIColor = UIColor(red: 1.0, green: 0.82, blue: 0.25, alpha: 1.0) // Gold
        public var needleTipColor: UIColor = UIColor(red: 1.0, green: 0.35, blue: 0.25, alpha: 1.0)
        public var hubColor: UIColor = UIColor(white: 0.15, alpha: 1.0)
        public var hubBorderColor: UIColor = UIColor(white: 0.35, alpha: 0.8)
        public var hubRadius: CGFloat = 16.0
        public var startAngle: CGFloat = -CGFloat.pi / 2.0 // 12 o'clock
        public var majorTickCount: Int = 20
        public var minorTickCount: Int = 100
        
        public static let `default` = Configuration()
        public init() {}
    }
    
    public var configuration: Configuration = .default {
        didSet {
            setupAppearance()
            setNeedsLayout()
        }
    }
    
    // MARK: - Public State
    
    /// The winning chance represented as a percentage from 0.0 to 100.0.
    public private(set) var chance: Double = 0.0
    
    /// Current normalized needle angle (0.0 rad = 12 o'clock / startAngle).
    public private(set) var currentNeedleAngle: CGFloat = 0.0
    
    /// Whether a spin animation is currently in progress.
    public private(set) var isSpinning: Bool = false
    
    // MARK: - Sublayers
    
    private let trackLayer = CAShapeLayer()
    private let ticksLayer = CAShapeLayer()
    private let winningArcLayer = CAShapeLayer()
    private let winningGradientLayer = CAGradientLayer()
    private let glowLayer = CAShapeLayer()
    
    // Needle hierarchy
    private let needleContainerLayer = CALayer()
    private let needleShaftLayer = CAShapeLayer()
    private let needleTipLayer = CAShapeLayer()
    private let hubLayer = CAShapeLayer()
    private let hubInnerDotLayer = CAShapeLayer()
    
    // MARK: - Center UI Elements
    
    public let percentageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = .label
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 36, weight: .black)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.6
        label.text = "0.00%"
        return label
    }()
    
    public let subtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        label.text = "ШАНС ПОБЕДЫ"
        label.alpha = 0.85
        return label
    }()
    
    public let multiplierBadge: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = UIColor(red: 0.12, green: 0.82, blue: 0.48, alpha: 1.0)
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .heavy)
        label.backgroundColor = UIColor(red: 0.12, green: 0.82, blue: 0.48, alpha: 0.15)
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        label.text = "x1.00"
        return label
    }()
    
    private let centerStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 3
        return stack
    }()
    
    // MARK: - Display Link for Live Text Animation
    
    private var displayLink: CADisplayLink?
    private var animationStartTime: CFTimeInterval = 0
    private var animationDuration: CFTimeInterval = 0.35
    private var startChanceValue: Double = 0.0
    private var targetChanceValue: Double = 0.0
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    deinit {
        displayLink?.invalidate()
    }
    
    private func commonInit() {
        backgroundColor = .clear
        isUserInteractionEnabled = true
        
        setupLayers()
        setupCenterViews()
        setupAppearance()
    }
    
    // MARK: - Layer Setup
    
    private func setupLayers() {
        // Base track
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.lineCap = .round
        layer.addSublayer(trackLayer)
        
        // Minor & major ticks
        ticksLayer.fillColor = UIColor.clear.cgColor
        ticksLayer.lineCap = .round
        layer.addSublayer(ticksLayer)
        
        // Winning arc glow
        glowLayer.fillColor = UIColor.clear.cgColor
        glowLayer.lineCap = .round
        glowLayer.strokeColor = configuration.winningGradientColors.first?.cgColor
        glowLayer.shadowColor = configuration.winningGradientColors.first?.cgColor
        glowLayer.shadowOffset = .zero
        glowLayer.shadowRadius = 12
        glowLayer.shadowOpacity = 0.45
        layer.addSublayer(glowLayer)
        
        // Winning arc gradient with shape mask
        winningArcLayer.fillColor = UIColor.clear.cgColor
        winningArcLayer.lineCap = .round
        winningArcLayer.strokeEnd = 0.0
        
        winningGradientLayer.type = .conic
        winningGradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        winningGradientLayer.endPoint = CGPoint(x: 0.5, y: 0.0)
        winningGradientLayer.mask = winningArcLayer
        layer.addSublayer(winningGradientLayer)
        
        // Needle hierarchy
        layer.addSublayer(needleContainerLayer)
        needleContainerLayer.addSublayer(needleShaftLayer)
        needleContainerLayer.addSublayer(needleTipLayer)
        needleContainerLayer.addSublayer(hubLayer)
        needleContainerLayer.addSublayer(hubInnerDotLayer)
    }
    
    private func setupCenterViews() {
        addSubview(centerStackView)
        centerStackView.addArrangedSubview(subtitleLabel)
        centerStackView.addArrangedSubview(percentageLabel)
        centerStackView.addArrangedSubview(multiplierBadge)
        
        NSLayoutConstraint.activate([
            centerStackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerStackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            centerStackView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.65),
            multiplierBadge.heightAnchor.constraint(equalToConstant: 24),
            multiplierBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 68)
        ])
    }
    
    private func setupAppearance() {
        trackLayer.strokeColor = configuration.trackColor.cgColor
        trackLayer.lineWidth = configuration.lineWidth
        
        winningArcLayer.lineWidth = configuration.lineWidth
        glowLayer.lineWidth = configuration.lineWidth
        
        winningGradientLayer.colors = configuration.winningGradientColors.map(\.cgColor)
        
        hubLayer.fillColor = configuration.hubColor.cgColor
        hubLayer.strokeColor = configuration.hubBorderColor.cgColor
        hubLayer.lineWidth = 2.0
        
        hubInnerDotLayer.fillColor = configuration.needleColor.cgColor
        
        needleShaftLayer.fillColor = configuration.needleColor.cgColor
        needleTipLayer.fillColor = configuration.needleTipColor.cgColor
    }
    
    // MARK: - Layout
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 && bounds.height > 0 else { return }
        
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = max(10, (min(bounds.width, bounds.height) - configuration.lineWidth * 2.5) / 2.0)
        let startAngle = configuration.startAngle
        let endAngle = startAngle + (2.0 * CGFloat.pi)
        
        // Circular track path
        let circularPath = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: true
        )
        
        trackLayer.path = circularPath.cgPath
        trackLayer.frame = bounds
        
        glowLayer.path = circularPath.cgPath
        glowLayer.frame = bounds
        glowLayer.strokeEnd = CGFloat(chance / 100.0)
        
        winningArcLayer.path = circularPath.cgPath
        winningArcLayer.frame = bounds
        
        winningGradientLayer.frame = bounds
        
        // Tick marks path
        updateTickMarks(center: center, radius: radius)
        
        // Needle geometry
        updateNeedleLayout(center: center, radius: radius)
    }
    
    private func updateTickMarks(center: CGPoint, radius: CGFloat) {
        let path = UIBezierPath()
        let count = configuration.minorTickCount
        let innerRadiusMinor = radius - configuration.lineWidth * 0.85
        let outerRadiusMinor = radius - configuration.lineWidth * 0.65
        let innerRadiusMajor = radius - configuration.lineWidth * 0.95
        let outerRadiusMajor = radius - configuration.lineWidth * 0.55
        
        for i in 0..<count {
            let angle = configuration.startAngle + (CGFloat(i) / CGFloat(count)) * (2.0 * .pi)
            let isMajor = (i % (count / configuration.majorTickCount) == 0)
            let rIn = isMajor ? innerRadiusMajor : innerRadiusMinor
            let rOut = isMajor ? outerRadiusMajor : outerRadiusMinor
            
            let p1 = CGPoint(
                x: center.x + rIn * cos(angle),
                y: center.y + rIn * sin(angle)
            )
            let p2 = CGPoint(
                x: center.x + rOut * cos(angle),
                y: center.y + rOut * sin(angle)
            )
            path.move(to: p1)
            path.addLine(to: p2)
        }
        
        ticksLayer.path = path.cgPath
        ticksLayer.strokeColor = UIColor(white: 0.5, alpha: 0.25).cgColor
        ticksLayer.lineWidth = 1.0
        ticksLayer.frame = bounds
    }
    
    private func updateNeedleLayout(center: CGPoint, radius: CGFloat) {
        needleContainerLayer.bounds = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        needleContainerLayer.position = center
        needleContainerLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        let needleLength = radius + (configuration.lineWidth * 0.5)
        let needleBaseHalfWidth: CGFloat = 6.0
        
        // Tapered needle shaft pointing up (at angle 0 = 12 o'clock)
        let needlePath = UIBezierPath()
        needlePath.move(to: CGPoint(x: center.x - needleBaseHalfWidth, y: center.y))
        needlePath.addLine(to: CGPoint(x: center.x, y: center.y - needleLength + 10))
        needlePath.addLine(to: CGPoint(x: center.x + needleBaseHalfWidth, y: center.y))
        needlePath.close()
        needleShaftLayer.path = needlePath.cgPath
        needleShaftLayer.shadowColor = UIColor.black.cgColor
        needleShaftLayer.shadowOffset = CGSize(width: 0, height: 2)
        needleShaftLayer.shadowOpacity = 0.4
        needleShaftLayer.shadowRadius = 4
        
        // Sharp diamond tip
        let tipPath = UIBezierPath()
        tipPath.move(to: CGPoint(x: center.x - 4, y: center.y - needleLength + 10))
        tipPath.addLine(to: CGPoint(x: center.x, y: center.y - needleLength - 4))
        tipPath.addLine(to: CGPoint(x: center.x + 4, y: center.y - needleLength + 10))
        tipPath.close()
        needleTipLayer.path = tipPath.cgPath
        
        // Center hub
        let hubPath = UIBezierPath(
            arcCenter: center,
            radius: configuration.hubRadius,
            startAngle: 0,
            endAngle: 2 * .pi,
            clockwise: true
        )
        hubLayer.path = hubPath.cgPath
        hubLayer.shadowColor = UIColor.black.cgColor
        hubLayer.shadowOffset = CGSize(width: 0, height: 3)
        hubLayer.shadowOpacity = 0.5
        hubLayer.shadowRadius = 5
        
        let dotPath = UIBezierPath(
            arcCenter: center,
            radius: configuration.hubRadius * 0.35,
            startAngle: 0,
            endAngle: 2 * .pi,
            clockwise: true
        )
        hubInnerDotLayer.path = dotPath.cgPath
    }
    
    // MARK: - Public API
    
    /// Updates the winning probability chance and smoothly animates the winning arc & label.
    public func setChance(_ newChance: Double, multiplier: Double? = nil, animated: Bool = true) {
        let clampedChance = max(0.01, min(99.99, newChance))
        let oldChance = chance
        chance = clampedChance
        
        let targetStroke = CGFloat(clampedChance / 100.0)
        
        if animated {
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.35)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
            
            let strokeAnim = CABasicAnimation(keyPath: "strokeEnd")
            strokeAnim.fromValue = winningArcLayer.strokeEnd
            strokeAnim.toValue = targetStroke
            winningArcLayer.strokeEnd = targetStroke
            winningArcLayer.add(strokeAnim, forKey: "strokeAnimation")
            
            let glowAnim = CABasicAnimation(keyPath: "strokeEnd")
            glowAnim.fromValue = glowLayer.strokeEnd
            glowAnim.toValue = targetStroke
            glowLayer.strokeEnd = targetStroke
            glowLayer.add(glowAnim, forKey: "glowStrokeAnimation")
            
            CATransaction.commit()
            
            startLabelCounterAnimation(from: oldChance, to: clampedChance)
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            winningArcLayer.strokeEnd = targetStroke
            glowLayer.strokeEnd = targetStroke
            CATransaction.commit()
            percentageLabel.text = String(format: "%.2f%%", clampedChance)
        }
        
        if let mult = multiplier {
            multiplierBadge.text = String(format: "x%.2f", mult)
        } else {
            let computedMult = clampedChance > 0 ? (100.0 / clampedChance) * 0.95 : 1.0
            multiplierBadge.text = String(format: "x%.2f", computedMult)
        }
    }
    
    /// Performs the authentic 2.4s spin animation with cubic easing to the final rolled percentage.
    /// - Parameters:
    ///   - roll: The outcome value in 0.0 ... 100.0.
    ///   - duration: Total duration of the spin (default 2.4 seconds).
    ///   - fullRotations: How many full 360-degree spins before landing (default: 4).
    ///   - completion: Callback invoked on completion with whether the roll landed in the winning zone.
    public func spin(
        toRoll roll: Double,
        duration: TimeInterval = 2.4,
        fullRotations: Int = 4,
        completion: ((Bool) -> Void)? = nil
    ) {
        guard !isSpinning else { return }
        isSpinning = true
        
        let normalizedRoll = max(0.0, min(100.0, roll))
        let targetAngle = (CGFloat(normalizedRoll) / 100.0) * (2.0 * CGFloat.pi)
        let totalRotationAngle = currentNeedleAngle + (CGFloat(fullRotations) * 2.0 * CGFloat.pi) + targetAngle
        
        // Haptic feedback sequence during spin
        triggerSpinHaptics(duration: duration)
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        // Authentic casino-grade cubic easing: brisk impulse, gradual cinematic deceleration
        CATransaction.setAnimationTimingFunction(
            CAMediaTimingFunction(controlPoints: Float(0.16), Float(1.0), Float(0.30), Float(1.0))
        )
        
        let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotationAnimation.fromValue = currentNeedleAngle
        rotationAnimation.toValue = totalRotationAngle
        rotationAnimation.fillMode = .forwards
        rotationAnimation.isRemovedOnCompletion = false
        
        CATransaction.setCompletionBlock { [weak self] in
            guard let self = self else { return }
            self.currentNeedleAngle = totalRotationAngle.truncatingRemainder(dividingBy: 2.0 * .pi)
            self.needleContainerLayer.transform = CATransform3DMakeRotation(self.currentNeedleAngle, 0, 0, 1)
            self.needleContainerLayer.removeAllAnimations()
            self.isSpinning = false
            
            let won = normalizedRoll <= self.chance
            self.triggerResultVisualFeedback(won: won)
            completion?(won)
        }
        
        needleContainerLayer.add(rotationAnimation, forKey: "spinNeedleAnimation")
        CATransaction.commit()
    }
    
    /// Resets the needle to 12 o'clock.
    public func resetNeedle(animated: Bool = true) {
        if animated {
            UIView.animate(withDuration: 0.3) {
                self.needleContainerLayer.transform = CATransform3DIdentity
            }
        } else {
            needleContainerLayer.transform = CATransform3DIdentity
        }
        currentNeedleAngle = 0.0
    }
    
    // MARK: - Private Animation & Haptic Helpers
    
    private func triggerSpinHaptics(duration: TimeInterval) {
        let feedback = UISelectionFeedbackGenerator()
        feedback.prepare()
        
        // Tick ticks decreasing in frequency over the 2.4s window
        let tickTimes: [Double] = [0.1, 0.25, 0.45, 0.7, 1.0, 1.35, 1.7, 2.05, 2.25]
        for t in tickTimes where t < duration {
            DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                feedback.selectionChanged()
            }
        }
    }
    
    private func triggerResultVisualFeedback(won: Bool) {
        if won {
            // Victorious glow pulse
            let pulse = CABasicAnimation(keyPath: "transform.scale")
            pulse.duration = 0.25
            pulse.fromValue = 1.0
            pulse.toValue = 1.08
            pulse.autoreverses = true
            pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer.add(pulse, forKey: "winPulse")
            
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            // Loss subtle shake
            let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
            shake.timingFunction = CAMediaTimingFunction(name: .linear)
            shake.duration = 0.45
            shake.values = [-8, 8, -6, 6, -3, 3, 0]
            layer.add(shake, forKey: "lossShake")
            
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
    
    private func startLabelCounterAnimation(from startVal: Double, to endVal: Double) {
        displayLink?.invalidate()
        startChanceValue = startVal
        targetChanceValue = endVal
        animationStartTime = CACurrentMediaTime()
        
        displayLink = CADisplayLink(target: self, selector: #selector(handleDisplayLinkUpdate))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func handleDisplayLinkUpdate() {
        let elapsed = CACurrentMediaTime() - animationStartTime
        let progress = min(1.0, elapsed / animationDuration)
        let easeOutProgress = 1.0 - pow(1.0 - progress, 3.0)
        
        let currentVal = startChanceValue + (targetChanceValue - startChanceValue) * easeOutProgress
        percentageLabel.text = String(format: "%.2f%%", currentVal)
        
        if progress >= 1.0 {
            displayLink?.invalidate()
            displayLink = nil
            percentageLabel.text = String(format: "%.2f%%", targetChanceValue)
        }
    }
}
#endif
