#if canImport(UIKit)
import UIKit
import WhiteGramCore

public final class GiftTransferController: UIViewController, UITextFieldDelegate {
    
    // MARK: - Properties
    
    public var gift: WhiteGramGift
    public var currentUserId: Int64
    public var onTransferCompleted: ((WhiteGramGift, Int64) -> Void)?
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // Preview card
    private let previewCardView = UIView()
    private let giftIconLabel = UILabel()
    private let giftTitleLabel = UILabel()
    private let rarityBadgeLabel = UILabel()
    private let nftEditionLabel = UILabel()
    
    // Recipient Section
    private let recipientHeaderLabel = UILabel()
    private let recipientTextField = UITextField()
    private let quickRecipientStackView = UIStackView()
    
    // Message Section
    private let messageHeaderLabel = UILabel()
    private let messageTextField = UITextField()
    
    // Options
    private let shelfSwitchContainer = UIView()
    private let shelfSwitchLabel = UILabel()
    private let shelfSwitch = UISwitch()
    
    private let anonymousSwitchContainer = UIView()
    private let anonymousSwitchLabel = UILabel()
    private let anonymousSwitch = UISwitch()
    
    // Info Pill
    private let protocolPillLabel = UILabel()
    
    // Action Button
    private let sendButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    
    // MARK: - Initializer
    
    public init(
        gift: WhiteGramGift,
        currentUserId: Int64,
        preselectedRecipientId: Int64? = nil,
        preselectedRecipientUsername: String? = nil
    ) {
        self.gift = gift
        self.currentUserId = currentUserId
        super.init(nibName: nil, bundle: nil)
        
        if let username = preselectedRecipientUsername {
            self.recipientTextField.text = username.hasPrefix("@") ? username : "@\(username)"
        } else if let recId = preselectedRecipientId {
            self.recipientTextField.text = "\(recId)"
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        populateGiftData()
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Send Gift"
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        setupPreviewCard()
        setupRecipientSection()
        setupMessageSection()
        setupSwitches()
        setupProtocolPill()
        setupSendButton()
    }
    
    private func setupPreviewCard() {
        previewCardView.translatesAutoresizingMaskIntoConstraints = false
        previewCardView.backgroundColor = .secondarySystemBackground
        previewCardView.layer.cornerRadius = 18
        previewCardView.layer.borderWidth = 1.5
        previewCardView.layer.borderColor = UIColor(giftsHex: gift.rarity.hexColor).withAlphaComponent(0.6).cgColor
        
        giftIconLabel.translatesAutoresizingMaskIntoConstraints = false
        giftIconLabel.font = .systemFont(ofSize: 56)
        giftIconLabel.textAlignment = .center
        
        giftTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        giftTitleLabel.font = .systemFont(ofSize: 19, weight: .bold)
        giftTitleLabel.textColor = .label
        giftTitleLabel.textAlignment = .center
        
        rarityBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        rarityBadgeLabel.font = .systemFont(ofSize: 12, weight: .heavy)
        rarityBadgeLabel.textColor = UIColor(giftsHex: gift.rarity.hexColor)
        rarityBadgeLabel.textAlignment = .center
        
        nftEditionLabel.translatesAutoresizingMaskIntoConstraints = false
        nftEditionLabel.font = .monospacedSystemFont(ofSize: 11, weight: .semibold)
        nftEditionLabel.textColor = .secondaryLabel
        nftEditionLabel.textAlignment = .center
        
        previewCardView.addSubview(giftIconLabel)
        previewCardView.addSubview(giftTitleLabel)
        previewCardView.addSubview(rarityBadgeLabel)
        previewCardView.addSubview(nftEditionLabel)
        contentView.addSubview(previewCardView)
        
        NSLayoutConstraint.activate([
            previewCardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            previewCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            previewCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            giftIconLabel.topAnchor.constraint(equalTo: previewCardView.topAnchor, constant: 16),
            giftIconLabel.centerXAnchor.constraint(equalTo: previewCardView.centerXAnchor),
            
            giftTitleLabel.topAnchor.constraint(equalTo: giftIconLabel.bottomAnchor, constant: 8),
            giftTitleLabel.leadingAnchor.constraint(equalTo: previewCardView.leadingAnchor, constant: 12),
            giftTitleLabel.trailingAnchor.constraint(equalTo: previewCardView.trailingAnchor, constant: -12),
            
            rarityBadgeLabel.topAnchor.constraint(equalTo: giftTitleLabel.bottomAnchor, constant: 4),
            rarityBadgeLabel.centerXAnchor.constraint(equalTo: previewCardView.centerXAnchor),
            
            nftEditionLabel.topAnchor.constraint(equalTo: rarityBadgeLabel.bottomAnchor, constant: 4),
            nftEditionLabel.centerXAnchor.constraint(equalTo: previewCardView.centerXAnchor),
            nftEditionLabel.bottomAnchor.constraint(equalTo: previewCardView.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupRecipientSection() {
        recipientHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        recipientHeaderLabel.text = "RECIPIENT (NO BOT REQUIRED)"
        recipientHeaderLabel.font = .systemFont(ofSize: 12, weight: .bold)
        recipientHeaderLabel.textColor = .secondaryLabel
        contentView.addSubview(recipientHeaderLabel)
        
        recipientTextField.translatesAutoresizingMaskIntoConstraints = false
        recipientTextField.placeholder = "@username or User ID (e.g. 1087968824)"
        recipientTextField.backgroundColor = .secondarySystemBackground
        recipientTextField.layer.cornerRadius = 12
        recipientTextField.font = .systemFont(ofSize: 15)
        recipientTextField.autocapitalizationType = .none
        recipientTextField.autocorrectionType = .no
        recipientTextField.clearButtonMode = .whileEditing
        recipientTextField.delegate = self
        
        let leftPadding = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 44))
        recipientTextField.leftView = leftPadding
        recipientTextField.leftViewMode = .always
        contentView.addSubview(recipientTextField)
        
        quickRecipientStackView.translatesAutoresizingMaskIntoConstraints = false
        quickRecipientStackView.axis = .horizontal
        quickRecipientStackView.spacing = 8
        quickRecipientStackView.distribution = .fillEqually
        contentView.addSubview(quickRecipientStackView)
        
        let presets = ["Saved Messages", "@durov", "@alice", "@crypto_bot"]
        for preset in presets {
            let chip = UIButton(type: .system)
            chip.setTitle(preset, for: .normal)
            chip.titleLabel?.font = .systemFont(ofSize: 11, weight: .medium)
            chip.backgroundColor = .tertiarySystemBackground
            chip.layer.cornerRadius = 8
            chip.addTarget(self, action: #selector(quickRecipientTapped(_:)), for: .touchUpInside)
            quickRecipientStackView.addArrangedSubview(chip)
        }
        
        NSLayoutConstraint.activate([
            recipientHeaderLabel.topAnchor.constraint(equalTo: previewCardView.bottomAnchor, constant: 20),
            recipientHeaderLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            
            recipientTextField.topAnchor.constraint(equalTo: recipientHeaderLabel.bottomAnchor, constant: 8),
            recipientTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            recipientTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            recipientTextField.heightAnchor.constraint(equalToConstant: 46),
            
            quickRecipientStackView.topAnchor.constraint(equalTo: recipientTextField.bottomAnchor, constant: 8),
            quickRecipientStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            quickRecipientStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            quickRecipientStackView.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    private func setupMessageSection() {
        messageHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        messageHeaderLabel.text = "CONGRATULATORY MESSAGE (OPTIONAL)"
        messageHeaderLabel.font = .systemFont(ofSize: 12, weight: .bold)
        messageHeaderLabel.textColor = .secondaryLabel
        contentView.addSubview(messageHeaderLabel)
        
        messageTextField.translatesAutoresizingMaskIntoConstraints = false
        messageTextField.placeholder = "Write a warm message or greeting..."
        messageTextField.backgroundColor = .secondarySystemBackground
        messageTextField.layer.cornerRadius = 12
        messageTextField.font = .systemFont(ofSize: 15)
        messageTextField.clearButtonMode = .whileEditing
        messageTextField.delegate = self
        
        let leftPadding = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 44))
        messageTextField.leftView = leftPadding
        messageTextField.leftViewMode = .always
        contentView.addSubview(messageTextField)
        
        NSLayoutConstraint.activate([
            messageHeaderLabel.topAnchor.constraint(equalTo: quickRecipientStackView.bottomAnchor, constant: 20),
            messageHeaderLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            
            messageTextField.topAnchor.constraint(equalTo: messageHeaderLabel.bottomAnchor, constant: 8),
            messageTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            messageTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            messageTextField.heightAnchor.constraint(equalToConstant: 46)
        ])
    }
    
    private func setupSwitches() {
        // Shelf Switch
        shelfSwitchContainer.translatesAutoresizingMaskIntoConstraints = false
        shelfSwitchContainer.backgroundColor = .secondarySystemBackground
        shelfSwitchContainer.layer.cornerRadius = 12
        contentView.addSubview(shelfSwitchContainer)
        
        shelfSwitchLabel.translatesAutoresizingMaskIntoConstraints = false
        shelfSwitchLabel.text = "Show on recipient's profile shelf"
        shelfSwitchLabel.font = .systemFont(ofSize: 14, weight: .medium)
        shelfSwitchLabel.textColor = .label
        shelfSwitchContainer.addSubview(shelfSwitchLabel)
        
        shelfSwitch.translatesAutoresizingMaskIntoConstraints = false
        shelfSwitch.isOn = true
        shelfSwitchContainer.addSubview(shelfSwitch)
        
        // Anonymous Switch
        anonymousSwitchContainer.translatesAutoresizingMaskIntoConstraints = false
        anonymousSwitchContainer.backgroundColor = .secondarySystemBackground
        anonymousSwitchContainer.layer.cornerRadius = 12
        contentView.addSubview(anonymousSwitchContainer)
        
        anonymousSwitchLabel.translatesAutoresizingMaskIntoConstraints = false
        anonymousSwitchLabel.text = "Send anonymously (hide my name)"
        anonymousSwitchLabel.font = .systemFont(ofSize: 14, weight: .medium)
        anonymousSwitchLabel.textColor = .label
        anonymousSwitchContainer.addSubview(anonymousSwitchLabel)
        
        anonymousSwitch.translatesAutoresizingMaskIntoConstraints = false
        anonymousSwitch.isOn = false
        anonymousSwitchContainer.addSubview(anonymousSwitch)
        
        NSLayoutConstraint.activate([
            shelfSwitchContainer.topAnchor.constraint(equalTo: messageTextField.bottomAnchor, constant: 16),
            shelfSwitchContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            shelfSwitchContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            shelfSwitchContainer.heightAnchor.constraint(equalToConstant: 48),
            
            shelfSwitchLabel.centerYAnchor.constraint(equalTo: shelfSwitchContainer.centerYAnchor),
            shelfSwitchLabel.leadingAnchor.constraint(equalTo: shelfSwitchContainer.leadingAnchor, constant: 14),
            shelfSwitch.centerYAnchor.constraint(equalTo: shelfSwitchContainer.centerYAnchor),
            shelfSwitch.trailingAnchor.constraint(equalTo: shelfSwitchContainer.trailingAnchor, constant: -14),
            
            anonymousSwitchContainer.topAnchor.constraint(equalTo: shelfSwitchContainer.bottomAnchor, constant: 8),
            anonymousSwitchContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            anonymousSwitchContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            anonymousSwitchContainer.heightAnchor.constraint(equalToConstant: 48),
            
            anonymousSwitchLabel.centerYAnchor.constraint(equalTo: anonymousSwitchContainer.centerYAnchor),
            anonymousSwitchLabel.leadingAnchor.constraint(equalTo: anonymousSwitchContainer.leadingAnchor, constant: 14),
            anonymousSwitch.centerYAnchor.constraint(equalTo: anonymousSwitchContainer.centerYAnchor),
            anonymousSwitch.trailingAnchor.constraint(equalTo: anonymousSwitchContainer.trailingAnchor, constant: -14)
        ])
    }
    
    private func setupProtocolPill() {
        protocolPillLabel.translatesAutoresizingMaskIntoConstraints = false
        protocolPillLabel.text = "⚡ Direct WhiteGram P2P • Gasless Instant Transfer • No Commands"
        protocolPillLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        protocolPillLabel.textColor = .systemGreen
        protocolPillLabel.textAlignment = .center
        contentView.addSubview(protocolPillLabel)
        
        NSLayoutConstraint.activate([
            protocolPillLabel.topAnchor.constraint(equalTo: anonymousSwitchContainer.bottomAnchor, constant: 16),
            protocolPillLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            protocolPillLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }
    
    private func setupSendButton() {
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.setTitle("Send Gift 🎁", for: .normal)
        sendButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        sendButton.backgroundColor = UIColor(giftsHex: gift.rarity.hexColor)
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.layer.cornerRadius = 14
        sendButton.addTarget(self, action: #selector(sendButtonTapped), for: .touchUpInside)
        contentView.addSubview(sendButton)
        
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        cancelButton.setTitleColor(.secondaryLabel, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        contentView.addSubview(cancelButton)
        
        NSLayoutConstraint.activate([
            sendButton.topAnchor.constraint(equalTo: protocolPillLabel.bottomAnchor, constant: 18),
            sendButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            sendButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            sendButton.heightAnchor.constraint(equalToConstant: 52),
            
            cancelButton.topAnchor.constraint(equalTo: sendButton.bottomAnchor, constant: 8),
            cancelButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            cancelButton.heightAnchor.constraint(equalToConstant: 40),
            cancelButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])
    }
    
    private func populateGiftData() {
        giftIconLabel.text = gift.iconEmoji
        giftTitleLabel.text = gift.title
        rarityBadgeLabel.text = "\(gift.rarity.badgeEmoji) \(gift.rarity.title.uppercased())"
        
        if gift.isUniqueNFT, let nft = gift.nftAttributes {
            nftEditionLabel.isHidden = false
            nftEditionLabel.text = "TON NFT: \(nft.formattedEdition) • Token \(nft.tokenId)"
        } else {
            nftEditionLabel.isHidden = true
        }
    }
    
    // MARK: - Actions
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func quickRecipientTapped(_ sender: UIButton) {
        guard let text = sender.titleLabel?.text else { return }
        if text == "Saved Messages" {
            recipientTextField.text = "\(currentUserId)"
        } else {
            recipientTextField.text = text
        }
    }
    
    @objc private func sendButtonTapped() {
        dismissKeyboard()
        
        guard let recipientText = recipientTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !recipientText.isEmpty else {
            showAlert(title: "Recipient Required", message: "Please specify a username (@example) or numerical User ID.")
            return
        }
        
        // Resolve recipient ID
        var targetUserId: Int64 = 0
        var targetUsername: String? = nil
        
        if recipientText.hasPrefix("@") {
            targetUsername = recipientText
            // Deterministic hash / mock ID for username in standalone test mode
            targetUserId = Int64(abs(recipientText.lowercased().hashValue % 1_000_000_000) + 100_000_000)
        } else if let parsedId = Int64(recipientText) {
            targetUserId = parsedId
        } else {
            targetUsername = "@" + recipientText
            targetUserId = Int64(abs(recipientText.lowercased().hashValue % 1_000_000_000) + 100_000_000)
        }
        
        let message = messageTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let isAnon = anonymousSwitch.isOn
        
        // Execute Transfer via GiftStorage
        do {
            let updatedGift = try GiftStorage.shared.transferGift(
                giftId: gift.id,
                fromUserId: currentUserId,
                toUserId: targetUserId,
                toUsername: targetUsername,
                message: message?.isEmpty == true ? nil : message,
                isAnonymous: isAnon
            )
            
            // Haptic celebration
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            self.onTransferCompleted?(updatedGift, targetUserId)
            
            let alert = UIAlertController(
                title: "Gift Sent! 🎁",
                message: "'\(updatedGift.title)' has been successfully transferred to \(targetUsername ?? "User \(targetUserId)").",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Awesome", style: .default, handler: { [weak self] _ in
                self?.dismiss(animated: true, completion: nil)
            }))
            present(alert, animated: true)
            
        } catch {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            showAlert(title: "Transfer Failed", message: error.localizedDescription)
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - Internal Color Extension

fileprivate extension UIColor {
    convenience init(giftsHex hex: String) {
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
