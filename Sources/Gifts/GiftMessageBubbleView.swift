#if canImport(UIKit)
import UIKit
import WhiteGramCore

public final class GiftMessageBubbleView: UIView {
    
    // MARK: - Properties
    
    public var gift: WhiteGramGift {
        didSet {
            updateContent()
        }
    }
    
    public var isOutgoing: Bool {
        didSet {
            updateBubbleStyling()
        }
    }
    
    public var onUnpackCompleted: ((WhiteGramGift) -> Void)?
    public var onOpenShelfTapped: ((WhiteGramGift) -> Void)?
    
    private let bubbleContainerView = UIView()
    private let headerLabel = UILabel()
    private let giftIconContainer = UIView()
    private let giftIconLabel = UILabel()
    private let titleLabel = UILabel()
    private let rarityBadge = UILabel()
    private let nftEditionLabel = UILabel()
    private let messageBubbleView = UIView()
    private let messageTextLabel = UILabel()
    private let actionButton = UIButton(type: .system)
    private let timestampLabel = UILabel()
    
    // MARK: - Initializer
    
    public init(gift: WhiteGramGift, isOutgoing: Bool = false) {
        self.gift = gift
        self.isOutgoing = isOutgoing
        super.init(frame: .zero)
        setupUI()
        updateContent()
        updateBubbleStyling()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        backgroundColor = .clear
        
        bubbleContainerView.translatesAutoresizingMaskIntoConstraints = false
        bubbleContainerView.layer.cornerRadius = 18
        bubbleContainerView.layer.masksToBounds = true
        addSubview(bubbleContainerView)
        
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.font = .systemFont(ofSize: 12, weight: .bold)
        bubbleContainerView.addSubview(headerLabel)
        
        giftIconContainer.translatesAutoresizingMaskIntoConstraints = false
        giftIconContainer.layer.cornerRadius = 32
        giftIconContainer.backgroundColor = .tertiarySystemBackground
        bubbleContainerView.addSubview(giftIconContainer)
        
        giftIconLabel.translatesAutoresizingMaskIntoConstraints = false
        giftIconLabel.font = .systemFont(ofSize: 38)
        giftIconLabel.textAlignment = .center
        giftIconContainer.addSubview(giftIconLabel)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        titleLabel.textAlignment = .center
        bubbleContainerView.addSubview(titleLabel)
        
        rarityBadge.translatesAutoresizingMaskIntoConstraints = false
        rarityBadge.font = .systemFont(ofSize: 11, weight: .heavy)
        rarityBadge.textAlignment = .center
        bubbleContainerView.addSubview(rarityBadge)
        
        nftEditionLabel.translatesAutoresizingMaskIntoConstraints = false
        nftEditionLabel.font = .monospacedSystemFont(ofSize: 10, weight: .semibold)
        nftEditionLabel.textColor = .secondaryLabel
        nftEditionLabel.textAlignment = .center
        bubbleContainerView.addSubview(nftEditionLabel)
        
        messageBubbleView.translatesAutoresizingMaskIntoConstraints = false
        messageBubbleView.backgroundColor = .tertiarySystemBackground
        messageBubbleView.layer.cornerRadius = 10
        bubbleContainerView.addSubview(messageBubbleView)
        
        messageTextLabel.translatesAutoresizingMaskIntoConstraints = false
        messageTextLabel.font = .systemFont(ofSize: 13, weight: .regular)
        messageTextLabel.textColor = .label
        messageTextLabel.numberOfLines = 0
        messageBubbleView.addSubview(messageTextLabel)
        
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        actionButton.layer.cornerRadius = 12
        actionButton.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
        bubbleContainerView.addSubview(actionButton)
        
        timestampLabel.translatesAutoresizingMaskIntoConstraints = false
        timestampLabel.font = .systemFont(ofSize: 10, weight: .regular)
        timestampLabel.textColor = .secondaryLabel
        bubbleContainerView.addSubview(timestampLabel)
        
        NSLayoutConstraint.activate([
            bubbleContainerView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            bubbleContainerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            bubbleContainerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            bubbleContainerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            bubbleContainerView.widthAnchor.constraint(lessThanOrEqualToConstant: 290),
            
            headerLabel.topAnchor.constraint(equalTo: bubbleContainerView.topAnchor, constant: 10),
            headerLabel.leadingAnchor.constraint(equalTo: bubbleContainerView.leadingAnchor, constant: 14),
            headerLabel.trailingAnchor.constraint(equalTo: bubbleContainerView.trailingAnchor, constant: -14),
            
            giftIconContainer.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 10),
            giftIconContainer.centerXAnchor.constraint(equalTo: bubbleContainerView.centerXAnchor),
            giftIconContainer.widthAnchor.constraint(equalToConstant: 64),
            giftIconContainer.heightAnchor.constraint(equalToConstant: 64),
            
            giftIconLabel.centerXAnchor.constraint(equalTo: giftIconContainer.centerXAnchor),
            giftIconLabel.centerYAnchor.constraint(equalTo: giftIconContainer.centerYAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: giftIconContainer.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: bubbleContainerView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: bubbleContainerView.trailingAnchor, constant: -12),
            
            rarityBadge.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            rarityBadge.centerXAnchor.constraint(equalTo: bubbleContainerView.centerXAnchor),
            
            nftEditionLabel.topAnchor.constraint(equalTo: rarityBadge.bottomAnchor, constant: 2),
            nftEditionLabel.centerXAnchor.constraint(equalTo: bubbleContainerView.centerXAnchor),
            
            messageBubbleView.topAnchor.constraint(equalTo: nftEditionLabel.bottomAnchor, constant: 8),
            messageBubbleView.leadingAnchor.constraint(equalTo: bubbleContainerView.leadingAnchor, constant: 12),
            messageBubbleView.trailingAnchor.constraint(equalTo: bubbleContainerView.trailingAnchor, constant: -12),
            
            messageTextLabel.topAnchor.constraint(equalTo: messageBubbleView.topAnchor, constant: 8),
            messageTextLabel.leadingAnchor.constraint(equalTo: messageBubbleView.leadingAnchor, constant: 10),
            messageTextLabel.trailingAnchor.constraint(equalTo: messageBubbleView.trailingAnchor, constant: -10),
            messageTextLabel.bottomAnchor.constraint(equalTo: messageBubbleView.bottomAnchor, constant: -8),
            
            actionButton.topAnchor.constraint(equalTo: messageBubbleView.bottomAnchor, constant: 10),
            actionButton.leadingAnchor.constraint(equalTo: bubbleContainerView.leadingAnchor, constant: 12),
            actionButton.trailingAnchor.constraint(equalTo: bubbleContainerView.trailingAnchor, constant: -12),
            actionButton.heightAnchor.constraint(equalToConstant: 38),
            
            timestampLabel.topAnchor.constraint(equalTo: actionButton.bottomAnchor, constant: 6),
            timestampLabel.trailingAnchor.constraint(equalTo: bubbleContainerView.trailingAnchor, constant: -12),
            timestampLabel.bottomAnchor.constraint(equalTo: bubbleContainerView.bottomAnchor, constant: -8)
        ])
    }
    
    private func updateBubbleStyling() {
        if isOutgoing {
            bubbleContainerView.backgroundColor = UIColor(red: 0.18, green: 0.58, blue: 0.94, alpha: 0.15)
            headerLabel.textColor = UIColor(red: 0.18, green: 0.58, blue: 0.94, alpha: 1.0)
            headerLabel.text = "🎁 You sent a gift"
        } else {
            bubbleContainerView.backgroundColor = .secondarySystemBackground
            headerLabel.textColor = .label
            let sender = gift.originalSenderName ?? "Someone"
            headerLabel.text = "🎁 Gift from \(sender)"
        }
    }
    
    private func updateContent() {
        let rarityColor = UIColor(bubbleHex: gift.rarity.hexColor)
        rarityBadge.textColor = rarityColor
        rarityBadge.text = "\(gift.rarity.badgeEmoji) \(gift.rarity.title.uppercased())"
        
        if gift.isUnpacked {
            giftIconLabel.text = gift.iconEmoji
            titleLabel.text = gift.title
            titleLabel.textColor = .label
            
            if gift.isUniqueNFT, let nft = gift.nftAttributes {
                nftEditionLabel.isHidden = false
                nftEditionLabel.text = "TON NFT: \(nft.formattedEdition)"
            } else {
                nftEditionLabel.isHidden = true
            }
            
            actionButton.setTitle("View in Profile Shelf ✨", for: .normal)
            actionButton.backgroundColor = rarityColor.withAlphaComponent(0.18)
            actionButton.setTitleColor(rarityColor, for: .normal)
        } else {
            // Packed state
            giftIconLabel.text = "📦"
            titleLabel.text = "Surprise Gift Box"
            titleLabel.textColor = .secondaryLabel
            nftEditionLabel.isHidden = false
            nftEditionLabel.text = "Sealed Mystery Gift"
            
            actionButton.setTitle("🎁 Unpack Gift", for: .normal)
            actionButton.backgroundColor = rarityColor
            actionButton.setTitleColor(.white, for: .normal)
        }
        
        if let msg = gift.giftMessage, !msg.isEmpty {
            messageBubbleView.isHidden = false
            messageTextLabel.text = "\"\(msg)\""
        } else {
            messageBubbleView.isHidden = true
        }
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        timestampLabel.text = formatter.string(from: gift.sentDate)
    }
    
    // MARK: - Action Handling
    
    @objc private func actionButtonTapped() {
        if !gift.isUnpacked {
            // Launch Unpack Animation
            if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first {
                let overlay = GiftUnpackAnimationView(gift: gift) { [weak self] unpackedGift in
                    guard let self = self else { return }
                    self.gift = unpackedGift
                    self.updateContent()
                    self.onUnpackCompleted?(unpackedGift)
                }
                overlay.frame = window.bounds
                window.addSubview(overlay)
                overlay.startUnpackSequence()
            }
        } else {
            onOpenShelfTapped?(gift)
        }
    }
}

// MARK: - Internal Hex Helper

fileprivate extension UIColor {
    convenience init(bubbleHex hex: String) {
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
