#if canImport(UIKit)
import UIKit
import WhiteGramCore
import GhostMode
import Gifts
import Upgrader
import ProfileSync

public final class WhiteGramSettingsController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    
    private enum Section: Int, CaseIterable {
        case ghostMode
        case giftsAndWorkshop
        case profileSync
        case appearance
        case proxy
        case about
        
        var title: String {
            switch self {
            case .ghostMode: return "Ghost Mode (Режим призрака)"
            case .giftsAndWorkshop: return "Local & NFT Gifts & Workshop"
            case .profileSync: return "Profile & Badges Sync"
            case .appearance: return "Appearance & Animations"
            case .proxy: return "TgWsProxy Connection"
            case .about: return "About WhiteGram"
            }
        }
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "WhiteGram Settings"
        view.backgroundColor = WhiteGramTheme.shared.backgroundColor
        
        setupTableView()
    }
    
    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - UITableViewDataSource
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let s = Section(rawValue: section) else { return 0 }
        switch s {
        case .ghostMode: return 4
        case .giftsAndWorkshop: return 3
        case .profileSync: return 2
        case .appearance: return 2
        case .proxy: return 2
        case .about: return 2
        }
    }
    
    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Section(rawValue: section)?.title
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "Cell")
        cell.accessoryType = .disclosureIndicator
        
        guard let s = Section(rawValue: indexPath.section) else { return cell }
        switch (s, indexPath.row) {
        case (.ghostMode, 0):
            cell.textLabel?.text = "Ghost Mode Master Switch"
            cell.detailTextLabel?.text = "Suppresses online presence, typing, and read receipts"
        case (.ghostMode, 1):
            cell.textLabel?.text = "Hide Online Status"
            cell.detailTextLabel?.text = "Never send account.updateStatus"
        case (.ghostMode, 2):
            cell.textLabel?.text = "Hide Typing Indicator"
            cell.detailTextLabel?.text = "Block messages.setTyping"
        case (.ghostMode, 3):
            cell.textLabel?.text = "Selective Read Receipts"
            cell.detailTextLabel?.text = "Mark read on manual action or scheduled reply"
            
        case (.giftsAndWorkshop, 0):
            cell.textLabel?.text = "Gifts Shelf"
            cell.detailTextLabel?.text = "View local collectible and NFT gifts"
        case (.giftsAndWorkshop, 1):
            cell.textLabel?.text = "Upgrader"
            cell.detailTextLabel?.text = "Radial gauge, win chance rolls and fireworks"
        case (.giftsAndWorkshop, 2):
            cell.textLabel?.text = "Craft Workshop"
            cell.detailTextLabel?.text = "Combine 4 items for upgraded rarity"
            
        case (.profileSync, 0):
            cell.textLabel?.text = "Silent Background Sync"
            cell.detailTextLabel?.text = "Enabled by default"
        case (.profileSync, 1):
            cell.textLabel?.text = "Custom Badges & Banners"
            cell.detailTextLabel?.text = "Local developer/tester badge display"
            
        case (.appearance, 0):
            cell.textLabel?.text = "Accent Color Palette"
            cell.detailTextLabel?.text = "Unified colors across all chats"
        case (.appearance, 1):
            cell.textLabel?.text = "Animation Speed"
            cell.detailTextLabel?.text = "Custom duration curves 25% – 300%"
            
        case (.proxy, 0):
            cell.textLabel?.text = "TgWsProxy Link Setup"
            cell.detailTextLabel?.text = "Paste tg://ws-proxy or flowseal URL"
        case (.proxy, 1):
            cell.textLabel?.text = "Test Local Port"
            cell.detailTextLabel?.text = "Check 127.0.0.1:1443 connectivity"
            
        case (.about, 0):
            cell.textLabel?.text = "Version"
            cell.detailTextLabel?.text = WhiteGramVersion.fullDescription
        case (.about, 1):
            cell.textLabel?.text = "Channel & Support"
            cell.detailTextLabel?.text = WhiteGramVersion.channelUrl
            
        default:
            break
        }
        
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let s = Section(rawValue: indexPath.section) else { return }
        
        switch (s, indexPath.row) {
        case (.ghostMode, 0):
            let newState = GhostModeManager.shared.toggleGhostMode()
            let alert = UIAlertController(
                title: "Ghost Mode",
                message: newState ? "Ghost Mode activated: Presence, typing, and read receipts suppressed." : "Ghost Mode deactivated.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            
        case (.giftsAndWorkshop, 0):
            let shelfVC = GiftShelfAllViewController(userId: 777000, isCurrentAccount: true)
            navigationController?.pushViewController(shelfVC, animated: true)
            
        case (.giftsAndWorkshop, 1):
            let upgraderVC = UpgraderViewController()
            navigationController?.pushViewController(upgraderVC, animated: true)
            
        case (.giftsAndWorkshop, 2):
            let craftVC = CraftWorkshopViewController()
            navigationController?.pushViewController(craftVC, animated: true)
            
        default:
            break
        }
    }
}
#endif
