#if canImport(UIKit)
import UIKit
import WhiteGramCore

public final class GiftUnpackAnimationView: UIView {
    
    // MARK: - Properties
    
    public var gift: WhiteGramGift
    public var onComplete: ((WhiteGramGift) -> Void)?
    
    private let blurBackgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let raysContainerView = UIView()
    private let boxContainerView = UIView()
    private let boxEmojiLabel = UILabel()
    private let revealedIconLabel = UILabel()
    private let celebrationTitleLabel = UILabel()
    private let rarityBadge = UILabel()
    private let nftBadge = UILabel()
    private let giftTitleLabel = UILabel()
    private let messageCardView = UIView()
    private let messageLabel = UILabel()
    private let claimButton = UIButton(type: .system)
    
    private var emitterLayer: CAEmitterLayer?
    
    // MARK: - Initializer
    
    public init(gift: WhiteGramGift, onComplete: ((WhiteGramGift) -> Void)? = nil) {
        self.gift = gift
        self.onComplete = onComplete
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        blurBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blurBackgroundView)
        
        raysContainerView.translatesAutoresizingMaskIntoConstraints = false
        raysContainerView.alpha = 0
        addSubview(raysContainerView)
        
        boxContainerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(boxContainerView)
        
        boxEmojiLabel.translatesAutoresizingMaskIntoConstraints = false
        boxEmojiLabel.text = "🎁"
        boxEmojiLabel.font = .systemFont(ofSize: 110)
        boxEmojiLabel.textAlignment = .center
        boxContainerView.addSubview(boxEmojiLabel)
        
        revealedIconLabel.translatesAutoresizingMaskIntoConstraints = false
        revealedIconLabel.text = gift.iconEmoji
        revealedIconLabel.font = .systemFont(ofSize: 100)
        revealedIconLabel.textAlignment = .center
        revealedIconLabel.alpha = 0
        revealedIconLabel.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        addSubview(revealedIconLabel)
        
        celebrationTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        celebrationTitleLabel.text = "NEW GIFT UNLOCKED!"
        celebrationTitleLabel.font = .systemFont(ofSize: 14, weight: .black)
        celebrationTitleLabel.textColor = .systemYellow
        celebrationTitleLabel.alpha = 0
        addSubview(celebrationTitleLabel)
        
        rarityBadge.translatesAutoresizingMaskIntoConstraints = false
        rarityBadge.text = "\(gift.rarity.badgeEmoji) \(gift.rarity.title.uppercased())"
        rarityBadge.font = .systemFont(ofSize: 16, weight: .heavy)
        rarityBadge.textColor = UIColor(unpackHex: gift.rarity.hexColor)
        rarityBadge.alpha = 0
        addSubview(rarityBadge)
        
        nftBadge.translatesAutoresizingMaskIntoConstraints = false
        nftBadge.font = .monospacedSystemFont(ofSize: 12, weight: .bold)
        nftBadge.textColor = .white
        nftBadge.backgroundColor = UIColor(unpackHex: gift.rarity.hexColor).withAlphaComponent(0.8)
        nftBadge.layer.cornerRadius = 8
        nftBadge.layer.masksToBounds = true
        nftBadge.textAlignment = .center
        nftBadge.alpha = 0
        if gift.isUniqueNFT, let nft = gift.nftAttributes {
            nftBadge.text = " TON NFT \(nft.formattedEdition) "
        }
        addSubview(nftBadge)
        
        giftTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        giftTitleLabel.text = gift.title
        giftTitleLabel.font = .systemFont(ofSize: 26, weight: .bold)
        giftTitleLabel.textColor = .white
        giftTitleLabel.textAlignment = .center
        giftTitleLabel.alpha = 0
        addSubview(giftTitleLabel)
        
        messageCardView.translatesAutoresizingMaskIntoConstraints = false
        messageCardView.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        messageCardView.layer.cornerRadius = 14
        messageCardView.alpha = 0
        addSubview(messageCardView)
        
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = .systemFont(ofSize: 14, weight: .medium)
        messageLabel.textColor = .white
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        if let msg = gift.giftMessage, !msg.isEmpty {
            messageLabel.text = "\"\(msg)\""
        } else {
            messageLabel.text = "Received with love & compliments"
        }
        messageCardView.addSubview(messageLabel)
        
        claimButton.translatesAutoresizingMaskIntoConstraints = false
        claimButton.setTitle("Claim to Profile Shelf ✨", for: .normal)
        claimButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        claimButton.backgroundColor = UIColor(unpackHex: gift.rarity.hexColor)
        claimButton.setTitleColor(.white, for: .normal)
        claimButton.layer.cornerRadius = 16
        claimButton.alpha = 0
        claimButton.addTarget(self, action: #selector(claimButtonTapped), for: .touchUpInside)
        addSubview(claimButton)
        
        NSLayoutConstraint.activate([
            blurBackgroundView.topAnchor.constraint(equalTo: topAnchor),
            blurBackgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurBackgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurBackgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            raysContainerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            raysContainerView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -40),
            raysContainerView.widthAnchor.constraint(equalToConstant: 300),
            raysContainerView.heightAnchor.constraint(equalToConstant: 300),
            
            boxContainerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            boxContainerView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -40),
            boxContainerView.widthAnchor.constraint(equalToConstant: 160),
            boxContainerView.heightAnchor.constraint(equalToConstant: 160),
            
            boxEmojiLabel.centerXAnchor.constraint(equalTo: boxContainerView.centerXAnchor),
            boxEmojiLabel.centerYAnchor.constraint(equalTo: boxContainerView.centerYAnchor),
            
            revealedIconLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            revealedIconLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -40),
            
            celebrationTitleLabel.bottomAnchor.constraint(equalTo: revealedIconLabel.topAnchor, constant: -16),
            celebrationTitleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            
            rarityBadge.topAnchor.constraint(equalTo: revealedIconLabel.bottomAnchor, constant: 14),
            rarityBadge.centerXAnchor.constraint(equalTo: centerXAnchor),
            
            nftBadge.topAnchor.constraint(equalTo: rarityBadge.bottomAnchor, constant: 6),
            nftBadge.centerXAnchor.constraint(equalTo: centerXAnchor),
            nftBadge.heightAnchor.constraint(equalToConstant: 22),
            
            giftTitleLabel.topAnchor.constraint(equalTo: gift.isUniqueNFT ? nftBadge.bottomAnchor : rarityBadge.bottomAnchor, constant: 8),
            giftTitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            giftTitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            
            messageCardView.topAnchor.constraint(equalTo: giftTitleLabel.bottomAnchor, constant: 16),
            messageCardView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            messageCardView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),
            
            messageLabel.topAnchor.constraint(equalTo: messageCardView.topAnchor, constant: 12),
            messageLabel.leadingAnchor.constraint(equalTo: messageCardView.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: messageCardView.trailingAnchor, constant: -16),
            messageLabel.bottomAnchor.constraint(equalTo: messageCardView.bottomAnchor, constant: -12),
            
            claimButton.topAnchor.constraint(equalTo: messageCardView.bottomAnchor, constant: 24),
            claimButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            claimButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),
            claimButton.heightAnchor.constraint(equalToConstant: 54)
        ])
    }
    
    // MARK: - Animation Sequence
    
    public func startUnpackSequence() {
        // Step 1: Suspense shake
        let shake = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        shake.values = [-0.15, 0.15, -0.12, 0.12, -0.08, 0.08, 0.0]
        shake.duration = 0.7
        shake.repeatCount = 2
        boxContainerView.layer.add(shake, forKey: "shake")
        
        let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
        impactGenerator.prepare()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { impactGenerator.impactOccurred() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { impactGenerator.impactOccurred() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { impactGenerator.impactOccurred() }
        
        // Step 2: Box bursts open & Confetti explosion
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            guard let self = self else { return }
            self.triggerExplosion()
        }
    }
    
    private func triggerExplosion() {
        // Haptic fanfare
        let notificationGenerator = UINotificationFeedbackGenerator()
        notificationGenerator.notificationOccurred(.success)
        
        // Hide Box
        UIView.animate(withDuration: 0.25, animations: {
            self.boxContainerView.transform = CGAffineTransform(scaleX: 1.4, y: 1.4)
            self.boxContainerView.alpha = 0
        }) { _ in
            self.boxContainerView.isHidden = true
        }
        
        // Launch Confetti Particles
        emitConfettiParticles()
        
        // Reveal Rays
        setupRotatingRays()
        
        // Pop revealed gift icon
        revealedIconLabel.alpha = 1.0
        revealedIconLabel.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        UIView.animate(
            withDuration: 0.7,
            delay: 0.1,
            usingSpringWithDamping: 0.45,
            initialSpringVelocity: 1.2,
            options: .curveEaseOut,
            animations: {
                self.revealedIconLabel.transform = .identity
            },
            completion: nil
        )
        
        // Fade in details & claim button
        UIView.animate(withDuration: 0.5, delay: 0.4, options: .curveEaseIn, animations: {
            self.celebrationTitleLabel.alpha = 1.0
            self.rarityBadge.alpha = 1.0
            if self.gift.isUniqueNFT {
                self.nftBadge.alpha = 1.0
            }
            self.giftTitleLabel.alpha = 1.0
            self.messageCardView.alpha = 1.0
            self.claimButton.alpha = 1.0
        }, completion: nil)
    }
    
    private func setupRotatingRays() {
        raysContainerView.alpha = 1.0
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.toValue = NSNumber(value: Double.pi * 2.0)
        rotation.duration = 10.0
        rotation.isCumulative = true
        rotation.repeatCount = .infinity
        raysContainerView.layer.add(rotation, forKey: "rotationAnimation")
    }
    
    private func emitConfettiParticles() {
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY - 40)
        emitter.emitterShape = .point
        emitter.emitterSize = CGSize(width: 10, height: 10)
        
        let colors: [UIColor] = [
            UIColor(unpackHex: gift.rarity.hexColor),
            .systemYellow,
            .systemCyan,
            .systemPink,
            .white
        ]
        
        var cells: [CAEmitterCell] = []
        for (index, color) in colors.enumerated() {
            let cell = CAEmitterCell()
            cell.birthRate = 25
            cell.lifetime = 3.0
            cell.velocity = CGFloat(200 + index * 40)
            cell.velocityRange = 80
            cell.emissionLongitude = CGFloat.pi * 2
            cell.emissionRange = CGFloat.pi * 2
            cell.spin = 3.5
            cell.spinRange = 4.0
            cell.scale = 0.18
            cell.scaleRange = 0.08
            cell.color = color.cgColor
            cell.contents = createParticleImage()?.cgImage
            cells.append(cell)
        }
        
        emitter.emitterCells = cells
        layer.addSublayer(emitter)
        self.emitterLayer = emitter
        
        // Stop emission after 1.5s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            emitter.birthRate = 0
        }
    }
    
    private func createParticleImage() -> UIImage? {
        let size = CGSize(width: 14, height: 14)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(UIColor.white.cgColor)
        context?.fill(CGRect(origin: .zero, size: size))
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img
    }
    
    // MARK: - Actions
    
    @objc private func claimButtonTapped() {
        gift.isUnpacked = true
        GiftStorage.shared.markAsUnpacked(giftId: gift.id)
        
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 0
        }) { [weak self] _ in
            guard let self = self else { return }
            self.onComplete?(self.gift)
            self.removeFromSuperview()
        }
    }
}

// MARK: - Internal Hex Extension

fileprivate extension UIColor {
    convenience init(unpackHex hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexSanitized.hasPrefix("#") {
            hexSanitized.remove(at: hexSanitized.startIndex)
        }
        var rgbValue: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgbValue)
        self.init(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }
}
#endif
