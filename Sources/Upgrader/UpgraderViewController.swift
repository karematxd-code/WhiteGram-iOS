import Foundation
#if canImport(UIKit)
import UIKit
import CoreGraphics
import QuartzCore
#endif
import WhiteGramCore
import Gifts

#if canImport(UIKit)
/// UpgraderViewController provides the Upgrader interface for WhiteGram-iOS.
/// Features:
/// - Radial gauge with live percentage counter and animated needle.
/// - Stake selector ("ВАША СТАВКА") supporting gifts and currency.
/// - Target selector ("ЦЕЛЬ") with target preview and multiplier calculation.
/// - Live probability formula: `chance = min(95.0, max(1.0, (stake / target) * 90.0))`.
/// - 2.4-second spin animation with cubic easing.
/// - Win / Loss rolls with celebration fireworks (CAEmitterLayer) and toast alerts.
public final class UpgraderViewController: UIViewController {
    
    // MARK: - Properties
    
    public var currentUserId: Int64 = 777000
    
    private var availableInventoryGifts: [WhiteGramGift] = []
    private var availableTargetGifts: [WhiteGramGift] = []
    
    private var selectedStakeGift: WhiteGramGift?
    private var selectedTargetGift: WhiteGramGift?
    
    private var currentStakeStars: Int = 100
    private var isSpinning: Bool = false
    
    // MARK: - UI Elements
    
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.alwaysBounceVertical = true
        sv.showsVerticalScrollIndicator = false
        return sv
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Balance Header
    private let balancePillView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(white: 0.15, alpha: 0.8)
        view.layer.cornerRadius = 18
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor(white: 0.3, alpha: 0.6).cgColor
        return view
    }()
    
    private let balanceLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 15, weight: .bold)
        label.textColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)
        label.text = "⭐️ 5,000"
        return label
    }()
    
    // Radial Gauge
    private let gaugeView: UpgraderRadialGaugeView = {
        let gauge = UpgraderRadialGaugeView()
        gauge.translatesAutoresizingMaskIntoConstraints = false
        return gauge
    }()
    
    // Stake Section ("ВАША СТАВКА")
    private let stakeHeaderLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 13, weight: .heavy)
        label.textColor = .secondaryLabel
        label.text = "ВАША СТАВКА"
        return label
    }()
    
    private let stakeCardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(white: 0.12, alpha: 0.9)
        view.layer.cornerRadius = 16
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor(white: 0.25, alpha: 0.6).cgColor
        return view
    }()
    
    private let stakeItemIconLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 32)
        label.text = "⭐️"
        label.textAlignment = .center
        return label
    }()
    
    private let stakeItemTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.textColor = .label
        label.text = "100 Stars"
        return label
    }()
    
    private let stakeItemSubtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabel
        label.text = "Ценность: 100 ⭐️"
        return label
    }()
    
    private let changeStakeButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Выбрать предмет", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        button.tintColor = UIColor(red: 0.18, green: 0.58, blue: 0.94, alpha: 1.0)
        return button
    }()
    
    // Quick Stake Presets
    private let presetStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 8
        return stack
    }()
    
    // Target Section ("ЦЕЛЬ")
    private let targetHeaderLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 13, weight: .heavy)
        label.textColor = .secondaryLabel
        label.text = "ЦЕЛЬ"
        return label
    }()
    
    private let targetCardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(white: 0.12, alpha: 0.9)
        view.layer.cornerRadius = 16
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor(white: 0.25, alpha: 0.6).cgColor
        return view
    }()
    
    private let targetItemIconLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 32)
        label.text = "🚀"
        label.textAlignment = .center
        return label
    }()
    
    private let targetItemTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.textColor = .label
        label.text = "Space Rocket"
        return label
    }()
    
    private let targetItemSubtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = UIColor(red: 0.48, green: 0.25, blue: 0.98, alpha: 1.0)
        label.text = "Epic • ⭐️ 500"
        return label
    }()
    
    private let changeTargetButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Выбрать цель", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        button.tintColor = UIColor(red: 0.18, green: 0.58, blue: 0.94, alpha: 1.0)
        return button
    }()
    
    // Upgrade Action Button
    private let upgradeButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.cornerRadius = 16
        button.layer.masksToBounds = true
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .heavy)
        button.setTitle("УЛУЧШИТЬ", for: .normal)
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
    
    // Confetti / Fireworks Layer
    private var fireworksEmitterLayer: CAEmitterLayer?
    
    // Toast Alert Overlay
    private let toastView: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let view = UIVisualEffectView(effect: blur)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 18
        view.layer.masksToBounds = true
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor(white: 0.3, alpha: 0.5).cgColor
        view.alpha = 0
        view.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        return view
    }()
    
    private let toastIconLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 28)
        return label
    }()
    
    private let toastTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    private let toastMessageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = UIColor(white: 0.85, alpha: 1.0)
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()
    
    // MARK: - Lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "Апгрейдер"
        view.backgroundColor = UIColor(white: 0.07, alpha: 1.0)
        
        setupLayout()
        setupActions()
        loadData()
        recalculateAndRefreshChance(animated: false)
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let grad = upgradeButton.layer.sublayers?.first(where: { $0.name == "gradientBackground" }) {
            grad.frame = upgradeButton.bounds
        }
    }
    
    // MARK: - Layout Setup
    
    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        view.addSubview(toastView)
        
        let toastStack = UIStackView(arrangedSubviews: [toastIconLabel, toastTitleLabel, toastMessageLabel])
        toastStack.translatesAutoresizingMaskIntoConstraints = false
        toastStack.axis = .vertical
        toastStack.alignment = .center
        toastStack.spacing = 4
        toastView.contentView.addSubview(toastStack)
        
        contentView.addSubview(balancePillView)
        balancePillView.addSubview(balanceLabel)
        
        contentView.addSubview(gaugeView)
        
        contentView.addSubview(stakeHeaderLabel)
        contentView.addSubview(stakeCardView)
        stakeCardView.addSubview(stakeItemIconLabel)
        stakeCardView.addSubview(stakeItemTitleLabel)
        stakeCardView.addSubview(stakeItemSubtitleLabel)
        stakeCardView.addSubview(changeStakeButton)
        
        contentView.addSubview(presetStackView)
        setupPresetButtons()
        
        contentView.addSubview(targetHeaderLabel)
        contentView.addSubview(targetCardView)
        targetCardView.addSubview(targetItemIconLabel)
        targetCardView.addSubview(targetItemTitleLabel)
        targetCardView.addSubview(targetItemSubtitleLabel)
        targetCardView.addSubview(changeTargetButton)
        
        contentView.addSubview(upgradeButton)
        
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
            
            // Balance
            balancePillView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            balancePillView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            balancePillView.heightAnchor.constraint(equalToConstant: 36),
            balanceLabel.leadingAnchor.constraint(equalTo: balancePillView.leadingAnchor, constant: 14),
            balanceLabel.trailingAnchor.constraint(equalTo: balancePillView.trailingAnchor, constant: -14),
            balanceLabel.centerYAnchor.constraint(equalTo: balancePillView.centerYAnchor),
            
            // Gauge
            gaugeView.topAnchor.constraint(equalTo: balancePillView.bottomAnchor, constant: 18),
            gaugeView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            gaugeView.widthAnchor.constraint(equalToConstant: 270),
            gaugeView.heightAnchor.constraint(equalToConstant: 270),
            
            // Stake Header & Card
            stakeHeaderLabel.topAnchor.constraint(equalTo: gaugeView.bottomAnchor, constant: 22),
            stakeHeaderLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            
            stakeCardView.topAnchor.constraint(equalTo: stakeHeaderLabel.bottomAnchor, constant: 8),
            stakeCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stakeCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stakeCardView.heightAnchor.constraint(equalToConstant: 72),
            
            stakeItemIconLabel.leadingAnchor.constraint(equalTo: stakeCardView.leadingAnchor, constant: 14),
            stakeItemIconLabel.centerYAnchor.constraint(equalTo: stakeCardView.centerYAnchor),
            stakeItemIconLabel.widthAnchor.constraint(equalToConstant: 44),
            
            stakeItemTitleLabel.topAnchor.constraint(equalTo: stakeCardView.topAnchor, constant: 14),
            stakeItemTitleLabel.leadingAnchor.constraint(equalTo: stakeItemIconLabel.trailingAnchor, constant: 10),
            stakeItemSubtitleLabel.topAnchor.constraint(equalTo: stakeItemTitleLabel.bottomAnchor, constant: 4),
            stakeItemSubtitleLabel.leadingAnchor.constraint(equalTo: stakeItemTitleLabel.leadingAnchor),
            
            changeStakeButton.trailingAnchor.constraint(equalTo: stakeCardView.trailingAnchor, constant: -14),
            changeStakeButton.centerYAnchor.constraint(equalTo: stakeCardView.centerYAnchor),
            
            // Presets
            presetStackView.topAnchor.constraint(equalTo: stakeCardView.bottomAnchor, constant: 10),
            presetStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            presetStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            presetStackView.heightAnchor.constraint(equalToConstant: 34),
            
            // Target Header & Card
            targetHeaderLabel.topAnchor.constraint(equalTo: presetStackView.bottomAnchor, constant: 18),
            targetHeaderLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            
            targetCardView.topAnchor.constraint(equalTo: targetHeaderLabel.bottomAnchor, constant: 8),
            targetCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            targetCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            targetCardView.heightAnchor.constraint(equalToConstant: 72),
            
            targetItemIconLabel.leadingAnchor.constraint(equalTo: targetCardView.leadingAnchor, constant: 14),
            targetItemIconLabel.centerYAnchor.constraint(equalTo: targetCardView.centerYAnchor),
            targetItemIconLabel.widthAnchor.constraint(equalToConstant: 44),
            
            targetItemTitleLabel.topAnchor.constraint(equalTo: targetCardView.topAnchor, constant: 14),
            targetItemTitleLabel.leadingAnchor.constraint(equalTo: targetItemIconLabel.trailingAnchor, constant: 10),
            targetItemSubtitleLabel.topAnchor.constraint(equalTo: targetItemTitleLabel.bottomAnchor, constant: 4),
            targetItemSubtitleLabel.leadingAnchor.constraint(equalTo: targetItemTitleLabel.leadingAnchor),
            
            changeTargetButton.trailingAnchor.constraint(equalTo: targetCardView.trailingAnchor, constant: -14),
            changeTargetButton.centerYAnchor.constraint(equalTo: targetCardView.centerYAnchor),
            
            // Upgrade Button
            upgradeButton.topAnchor.constraint(equalTo: targetCardView.bottomAnchor, constant: 24),
            upgradeButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            upgradeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            upgradeButton.heightAnchor.constraint(equalToConstant: 54),
            upgradeButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30),
            
            // Toast Constraints
            toastView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            toastView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastView.widthAnchor.constraint(equalToConstant: 290),
            toastStack.topAnchor.constraint(equalTo: toastView.contentView.topAnchor, constant: 14),
            toastStack.leadingAnchor.constraint(equalTo: toastView.contentView.leadingAnchor, constant: 16),
            toastStack.trailingAnchor.constraint(equalTo: toastView.contentView.trailingAnchor, constant: -16),
            toastStack.bottomAnchor.constraint(equalTo: toastView.contentView.bottomAnchor, constant: -14)
        ])
    }
    
    private func setupPresetButtons() {
        let presets = ["50", "100", "250", "500", "1000", "2x"]
        for p in presets {
            let btn = UIButton(type: .system)
            btn.setTitle(p, for: .normal)
            btn.titleLabel?.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .bold)
            btn.setTitleColor(UIColor(white: 0.9, alpha: 1.0), for: .normal)
            btn.backgroundColor = UIColor(white: 0.2, alpha: 0.7)
            btn.layer.cornerRadius = 8
            btn.layer.borderWidth = 0.5
            btn.layer.borderColor = UIColor(white: 0.35, alpha: 0.5).cgColor
            btn.addTarget(self, action: #selector(handlePresetTapped(_:)), for: .touchUpInside)
            presetStackView.addArrangedSubview(btn)
        }
    }
    
    private func setupActions() {
        upgradeButton.addTarget(self, action: #selector(handleUpgradeTapped), for: .touchUpInside)
        changeStakeButton.addTarget(self, action: #selector(handleSelectStakeTapped), for: .touchUpInside)
        changeTargetButton.addTarget(self, action: #selector(handleSelectTargetTapped), for: .touchUpInside)
    }
    
    // MARK: - Data Loading
    
    private func loadData() {
        GiftStorage.shared.seedInitialDataIfNeeded(for: currentUserId)
        availableInventoryGifts = GiftStorage.shared.getGifts(for: currentUserId)
        
        // Target catalog from all gifts or mock catalog
        let allCatalog = GiftStorage.shared.allGifts()
        availableTargetGifts = allCatalog.filter { $0.rarity >= .rare }
        
        if availableTargetGifts.isEmpty {
            // Seed sample targets
            availableTargetGifts = [
                WhiteGramGift(slug: "rocket", title: "Space Rocket", descriptionText: "Epic cosmic ride", iconEmoji: "🚀", rarity: .epic, starsPrice: 500),
                WhiteGramGift(slug: "crown", title: "Royal Crown", descriptionText: "Pure gold nobility", iconEmoji: "👑", rarity: .legendary, starsPrice: 2500),
                WhiteGramGift(slug: "diamond", title: "Astral Gem", descriptionText: "Exclusive NFT artifact", iconEmoji: "💎", rarity: .unique, starsPrice: 10000)
            ]
        }
        
        if let firstTarget = availableTargetGifts.first {
            selectedTargetGift = firstTarget
            targetItemIconLabel.text = firstTarget.iconEmoji
            targetItemTitleLabel.text = firstTarget.title
            targetItemSubtitleLabel.text = "\(firstTarget.rarity.title) • ⭐️ \(firstTarget.starsPrice)"
        }
    }
    
    // MARK: - Live Chance Formula
    
    /// Computes the exact live win chance based on the stake and target values.
    /// Formula: chance = min(95.0, max(1.0, (stakeValue / targetValue) * 90.0))
    public func computeLiveChance() -> (chance: Double, multiplier: Double) {
        let stakeVal: Double
        if let gift = selectedStakeGift {
            stakeVal = max(1.0, Double(gift.effectiveValue * 10))
        } else {
            stakeVal = max(1.0, Double(currentStakeStars))
        }
        
        let targetVal: Double
        if let gift = selectedTargetGift {
            targetVal = max(1.0, Double(gift.starsPrice))
        } else {
            targetVal = 500.0
        }
        
        let rawRatio = stakeVal / targetVal
        let calculatedChance = min(95.0, max(1.0, rawRatio * 90.0))
        let roundedChance = (calculatedChance * 100.0).rounded() / 100.0
        
        let multiplier = (targetVal / stakeVal * 0.95)
        let roundedMultiplier = (multiplier * 100.0).rounded() / 100.0
        
        return (roundedChance, roundedMultiplier)
    }
    
    private func recalculateAndRefreshChance(animated: Bool = true) {
        let (chance, mult) = computeLiveChance()
        gaugeView.setChance(chance, multiplier: mult, animated: animated)
        
        let btnTitle = String(format: "УЛУЧШИТЬ (%.2f%%)", chance)
        upgradeButton.setTitle(btnTitle, for: .normal)
    }
    
    // MARK: - Actions
    
    @objc private func handlePresetTapped(_ sender: UIButton) {
        guard !isSpinning else { return }
        guard let title = sender.title(for: .normal) else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        
        if title == "2x" {
            currentStakeStars = min(5000, currentStakeStars * 2)
        } else if let val = Int(title) {
            currentStakeStars = val
        }
        
        selectedStakeGift = nil
        stakeItemIconLabel.text = "⭐️"
        stakeItemTitleLabel.text = "\(currentStakeStars) Stars"
        stakeItemSubtitleLabel.text = "Баланс ставки: ⭐️ \(currentStakeStars)"
        
        recalculateAndRefreshChance(animated: true)
    }
    
    @objc private func handleSelectStakeTapped() {
        guard !isSpinning else { return }
        let alert = UIAlertController(title: "Выберите ставку", message: "Выберите предмет из вашего инвентаря или используйте Stars", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "⭐️ Использовать Stars (100)", style: .default) { [weak self] _ in
            self?.selectedStakeGift = nil
            self?.currentStakeStars = 100
            self?.stakeItemIconLabel.text = "⭐️"
            self?.stakeItemTitleLabel.text = "100 Stars"
            self?.stakeItemSubtitleLabel.text = "Ценность: 100 ⭐️"
            self?.recalculateAndRefreshChance(animated: true)
        })
        
        for gift in availableInventoryGifts {
            let actionTitle = "\(gift.iconEmoji) \(gift.title) (\(gift.rarity.title) - \(gift.starsPrice) ⭐️)"
            alert.addAction(UIAlertAction(title: actionTitle, style: .default) { [weak self] _ in
                self?.selectedStakeGift = gift
                self?.stakeItemIconLabel.text = gift.iconEmoji
                self?.stakeItemTitleLabel.text = gift.title
                self?.stakeItemSubtitleLabel.text = "\(gift.rarity.title) • ⭐️ \(gift.starsPrice)"
                self?.recalculateAndRefreshChance(animated: true)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func handleSelectTargetTapped() {
        guard !isSpinning else { return }
        let alert = UIAlertController(title: "Выберите цель улучшения", message: "Желаемый предмет для получения", preferredStyle: .actionSheet)
        
        for target in availableTargetGifts {
            let actionTitle = "\(target.iconEmoji) \(target.title) (\(target.rarity.title) - \(target.starsPrice) ⭐️)"
            alert.addAction(UIAlertAction(title: actionTitle, style: .default) { [weak self] _ in
                self?.selectedTargetGift = target
                self?.targetItemIconLabel.text = target.iconEmoji
                self?.targetItemTitleLabel.text = target.title
                self?.targetItemSubtitleLabel.text = "\(target.rarity.title) • ⭐️ \(target.starsPrice)"
                self?.recalculateAndRefreshChance(animated: true)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(alert, animated: true)
    }
    
    // MARK: - Spin & Outcome Flow
    
    @objc private func handleUpgradeTapped() {
        guard !isSpinning else { return }
        isSpinning = true
        upgradeButton.isEnabled = false
        upgradeButton.alpha = 0.6
        
        let (chance, _) = computeLiveChance()
        
        // Generate cryptographic outcome roll between 0.00 and 100.00
        let roll = Double.random(in: 0.01...100.00)
        let won = roll <= chance
        
        // 2.4s spin animation with cubic easing executed on CoreAnimation
        gaugeView.spin(toRoll: roll, duration: 2.4, fullRotations: 4) { [weak self] _ in
            guard let self = self else { return }
            self.isSpinning = false
            self.upgradeButton.isEnabled = true
            self.upgradeButton.alpha = 1.0
            
            if won {
                self.handleWinOutcome(roll: roll)
            } else {
                self.handleLossOutcome(roll: roll)
            }
        }
    }
    
    private func handleWinOutcome(roll: Double) {
        let target = selectedTargetGift ?? availableTargetGifts.first!
        
        // Add target to inventory
        var wonGift = target
        wonGift.currentOwnerId = currentUserId
        GiftStorage.shared.saveGift(wonGift)
        
        // Remove staked gift if one was used
        if let staked = selectedStakeGift {
            GiftStorage.shared.removeGift(id: staked.id)
            selectedStakeGift = nil
            stakeItemIconLabel.text = "⭐️"
            stakeItemTitleLabel.text = "100 Stars"
            stakeItemSubtitleLabel.text = "Ценность: 100 ⭐️"
        }
        
        // Refresh local lists
        availableInventoryGifts = GiftStorage.shared.getGifts(for: currentUserId)
        
        // Trigger celebration fireworks & toast
        showCelebrationFireworks()
        showToast(
            icon: "🎉",
            title: "УСПЕШНЫЙ АПГРЕЙД!",
            message: "Вы выиграли \(target.iconEmoji) \(target.title)!\nВыпало: \(String(format: "%.2f", roll))%",
            isSuccess: true
        )
        
        recalculateAndRefreshChance(animated: true)
    }
    
    private func handleLossOutcome(roll: Double) {
        // Remove staked gift
        if let staked = selectedStakeGift {
            GiftStorage.shared.removeGift(id: staked.id)
            selectedStakeGift = nil
            stakeItemIconLabel.text = "⭐️"
            stakeItemTitleLabel.text = "100 Stars"
            stakeItemSubtitleLabel.text = "Ценность: 100 ⭐️"
        }
        
        availableInventoryGifts = GiftStorage.shared.getGifts(for: currentUserId)
        
        showToast(
            icon: "💔",
            title: "НЕ УДАЛОСЬ",
            message: "Выпало \(String(format: "%.2f", roll))%. Предмет сгорел.\nПопробуйте снова!",
            isSuccess: false
        )
        
        recalculateAndRefreshChance(animated: true)
    }
    
    // MARK: - Fireworks & Toast Notifications
    
    private func showCelebrationFireworks() {
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: view.bounds.midX, y: view.bounds.midY - 80)
        emitter.emitterShape = .point
        emitter.emitterSize = CGSize(width: 10, height: 10)
        
        let colors: [UIColor] = [
            UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0),
            UIColor(red: 0.12, green: 0.74, blue: 0.98, alpha: 1.0),
            UIColor(red: 0.98, green: 0.22, blue: 0.58, alpha: 1.0),
            UIColor(red: 0.38, green: 0.88, blue: 0.42, alpha: 1.0)
        ]
        
        var cells: [CAEmitterCell] = []
        for color in colors {
            let cell = CAEmitterCell()
            cell.birthRate = 24
            cell.lifetime = 2.0
            cell.velocity = 220
            cell.velocityRange = 80
            cell.emissionRange = 2.0 * .pi
            cell.spin = 3.5
            cell.spinRange = 4.0
            cell.scale = 0.18
            cell.scaleRange = 0.08
            cell.scaleSpeed = -0.06
            cell.color = color.cgColor
            cell.alphaSpeed = -0.5
            cell.contents = createSparkParticleImage()?.cgImage
            cells.append(cell)
        }
        
        emitter.emitterCells = cells
        view.layer.addSublayer(emitter)
        fireworksEmitterLayer = emitter
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            emitter.birthRate = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            emitter.removeFromSuperlayer()
        }
    }
    
    private func createSparkParticleImage() -> UIImage? {
        let rect = CGRect(x: 0, y: 0, width: 20, height: 20)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        ctx.setFillColor(UIColor.white.cgColor)
        ctx.fillEllipse(in: rect)
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img
    }
    
    private func showToast(icon: String, title: String, message: String, isSuccess: Bool) {
        toastIconLabel.text = icon
        toastTitleLabel.text = title
        toastTitleLabel.textColor = isSuccess ? UIColor(red: 0.3, green: 0.9, blue: 0.5, alpha: 1.0) : UIColor(red: 1.0, green: 0.35, blue: 0.35, alpha: 1.0)
        toastMessageLabel.text = message
        
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            self.toastView.alpha = 1.0
            self.toastView.transform = .identity
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 2.5, options: .curveEaseIn) {
                self.toastView.alpha = 0.0
                self.toastView.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
            }
        }
    }
}
#endif
