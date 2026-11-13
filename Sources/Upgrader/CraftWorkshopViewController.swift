import Foundation
#if canImport(UIKit)
import UIKit
import CoreGraphics
import QuartzCore
#endif
import WhiteGramCore
import Gifts

#if canImport(UIKit)
// MARK: - Internal Hex Color Helper

extension UIColor {
    fileprivate convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexSanitized.hasPrefix("#") {
            hexSanitized.remove(at: hexSanitized.startIndex)
        }
        guard hexSanitized.count == 6 || hexSanitized.count == 8 else { return nil }
        
        var rgbValue: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgbValue)
        
        if hexSanitized.count == 6 {
            self.init(
                red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
                green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
                blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
                alpha: 1.0
            )
        } else {
            self.init(
                red: CGFloat((rgbValue & 0xFF000000) >> 24) / 255.0,
                green: CGFloat((rgbValue & 0x00FF0000) >> 16) / 255.0,
                blue: CGFloat((rgbValue & 0x0000FF00) >> 8) / 255.0,
                alpha: CGFloat(rgbValue & 0x000000FF) / 255.0
            )
        }
    }
}

/// CraftWorkshopViewController implements the WhiteGram Craft Workshop ("Мастерская Крафта").
/// Features:
/// - 4 ingredient slots (2x2 grid) with dashed borders for empty slots and item previews for filled ones.
/// - Dynamic real chance calculation: exactly 25% per slotted gift (up to 100% with 4 gifts).
/// - Dynamic outcome prediction based on ingredient rarities.
/// - Rich CoreAnimation crafting sequence with slot pulsation and converging particle beams.
/// - High-fidelity Success (golden blast + gift reveal) and Failure (smoke burst + slot shake) animations.
public final class CraftWorkshopViewController: UIViewController {
    
    // MARK: - Types
    
    private final class IngredientSlotView: UIView {
        let index: Int
        var gift: WhiteGramGift?
        var onSlotTapped: ((Int) -> Void)?
        
        private let borderShape = CAShapeLayer()
        private let iconLabel = UILabel()
        private let titleLabel = UILabel()
        private let rarityBadge = UILabel()
        private let plusIconLabel = UILabel()
        private let removeButton = UIButton(type: .system)
        
        init(index: Int) {
            self.index = index
            super.init(frame: .zero)
            setupView()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func setupView() {
            translatesAutoresizingMaskIntoConstraints = false
            layer.cornerRadius = 16
            backgroundColor = UIColor(white: 0.12, alpha: 0.8)
            isUserInteractionEnabled = true
            
            borderShape.fillColor = UIColor.clear.cgColor
            borderShape.strokeColor = UIColor(white: 0.35, alpha: 0.6).cgColor
            borderShape.lineWidth = 1.5
            borderShape.lineDashPattern = [6, 4]
            layer.addSublayer(borderShape)
            
            plusIconLabel.translatesAutoresizingMaskIntoConstraints = false
            plusIconLabel.text = "+"
            plusIconLabel.textColor = UIColor(white: 0.5, alpha: 0.8)
            plusIconLabel.font = UIFont.systemFont(ofSize: 28, weight: .light)
            plusIconLabel.textAlignment = .center
            addSubview(plusIconLabel)
            
            iconLabel.translatesAutoresizingMaskIntoConstraints = false
            iconLabel.font = UIFont.systemFont(ofSize: 32)
            iconLabel.textAlignment = .center
            iconLabel.isHidden = true
            addSubview(iconLabel)
            
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            titleLabel.font = UIFont.systemFont(ofSize: 11, weight: .bold)
            titleLabel.textColor = .label
            titleLabel.textAlignment = .center
            titleLabel.numberOfLines = 1
            titleLabel.isHidden = true
            addSubview(titleLabel)
            
            rarityBadge.translatesAutoresizingMaskIntoConstraints = false
            rarityBadge.font = UIFont.systemFont(ofSize: 9, weight: .heavy)
            rarityBadge.textColor = .white
            rarityBadge.textAlignment = .center
            rarityBadge.layer.cornerRadius = 5
            rarityBadge.layer.masksToBounds = true
            rarityBadge.isHidden = true
            addSubview(rarityBadge)
            
            removeButton.translatesAutoresizingMaskIntoConstraints = false
            removeButton.setTitle("✕", for: .normal)
            removeButton.setTitleColor(UIColor(white: 0.7, alpha: 1.0), for: .normal)
            removeButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
            removeButton.backgroundColor = UIColor(white: 0.2, alpha: 0.8)
            removeButton.layer.cornerRadius = 10
            removeButton.isHidden = true
            removeButton.addTarget(self, action: #selector(handleRemoveTapped), for: .touchUpInside)
            addSubview(removeButton)
            
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            addGestureRecognizer(tap)
            
            NSLayoutConstraint.activate([
                plusIconLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
                plusIconLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
                
                iconLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
                iconLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
                
                titleLabel.topAnchor.constraint(equalTo: iconLabel.bottomAnchor, constant: 4),
                titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
                titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
                
                rarityBadge.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
                rarityBadge.centerXAnchor.constraint(equalTo: centerXAnchor),
                rarityBadge.heightAnchor.constraint(equalToConstant: 14),
                rarityBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
                
                removeButton.topAnchor.constraint(equalTo: topAnchor, constant: 6),
                removeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
                removeButton.widthAnchor.constraint(equalToConstant: 20),
                removeButton.heightAnchor.constraint(equalToConstant: 20)
            ])
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            borderShape.path = UIBezierPath(roundedRect: bounds, cornerRadius: 16).cgPath
            borderShape.frame = bounds
        }
        
        func configure(with gift: WhiteGramGift?) {
            self.gift = gift
            if let gift = gift {
                plusIconLabel.isHidden = true
                iconLabel.isHidden = false
                titleLabel.isHidden = false
                rarityBadge.isHidden = false
                removeButton.isHidden = false
                
                iconLabel.text = gift.iconEmoji
                titleLabel.text = gift.title
                rarityBadge.text = gift.rarity.title.uppercased()
                rarityBadge.backgroundColor = UIColor(hex: gift.rarity.hexColor) ?? .systemBlue
                
                borderShape.lineDashPattern = nil
                borderShape.strokeColor = (UIColor(hex: gift.rarity.hexColor) ?? .systemBlue).withAlphaComponent(0.8).cgColor
                borderShape.lineWidth = 2.0
            } else {
                plusIconLabel.isHidden = false
                iconLabel.isHidden = true
                titleLabel.isHidden = true
                rarityBadge.isHidden = true
                removeButton.isHidden = true
                
                borderShape.lineDashPattern = [6, 4]
                borderShape.strokeColor = UIColor(white: 0.35, alpha: 0.6).cgColor
                borderShape.lineWidth = 1.5
            }
        }
        
        @objc private func handleTap() {
            onSlotTapped?(index)
        }
        
        @objc private func handleRemoveTapped() {
            configure(with: nil)
            onSlotTapped?(index)
        }
    }
    
    // MARK: - Properties
    
    public var currentUserId: Int64 = 777000
    private var slottedGifts: [WhiteGramGift?] = [nil, nil, nil, nil]
    private var ownedGifts: [WhiteGramGift] = []
    private var isCrafting: Bool = false
    
    // MARK: - UI Elements
    
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.showsVerticalScrollIndicator = false
        sv.alwaysBounceVertical = true
        return sv
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Anvil / Forge Header
    private let anvilIconLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "⚒️"
        label.font = UIFont.systemFont(ofSize: 52)
        label.textAlignment = .center
        return label
    }()
    
    private let titleHeaderLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Мастерская Крафта"
        label.font = UIFont.systemFont(ofSize: 24, weight: .heavy)
        label.textColor = .label
        label.textAlignment = .center
        return label
    }()
    
    private let subtitleHeaderLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Объединяйте подарки для создания редких NFT"
        label.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()
    
    // Dynamic Chance Meter Card
    private let chanceCardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(white: 0.12, alpha: 0.9)
        view.layer.cornerRadius = 18
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor(white: 0.25, alpha: 0.6).cgColor
        return view
    }()
    
    private let chanceTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "ШАНС УСПЕХА КРАФТА"
        label.font = UIFont.systemFont(ofSize: 11, weight: .heavy)
        label.textColor = .secondaryLabel
        return label
    }()
    
    private let chancePercentageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "0%"
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 32, weight: .black)
        label.textColor = UIColor(red: 0.18, green: 0.58, blue: 0.94, alpha: 1.0)
        return label
    }()
    
    private let chanceProgressBar: UIProgressView = {
        let bar = UIProgressView(progressViewStyle: .default)
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.progressTintColor = UIColor(red: 0.12, green: 0.74, blue: 0.98, alpha: 1.0)
        bar.trackTintColor = UIColor(white: 0.2, alpha: 1.0)
        bar.layer.cornerRadius = 4
        bar.layer.masksToBounds = true
        bar.progress = 0.0
        return bar
    }()
    
    private let targetPreviewLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Ожидаемый результат: Добавьте ингредиенты"
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = UIColor(white: 0.8, alpha: 1.0)
        label.textAlignment = .center
        return label
    }()
    
    // 4 Slots Grid
    private var slotViews: [IngredientSlotView] = []
    private let slotsContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Craft Button
    private let craftButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.cornerRadius = 16
        button.layer.masksToBounds = true
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .heavy)
        button.setTitle("СКРАФТИТЬ (0%)", for: .normal)
        button.setTitleColor(.white, for: .normal)
        
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor(red: 0.12, green: 0.74, blue: 0.98, alpha: 1.0).cgColor,
            UIColor(red: 0.48, green: 0.25, blue: 0.98, alpha: 1.0).cgColor
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        gradient.name = "gradientBackground"
        button.layer.insertSublayer(gradient, at: 0)
        return button
    }()
    
    // Success Celebration Modal
    private let modalBackdropView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        view.alpha = 0
        return view
    }()
    
    private let modalCardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(white: 0.12, alpha: 0.95)
        view.layer.cornerRadius = 22
        view.layer.borderWidth = 1.5
        view.layer.borderColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 0.8).cgColor
        view.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        view.alpha = 0
        return view
    }()
    
    private let modalIconLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 64)
        label.textAlignment = .center
        return label
    }()
    
    private let modalTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 20, weight: .heavy)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    private let modalSubtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)
        label.textAlignment = .center
        return label
    }()
    
    private let modalCloseButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Забрать предмет", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        button.backgroundColor = UIColor(red: 0.18, green: 0.58, blue: 0.94, alpha: 1.0)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 14
        return button
    }()
    
    // MARK: - Lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "Мастерская"
        view.backgroundColor = UIColor(white: 0.07, alpha: 1.0)
        
        setupLayout()
        setupSlots()
        setupActions()
        loadInventory()
        refreshChanceDisplay(animated: false)
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let grad = craftButton.layer.sublayers?.first(where: { $0.name == "gradientBackground" }) {
            grad.frame = craftButton.bounds
        }
    }
    
    // MARK: - Layout Setup
    
    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(anvilIconLabel)
        contentView.addSubview(titleHeaderLabel)
        contentView.addSubview(subtitleHeaderLabel)
        
        contentView.addSubview(chanceCardView)
        chanceCardView.addSubview(chanceTitleLabel)
        chanceCardView.addSubview(chancePercentageLabel)
        chanceCardView.addSubview(chanceProgressBar)
        chanceCardView.addSubview(targetPreviewLabel)
        
        contentView.addSubview(slotsContainerView)
        contentView.addSubview(craftButton)
        
        // Modal
        view.addSubview(modalBackdropView)
        view.addSubview(modalCardView)
        modalCardView.addSubview(modalIconLabel)
        modalCardView.addSubview(modalTitleLabel)
        modalCardView.addSubview(modalSubtitleLabel)
        modalCardView.addSubview(modalCloseButton)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Header
            anvilIconLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            anvilIconLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            titleHeaderLabel.topAnchor.constraint(equalTo: anvilIconLabel.bottomAnchor, constant: 8),
            titleHeaderLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            subtitleHeaderLabel.topAnchor.constraint(equalTo: titleHeaderLabel.bottomAnchor, constant: 4),
            subtitleHeaderLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            // Chance Card
            chanceCardView.topAnchor.constraint(equalTo: subtitleHeaderLabel.bottomAnchor, constant: 18),
            chanceCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            chanceCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            chanceTitleLabel.topAnchor.constraint(equalTo: chanceCardView.topAnchor, constant: 14),
            chanceTitleLabel.leadingAnchor.constraint(equalTo: chanceCardView.leadingAnchor, constant: 16),
            
            chancePercentageLabel.topAnchor.constraint(equalTo: chanceTitleLabel.bottomAnchor, constant: 4),
            chancePercentageLabel.leadingAnchor.constraint(equalTo: chanceTitleLabel.leadingAnchor),
            
            chanceProgressBar.topAnchor.constraint(equalTo: chancePercentageLabel.bottomAnchor, constant: 10),
            chanceProgressBar.leadingAnchor.constraint(equalTo: chanceCardView.leadingAnchor, constant: 16),
            chanceProgressBar.trailingAnchor.constraint(equalTo: chanceCardView.trailingAnchor, constant: -16),
            chanceProgressBar.heightAnchor.constraint(equalToConstant: 8),
            
            targetPreviewLabel.topAnchor.constraint(equalTo: chanceProgressBar.bottomAnchor, constant: 12),
            targetPreviewLabel.leadingAnchor.constraint(equalTo: chanceCardView.leadingAnchor, constant: 16),
            targetPreviewLabel.trailingAnchor.constraint(equalTo: chanceCardView.trailingAnchor, constant: -16),
            targetPreviewLabel.bottomAnchor.constraint(equalTo: chanceCardView.bottomAnchor, constant: -14),
            
            // Slots Container
            slotsContainerView.topAnchor.constraint(equalTo: chanceCardView.bottomAnchor, constant: 20),
            slotsContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            slotsContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            slotsContainerView.heightAnchor.constraint(equalToConstant: 220),
            
            // Craft Button
            craftButton.topAnchor.constraint(equalTo: slotsContainerView.bottomAnchor, constant: 24),
            craftButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            craftButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            craftButton.heightAnchor.constraint(equalToConstant: 54),
            craftButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30),
            
            // Modal Backdrop & Card
            modalBackdropView.topAnchor.constraint(equalTo: view.topAnchor),
            modalBackdropView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            modalBackdropView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            modalBackdropView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            modalCardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            modalCardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            modalCardView.widthAnchor.constraint(equalToConstant: 300),
            
            modalIconLabel.topAnchor.constraint(equalTo: modalCardView.topAnchor, constant: 24),
            modalIconLabel.centerXAnchor.constraint(equalTo: modalCardView.centerXAnchor),
            
            modalTitleLabel.topAnchor.constraint(equalTo: modalIconLabel.bottomAnchor, constant: 12),
            modalTitleLabel.leadingAnchor.constraint(equalTo: modalCardView.leadingAnchor, constant: 16),
            modalTitleLabel.trailingAnchor.constraint(equalTo: modalCardView.trailingAnchor, constant: -16),
            
            modalSubtitleLabel.topAnchor.constraint(equalTo: modalTitleLabel.bottomAnchor, constant: 6),
            modalSubtitleLabel.leadingAnchor.constraint(equalTo: modalCardView.leadingAnchor, constant: 16),
            modalSubtitleLabel.trailingAnchor.constraint(equalTo: modalCardView.trailingAnchor, constant: -16),
            
            modalCloseButton.topAnchor.constraint(equalTo: modalSubtitleLabel.bottomAnchor, constant: 20),
            modalCloseButton.leadingAnchor.constraint(equalTo: modalCardView.leadingAnchor, constant: 20),
            modalCloseButton.trailingAnchor.constraint(equalTo: modalCardView.trailingAnchor, constant: -20),
            modalCloseButton.heightAnchor.constraint(equalToConstant: 46),
            modalCloseButton.bottomAnchor.constraint(equalTo: modalCardView.bottomAnchor, constant: -24)
        ])
    }
    
    private func setupSlots() {
        for i in 0..<4 {
            let slot = IngredientSlotView(index: i)
            slot.onSlotTapped = { [weak self] index in
                self?.handleSlotInteraction(index: index)
            }
            slotViews.append(slot)
            slotsContainerView.addSubview(slot)
        }
        
        // 2x2 Grid Layout
        let s0 = slotViews[0], s1 = slotViews[1], s2 = slotViews[2], s3 = slotViews[3]
        let spacing: CGFloat = 12
        
        NSLayoutConstraint.activate([
            s0.topAnchor.constraint(equalTo: slotsContainerView.topAnchor),
            s0.leadingAnchor.constraint(equalTo: slotsContainerView.leadingAnchor),
            s0.trailingAnchor.constraint(equalTo: slotsContainerView.centerXAnchor, constant: -spacing / 2),
            s0.bottomAnchor.constraint(equalTo: slotsContainerView.centerYAnchor, constant: -spacing / 2),
            
            s1.topAnchor.constraint(equalTo: slotsContainerView.topAnchor),
            s1.leadingAnchor.constraint(equalTo: slotsContainerView.centerXAnchor, constant: spacing / 2),
            s1.trailingAnchor.constraint(equalTo: slotsContainerView.trailingAnchor),
            s1.bottomAnchor.constraint(equalTo: slotsContainerView.centerYAnchor, constant: -spacing / 2),
            
            s2.topAnchor.constraint(equalTo: slotsContainerView.centerYAnchor, constant: spacing / 2),
            s2.leadingAnchor.constraint(equalTo: slotsContainerView.leadingAnchor),
            s2.trailingAnchor.constraint(equalTo: slotsContainerView.centerXAnchor, constant: -spacing / 2),
            s2.bottomAnchor.constraint(equalTo: slotsContainerView.bottomAnchor),
            
            s3.topAnchor.constraint(equalTo: slotsContainerView.centerYAnchor, constant: spacing / 2),
            s3.leadingAnchor.constraint(equalTo: slotsContainerView.centerXAnchor, constant: spacing / 2),
            s3.trailingAnchor.constraint(equalTo: slotsContainerView.trailingAnchor),
            s3.bottomAnchor.constraint(equalTo: slotsContainerView.bottomAnchor)
        ])
    }
    
    private func setupActions() {
        craftButton.addTarget(self, action: #selector(handleCraftTapped), for: .touchUpInside)
        modalCloseButton.addTarget(self, action: #selector(dismissSuccessModal), for: .touchUpInside)
    }
    
    // MARK: - Data & Chance Calculation
    
    private func loadInventory() {
        GiftStorage.shared.seedInitialDataIfNeeded(for: currentUserId)
        ownedGifts = GiftStorage.shared.getGifts(for: currentUserId)
    }
    
    /// Dynamic real chance calculation: exactly 25% per slotted gift ingredient.
    public func computeCraftSuccessChance() -> Double {
        let activeCount = slottedGifts.compactMap { $0 }.count
        return WhiteGramGift.craftSuccessChance(ingredientCount: activeCount)
    }
    
    private func refreshChanceDisplay(animated: Bool = true) {
        let activeGifts = slottedGifts.compactMap { $0 }
        let chance = computeCraftSuccessChance()
        
        let progress = Float(chance / 100.0)
        chanceProgressBar.setProgress(progress, animated: animated)
        chancePercentageLabel.text = "\(Int(chance))%"
        
        if activeGifts.isEmpty {
            targetPreviewLabel.text = "Ожидаемый результат: Добавьте ингредиенты"
            craftButton.setTitle("СКРАФТИТЬ (0%)", for: .normal)
            craftButton.isEnabled = false
            craftButton.alpha = 0.5
        } else {
            let predictedRarity = WhiteGramGift.determineCraftOutcomeRarity(ingredients: activeGifts)
            targetPreviewLabel.text = "Ожидаемый результат: \(predictedRarity.title) предмет"
            craftButton.setTitle("СКРАФТИТЬ (\(Int(chance))%)", for: .normal)
            craftButton.isEnabled = true
            craftButton.alpha = 1.0
        }
    }
    
    // MARK: - Slot Interaction
    
    private func handleSlotInteraction(index: Int) {
        guard !isCrafting else { return }
        
        if slottedGifts[index] != nil {
            // Unslot
            slottedGifts[index] = nil
            slotViews[index].configure(with: nil)
            UISelectionFeedbackGenerator().selectionChanged()
            refreshChanceDisplay()
            return
        }
        
        // Present picker with owned gifts not yet in other slots
        let slottedIds = Set(slottedGifts.compactMap { $0?.id })
        let available = ownedGifts.filter { !slottedIds.contains($0.id) }
        
        guard !available.isEmpty else {
            let alert = UIAlertController(title: "Нет доступных подарков", message: "У вас нет свободных подарков для слота крафта.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        let sheet = UIAlertController(title: "Выберите ингредиент", message: "Каждый ингредиент дает +25% к шансу успеха", preferredStyle: .actionSheet)
        for gift in available {
            let title = "\(gift.iconEmoji) \(gift.title) (\(gift.rarity.title))"
            sheet.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                guard let self = self else { return }
                self.slottedGifts[index] = gift
                self.slotViews[index].configure(with: gift)
                UISelectionFeedbackGenerator().selectionChanged()
                self.refreshChanceDisplay()
            })
        }
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(sheet, animated: true)
    }
    
    // MARK: - Crafting Action & Animations
    
    @objc private func handleCraftTapped() {
        guard !isCrafting else { return }
        let activeGifts = slottedGifts.compactMap { $0 }
        guard !activeGifts.isEmpty else { return }
        
        isCrafting = true
        craftButton.isEnabled = false
        craftButton.setTitle("Ковка артефакта...", for: .normal)
        
        // Anvil vibration & slot pulse animation
        startCraftingSequenceAnimations()
        
        let successChance = computeCraftSuccessChance()
        let roll = Double.random(in: 0.01...100.0)
        let isSuccess = roll <= successChance
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            self.isCrafting = false
            self.stopCraftingSequenceAnimations()
            
            if isSuccess {
                self.handleCraftSuccess(ingredients: activeGifts)
            } else {
                self.handleCraftFailure()
            }
        }
    }
    
    private func startCraftingSequenceAnimations() {
        // Anvil rotation wobble
        let wobble = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        wobble.values = [-0.15, 0.15, -0.1, 0.1, 0]
        wobble.duration = 0.35
        wobble.repeatCount = 5
        anvilIconLabel.layer.add(wobble, forKey: "anvilWobble")
        
        // Slot pulsing
        for slot in slotViews {
            let pulse = CABasicAnimation(keyPath: "transform.scale")
            pulse.fromValue = 1.0
            pulse.toValue = 1.05
            pulse.duration = 0.25
            pulse.autoreverses = true
            pulse.repeatCount = 4
            slot.layer.add(pulse, forKey: "slotPulse")
        }
    }
    
    private func stopCraftingSequenceAnimations() {
        anvilIconLabel.layer.removeAllAnimations()
        slotViews.forEach { $0.layer.removeAllAnimations() }
    }
    
    private func handleCraftSuccess(ingredients: [WhiteGramGift]) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
        // Consume ingredients from storage
        for gift in ingredients {
            GiftStorage.shared.removeGift(id: gift.id)
        }
        
        // Determine outcome rarity and produce new gift
        let outcomeRarity = WhiteGramGift.determineCraftOutcomeRarity(ingredients: ingredients)
        let isNFT = outcomeRarity == .unique
        
        let craftedGift = WhiteGramGift(
            slug: "crafted_\(UUID().uuidString.prefix(6))",
            title: isNFT ? "Masterwork NFT" : "Forged \(outcomeRarity.title)",
            descriptionText: "Эксклюзивный предмет, выкованный в Мастерской Крафта.",
            iconEmoji: isNFT ? "💎" : (outcomeRarity >= .legendary ? "👑" : "🔮"),
            rarity: outcomeRarity,
            isUniqueNFT: isNFT,
            nftAttributes: isNFT ? NFTAttributes(tokenId: "CRAFT-\(Int.random(in: 1000...9999))", serialNumber: 1, totalEditions: 100, modelName: "Anvil Masterwork") : nil,
            currentOwnerId: currentUserId,
            starsPrice: outcomeRarity.starsPriceEquivalent
        )
        
        GiftStorage.shared.saveGift(craftedGift)
        loadInventory()
        
        // Reset slots
        clearAllSlots()
        refreshChanceDisplay()
        
        // Show celebration
        showGoldenExplosion()
        showSuccessModal(for: craftedGift)
    }
    
    private func handleCraftFailure() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        
        // Ingredients lost
        let activeGifts = slottedGifts.compactMap { $0 }
        for gift in activeGifts {
            GiftStorage.shared.removeGift(id: gift.id)
        }
        loadInventory()
        
        // Slot shake
        for slot in slotViews {
            let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
            shake.duration = 0.4
            shake.values = [-10, 10, -8, 8, -4, 4, 0]
            slot.layer.add(shake, forKey: "shakeFailure")
        }
        
        showSmokeBurst()
        clearAllSlots()
        refreshChanceDisplay()
        
        let alert = UIAlertController(title: "Крафт провалился", message: "Ингредиенты расплавились и были утеряны в пламени горна.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Понятно", style: .default))
        present(alert, animated: true)
    }
    
    private func clearAllSlots() {
        slottedGifts = [nil, nil, nil, nil]
        slotViews.forEach { $0.configure(with: nil) }
    }
    
    // MARK: - Particles & Modal
    
    private func showGoldenExplosion() {
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        emitter.emitterShape = .point
        emitter.emitterSize = CGSize(width: 20, height: 20)
        
        let cell = CAEmitterCell()
        cell.birthRate = 60
        cell.lifetime = 1.8
        cell.velocity = 260
        cell.velocityRange = 100
        cell.emissionRange = 2.0 * .pi
        cell.spin = 4.0
        cell.scale = 0.2
        cell.scaleSpeed = -0.05
        cell.color = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0).cgColor
        cell.contents = createSparkParticle()?.cgImage
        
        emitter.emitterCells = [cell]
        view.layer.addSublayer(emitter)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            emitter.birthRate = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            emitter.removeFromSuperlayer()
        }
    }
    
    private func showSmokeBurst() {
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: view.bounds.midX, y: slotsContainerView.frame.midY)
        emitter.emitterShape = .circle
        emitter.emitterSize = CGSize(width: 80, height: 80)
        
        let cell = CAEmitterCell()
        cell.birthRate = 30
        cell.lifetime = 1.2
        cell.velocity = 40
        cell.emissionRange = 2.0 * .pi
        cell.scale = 0.35
        cell.scaleSpeed = 0.2
        cell.alphaSpeed = -0.7
        cell.color = UIColor(white: 0.4, alpha: 0.7).cgColor
        cell.contents = createSparkParticle()?.cgImage
        
        emitter.emitterCells = [cell]
        view.layer.addSublayer(emitter)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            emitter.birthRate = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            emitter.removeFromSuperlayer()
        }
    }
    
    private func createSparkParticle() -> UIImage? {
        let rect = CGRect(x: 0, y: 0, width: 16, height: 16)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        ctx.setFillColor(UIColor.white.cgColor)
        ctx.fillEllipse(in: rect)
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img
    }
    
    private func showSuccessModal(for gift: WhiteGramGift) {
        modalIconLabel.text = gift.iconEmoji
        modalTitleLabel.text = gift.title
        modalSubtitleLabel.text = "\(gift.rarity.title) • ⭐️ \(gift.starsPrice)"
        
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.4, options: .curveEaseOut) {
            self.modalBackdropView.alpha = 1.0
            self.modalCardView.alpha = 1.0
            self.modalCardView.transform = .identity
        }
    }
    
    @objc private func dismissSuccessModal() {
        UIView.animate(withDuration: 0.25) {
            self.modalBackdropView.alpha = 0
            self.modalCardView.alpha = 0
            self.modalCardView.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        }
    }
}
#endif
