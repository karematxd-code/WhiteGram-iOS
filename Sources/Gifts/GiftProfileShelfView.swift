#if canImport(UIKit)
import UIKit
import WhiteGramCore

// MARK: - Gift Shelf Collection Cell

public final class GiftShelfCollectionViewCell: UICollectionViewCell {
    public static let identifier = "GiftShelfCollectionViewCell"
    
    private let containerView = UIView()
    private let iconLabel = UILabel()
    private let titleLabel = UILabel()
    private let rarityBadge = UILabel()
    private let nftPill = UILabel()
    private let pinnedBadge = UILabel()
    
    private var currentGift: WhiteGramGift?
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        contentView.backgroundColor = .clear
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .secondarySystemBackground
        containerView.layer.cornerRadius = 16
        containerView.layer.masksToBounds = false
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        containerView.layer.shadowOpacity = 0.15
        containerView.layer.shadowRadius = 8
        contentView.addSubview(containerView)
        
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.font = .systemFont(ofSize: 42)
        iconLabel.textAlignment = .center
        containerView.addSubview(iconLabel)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 12, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        containerView.addSubview(titleLabel)
        
        rarityBadge.translatesAutoresizingMaskIntoConstraints = false
        rarityBadge.font = .systemFont(ofSize: 10, weight: .heavy)
        rarityBadge.textAlignment = .center
        containerView.addSubview(rarityBadge)
        
        nftPill.translatesAutoresizingMaskIntoConstraints = false
        nftPill.font = .monospacedSystemFont(ofSize: 9, weight: .bold)
        nftPill.textColor = .white
        nftPill.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 0.85)
        nftPill.layer.cornerRadius = 6
        nftPill.layer.masksToBounds = true
        nftPill.textAlignment = .center
        containerView.addSubview(nftPill)
        
        pinnedBadge.translatesAutoresizingMaskIntoConstraints = false
        pinnedBadge.text = "📌"
        pinnedBadge.font = .systemFont(ofSize: 12)
        containerView.addSubview(pinnedBadge)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            
            pinnedBadge.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 6),
            pinnedBadge.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            
            iconLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            iconLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: iconLabel.bottomAnchor, constant: 6),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 6),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -6),
            
            rarityBadge.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            rarityBadge.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            nftPill.topAnchor.constraint(equalTo: rarityBadge.bottomAnchor, constant: 4),
            nftPill.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            nftPill.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: 6),
            nftPill.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -6),
            nftPill.heightAnchor.constraint(equalToConstant: 16),
            nftPill.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -6)
        ])
    }
    
    public func configure(with gift: WhiteGramGift) {
        self.currentGift = gift
        iconLabel.text = gift.iconEmoji
        titleLabel.text = gift.title
        rarityBadge.text = gift.rarity.title.uppercased()
        
        let rarityColor = UIColor(shelfHex: gift.rarity.hexColor)
        rarityBadge.textColor = rarityColor
        containerView.layer.borderColor = rarityColor.withAlphaComponent(0.5).cgColor
        containerView.layer.borderWidth = gift.rarity >= .epic ? 1.5 : 0.8
        containerView.layer.shadowColor = rarityColor.cgColor
        
        pinnedBadge.isHidden = !gift.isPinnedToShelf
        
        if gift.isUniqueNFT, let nft = gift.nftAttributes {
            nftPill.isHidden = false
            nftPill.text = " #\(nft.serialNumber)/\(nft.totalEditions) "
        } else {
            nftPill.isHidden = true
        }
    }
    
    public override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.15) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
            }
        }
    }
}

// MARK: - Gift Profile Shelf View

public final class GiftProfileShelfView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    public var userId: Int64 = 0 {
        didSet {
            reloadShelfData()
        }
    }
    
    public var isCurrentAccount: Bool = true
    public var onGiftSelected: ((WhiteGramGift) -> Void)?
    public var onAddGiftTapped: (() -> Void)?
    
    private let headerContainer = UIView()
    private let titleLabel = UILabel()
    private let countBadge = UILabel()
    private let seeAllButton = UIButton(type: .system)
    
    private var collectionView: UICollectionView!
    private let emptyLabel = UILabel()
    
    private var shelfGifts: [WhiteGramGift] = []
    
    // MARK: - Initializer
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        registerForNotifications()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
        registerForNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        backgroundColor = .clear
        
        // Header
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(headerContainer)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "🎁 Gifts Shelf"
        titleLabel.font = .systemFont(ofSize: 17, weight: .bold)
        titleLabel.textColor = .label
        headerContainer.addSubview(titleLabel)
        
        countBadge.translatesAutoresizingMaskIntoConstraints = false
        countBadge.font = .systemFont(ofSize: 12, weight: .bold)
        countBadge.textColor = .secondaryLabel
        countBadge.backgroundColor = .secondarySystemBackground
        countBadge.layer.cornerRadius = 8
        countBadge.layer.masksToBounds = true
        countBadge.textAlignment = .center
        headerContainer.addSubview(countBadge)
        
        seeAllButton.translatesAutoresizingMaskIntoConstraints = false
        seeAllButton.setTitle("See All", for: .normal)
        seeAllButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        seeAllButton.addTarget(self, action: #selector(seeAllTapped), for: .touchUpInside)
        headerContainer.addSubview(seeAllButton)
        
        // Collection View Layout
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 124, height: 148)
        layout.minimumLineSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(GiftShelfCollectionViewCell.self, forCellWithReuseIdentifier: GiftShelfCollectionViewCell.identifier)
        addSubview(collectionView)
        
        // Empty State Label
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.text = "No gifts showcased yet. Tap to craft or receive gifts!"
        emptyLabel.font = .systemFont(ofSize: 13, weight: .regular)
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.textAlignment = .center
        emptyLabel.isHidden = true
        addSubview(emptyLabel)
        
        NSLayoutConstraint.activate([
            headerContainer.topAnchor.constraint(equalTo: topAnchor),
            headerContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            headerContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            headerContainer.heightAnchor.constraint(equalToConstant: 28),
            
            titleLabel.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor),
            
            countBadge.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            countBadge.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            countBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 24),
            countBadge.heightAnchor.constraint(equalToConstant: 18),
            
            seeAllButton.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            seeAllButton.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor),
            
            collectionView.topAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: 10),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            collectionView.heightAnchor.constraint(equalToConstant: 154),
            
            emptyLabel.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor)
        ])
    }
    
    private func registerForNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGiftsUpdated),
            name: GiftStorage.didUpdateGiftsNotification,
            object: nil
        )
    }
    
    @objc private func handleGiftsUpdated() {
        DispatchQueue.main.async { [weak self] in
            self?.reloadShelfData()
        }
    }
    
    public func reloadShelfData() {
        let pinned = GiftStorage.shared.getShelfGifts(for: userId)
        if pinned.isEmpty {
            // If none pinned, show first few owned gifts
            let owned = GiftStorage.shared.getGifts(for: userId)
            self.shelfGifts = Array(owned.prefix(8))
        } else {
            self.shelfGifts = pinned
        }
        
        countBadge.text = " \(shelfGifts.count) "
        emptyLabel.isHidden = !shelfGifts.isEmpty
        collectionView.reloadData()
    }
    
    // MARK: - Actions
    
    @objc private func seeAllTapped() {
        if let topVC = findViewController() {
            let allGiftsVC = GiftShelfAllViewController(userId: userId, isCurrentAccount: isCurrentAccount)
            topVC.navigationController?.pushViewController(allGiftsVC, animated: true)
        }
    }
    
    // MARK: - CollectionView DataSource & Delegate
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return shelfGifts.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: GiftShelfCollectionViewCell.identifier,
            for: indexPath
        ) as! GiftShelfCollectionViewCell
        
        let gift = shelfGifts[indexPath.item]
        cell.configure(with: gift)
        return cell
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let gift = shelfGifts[indexPath.item]
        onGiftSelected?(gift)
        
        if let parentVC = findViewController() {
            let detailSheet = GiftDetailSheetController(gift: gift, currentUserId: userId, isCurrentAccount: isCurrentAccount)
            detailSheet.modalPresentationStyle = .pageSheet
            if #available(iOS 15.0, *) {
                if let sheet = detailSheet.sheetPresentationController {
                    sheet.detents = [.medium(), .large()]
                    sheet.prefersGrabberVisible = true
                }
            }
            parentVC.present(detailSheet, animated: true)
        }
    }
    
    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while responder != nil {
            if let vc = responder as? UIViewController {
                return vc
            }
            responder = responder?.next
        }
        return nil
    }
}

// MARK: - Gift Detail Sheet Controller

public final class GiftDetailSheetController: UIViewController {
    
    public var gift: WhiteGramGift
    public var currentUserId: Int64
    public var isCurrentAccount: Bool
    
    private let iconLabel = UILabel()
    private let titleLabel = UILabel()
    private let rarityBadge = UILabel()
    private let descriptionLabel = UILabel()
    private let nftDetailsCard = UIView()
    private let nftInfoLabel = UILabel()
    private let transferButton = UIButton(type: .system)
    private let pinShelfButton = UIButton(type: .system)
    
    public init(gift: WhiteGramGift, currentUserId: Int64, isCurrentAccount: Bool) {
        self.gift = gift
        self.currentUserId = currentUserId
        self.isCurrentAccount = isCurrentAccount
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.font = .systemFont(ofSize: 72)
        iconLabel.text = gift.iconEmoji
        iconLabel.textAlignment = .center
        view.addSubview(iconLabel)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.text = gift.title
        titleLabel.textAlignment = .center
        view.addSubview(titleLabel)
        
        rarityBadge.translatesAutoresizingMaskIntoConstraints = false
        rarityBadge.font = .systemFont(ofSize: 13, weight: .heavy)
        rarityBadge.textColor = UIColor(shelfHex: gift.rarity.hexColor)
        rarityBadge.text = "\(gift.rarity.badgeEmoji) \(gift.rarity.title.uppercased())"
        rarityBadge.textAlignment = .center
        view.addSubview(rarityBadge)
        
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.font = .systemFont(ofSize: 14)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.text = gift.descriptionText
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
        view.addSubview(descriptionLabel)
        
        // NFT Card
        nftDetailsCard.translatesAutoresizingMaskIntoConstraints = false
        nftDetailsCard.backgroundColor = .secondarySystemBackground
        nftDetailsCard.layer.cornerRadius = 14
        nftDetailsCard.layer.borderWidth = 1
        nftDetailsCard.layer.borderColor = UIColor(shelfHex: gift.rarity.hexColor).withAlphaComponent(0.4).cgColor
        view.addSubview(nftDetailsCard)
        
        nftInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        nftInfoLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        nftInfoLabel.textColor = .label
        nftInfoLabel.numberOfLines = 0
        nftDetailsCard.addSubview(nftInfoLabel)
        
        if gift.isUniqueNFT, let nft = gift.nftAttributes {
            nftInfoLabel.text = """
            💎 Blockchain: \(nft.blockchain)
            🏷 Edition: \(nft.formattedEdition)
            🔑 Token: \(nft.tokenId)
            🛡 Rarity Score: \(nft.rarityScore)%
            """
        } else {
            nftInfoLabel.text = """
            ✨ Tier: \(gift.rarity.tier) of 5
            ⭐ Stars Price: \(gift.starsPrice) Stars
            ⚡ Craft Value: \(gift.effectiveValue) PTS
            """
        }
        
        // Action Buttons
        transferButton.translatesAutoresizingMaskIntoConstraints = false
        transferButton.setTitle("Transfer Gift to User 🎁", for: .normal)
        transferButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        transferButton.backgroundColor = UIColor(shelfHex: gift.rarity.hexColor)
        transferButton.setTitleColor(.white, for: .normal)
        transferButton.layer.cornerRadius = 14
        transferButton.addTarget(self, action: #selector(transferTapped), for: .touchUpInside)
        view.addSubview(transferButton)
        
        pinShelfButton.translatesAutoresizingMaskIntoConstraints = false
        let pinTitle = gift.isPinnedToShelf ? "Unpin from Profile Shelf" : "Pin to Profile Shelf 📌"
        pinShelfButton.setTitle(pinTitle, for: .normal)
        pinShelfButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        pinShelfButton.setTitleColor(.secondaryLabel, for: .normal)
        pinShelfButton.addTarget(self, action: #selector(pinTapped), for: .touchUpInside)
        view.addSubview(pinShelfButton)
        
        NSLayoutConstraint.activate([
            iconLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            iconLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: iconLabel.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            rarityBadge.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            rarityBadge.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            descriptionLabel.topAnchor.constraint(equalTo: rarityBadge.bottomAnchor, constant: 10),
            descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            nftDetailsCard.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 16),
            nftDetailsCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            nftDetailsCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            nftInfoLabel.topAnchor.constraint(equalTo: nftDetailsCard.topAnchor, constant: 12),
            nftInfoLabel.leadingAnchor.constraint(equalTo: nftDetailsCard.leadingAnchor, constant: 14),
            nftInfoLabel.trailingAnchor.constraint(equalTo: nftDetailsCard.trailingAnchor, constant: -14),
            nftInfoLabel.bottomAnchor.constraint(equalTo: nftDetailsCard.bottomAnchor, constant: -12),
            
            transferButton.topAnchor.constraint(equalTo: nftDetailsCard.bottomAnchor, constant: 20),
            transferButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            transferButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            transferButton.heightAnchor.constraint(equalToConstant: 50),
            
            pinShelfButton.topAnchor.constraint(equalTo: transferButton.bottomAnchor, constant: 8),
            pinShelfButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pinShelfButton.heightAnchor.constraint(equalToConstant: 38)
        ])
    }
    
    @objc private func transferTapped() {
        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            if let presenter = UIApplication.shared.windows.first?.rootViewController {
                let transferVC = GiftTransferController(gift: self.gift, currentUserId: self.currentUserId)
                let nav = UINavigationController(rootViewController: transferVC)
                presenter.present(nav, animated: true)
            }
        }
    }
    
    @objc private func pinTapped() {
        let isPinned = GiftStorage.shared.togglePinToShelf(giftId: gift.id, ownerId: currentUserId)
        gift.isPinnedToShelf = isPinned
        let newTitle = isPinned ? "Unpin from Profile Shelf" : "Pin to Profile Shelf 📌"
        pinShelfButton.setTitle(newTitle, for: .normal)
        
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()
    }
}

// MARK: - All Gifts Grid View Controller

public final class GiftShelfAllViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    private let userId: Int64
    private let isCurrentAccount: Bool
    private var allGifts: [WhiteGramGift] = []
    private var collectionView: UICollectionView!
    
    public init(userId: Int64, isCurrentAccount: Bool) {
        self.userId = userId
        self.isCurrentAccount = isCurrentAccount
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "Gifts & NFT Collection"
        view.backgroundColor = .systemBackground
        
        let layout = UICollectionViewFlowLayout()
        let width = (view.bounds.width - 48) / 3
        layout.itemSize = CGSize(width: width, height: width * 1.25)
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 20, right: 16)
        
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(GiftShelfCollectionViewCell.self, forCellWithReuseIdentifier: GiftShelfCollectionViewCell.identifier)
        view.addSubview(collectionView)
        
        loadGifts()
    }
    
    private func loadGifts() {
        GiftStorage.shared.seedInitialDataIfNeeded(for: userId)
        self.allGifts = GiftStorage.shared.getGifts(for: userId)
        if self.allGifts.isEmpty {
            self.allGifts = WhiteGramGift.mockUserCollection(userId: userId)
        }
        collectionView.reloadData()
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return allGifts.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: GiftShelfCollectionViewCell.identifier, for: indexPath) as! GiftShelfCollectionViewCell
        cell.configure(with: allGifts[indexPath.item])
        return cell
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let gift = allGifts[indexPath.item]
        let detailSheet = GiftDetailSheetController(gift: gift, currentUserId: userId, isCurrentAccount: isCurrentAccount)
        present(detailSheet, animated: true)
    }
}

// MARK: - Internal Hex Extension

fileprivate extension UIColor {
    convenience init(shelfHex hex: String) {
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
