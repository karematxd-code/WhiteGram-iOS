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
        case about
        
        var title: String {
            switch self {
            case .ghostMode: return "👻 Режим призрака (Ghost Mode)"
            case .giftsAndWorkshop: return "🎁 Подарки, Апгрейдер и Крафт"
            case .profileSync: return "🔄 Синхронизация профиля и бейджи"
            case .appearance: return "🎨 Оформление WhiteGram"
            case .about: return "ℹ️ О клиенте WhiteGram"
            }
        }
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "⚡ WhiteGram 0.5.3"
        view.backgroundColor = UIColor(red: 17/255.0, green: 24/255.0, blue: 39/255.0, alpha: 1.0)
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Закрыть",
            style: .done,
            target: self,
            action: #selector(closeTapped)
        )
        
        setupTableView()
    }
    
    @objc private func closeTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.backgroundColor = .clear
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
        case .about: return 2
        }
    }
    
    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Section(rawValue: section)?.title
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "Cell")
        cell.backgroundColor = UIColor(white: 0.14, alpha: 0.8)
        cell.textLabel?.textColor = .white
        cell.detailTextLabel?.textColor = UIColor(white: 0.7, alpha: 1.0)
        
        guard let s = Section(rawValue: indexPath.section) else { return cell }
        
        let settings = GhostModeManager.shared.settings
        
        switch (s, indexPath.row) {
        case (.ghostMode, 0):
            cell.textLabel?.text = "Главный переключатель Ghost Mode"
            cell.detailTextLabel?.text = "Блокирует онлайн, тайпинг и прочтение сообщений"
            let toggle = UISwitch()
            toggle.isOn = settings.isEnabled
            toggle.onTintColor = UIColor(red: 143/255.0, green: 240/255.0, blue: 220/255.0, alpha: 1.0)
            toggle.addTarget(self, action: #selector(toggleMasterGhost(_:)), for: .valueChanged)
            cell.accessoryView = toggle
            
        case (.ghostMode, 1):
            cell.textLabel?.text = "Скрывать статус «В сети»"
            cell.detailTextLabel?.text = "Подавление пакетов account.updateStatus"
            let toggle = UISwitch()
            toggle.isOn = settings.suppressOnlinePresence
            toggle.addTarget(self, action: #selector(toggleOnlinePresence(_:)), for: .valueChanged)
            cell.accessoryView = toggle
            
        case (.ghostMode, 2):
            cell.textLabel?.text = "Скрывать статус набора текста"
            cell.detailTextLabel?.text = "Подавление пакетов messages.setTyping"
            let toggle = UISwitch()
            toggle.isOn = settings.suppressTypingIndicator
            toggle.addTarget(self, action: #selector(toggleTypingIndicator(_:)), for: .valueChanged)
            cell.accessoryView = toggle
            
        case (.ghostMode, 3):
            cell.textLabel?.text = "Не читать сообщения (Selective Read)"
            cell.detailTextLabel?.text = "Чтение только при явном ответе (Read-on-Action)"
            let toggle = UISwitch()
            toggle.isOn = settings.suppressReadReceipts
            toggle.addTarget(self, action: #selector(toggleReadReceipts(_:)), for: .valueChanged)
            cell.accessoryView = toggle
            
        case (.giftsAndWorkshop, 0):
            cell.textLabel?.text = "🎁 Витрина подарков и NFT"
            cell.detailTextLabel?.text = "Локальная коллекция, пересылка, распаковка"
            cell.accessoryType = .disclosureIndicator
            
        case (.giftsAndWorkshop, 1):
            cell.textLabel?.text = "⚡ Апгрейдер подарков"
            cell.detailTextLabel?.text = "Радиальный спидометр, вращение стрелки, салют"
            cell.accessoryType = .disclosureIndicator
            
        case (.giftsAndWorkshop, 2):
            cell.textLabel?.text = "⚒️ Мастерская крафта"
            cell.detailTextLabel?.text = "4 слота (по 25% за предмет), анимация наковальни"
            cell.accessoryType = .disclosureIndicator
            
        case (.profileSync, 0):
            cell.textLabel?.text = "Фоновая синхронизация"
            cell.detailTextLabel?.text = "Локальное зеркало бейджей и предметов"
            let toggle = UISwitch()
            toggle.isOn = true
            cell.accessoryView = toggle
            
        case (.profileSync, 1):
            cell.textLabel?.text = "Кастомные бейджи профиля"
            cell.detailTextLabel?.text = "Отображение бейджей разработчика / тестера"
            cell.accessoryType = .disclosureIndicator
            
        case (.appearance, 0):
            cell.textLabel?.text = "Фирменная тема WhiteGram"
            cell.detailTextLabel?.text = "Черно-белая высококонтрастная палитра"
            let toggle = UISwitch()
            toggle.isOn = true
            cell.accessoryView = toggle
            
        case (.appearance, 1):
            cell.textLabel?.text = "Скорость анимаций"
            cell.detailTextLabel?.text = "Нативная частота 120 Гц ProMotion"
            cell.accessoryType = .disclosureIndicator
            
        case (.about, 0):
            cell.textLabel?.text = "Версия клиента"
            cell.detailTextLabel?.text = "WhiteGram 0.5.3-beta (iOS arm64 full parity)"
        case (.about, 1):
            cell.textLabel?.text = "Канал и поддержка"
            cell.detailTextLabel?.text = WhiteGramVersion.channelUrl
            cell.accessoryType = .disclosureIndicator
            
        default:
            break
        }
        
        return cell
    }
    
    // MARK: - Actions
    
    @objc private func toggleMasterGhost(_ sender: UISwitch) {
        GhostModeManager.shared.updateSettings { $0.isEnabled = sender.isOn }
        tableView.reloadData()
    }
    
    @objc private func toggleOnlinePresence(_ sender: UISwitch) {
        GhostModeManager.shared.updateSettings { $0.suppressOnlinePresence = sender.isOn }
    }
    
    @objc private func toggleTypingIndicator(_ sender: UISwitch) {
        GhostModeManager.shared.updateSettings { $0.suppressTypingIndicator = sender.isOn }
    }
    
    @objc private func toggleReadReceipts(_ sender: UISwitch) {
        GhostModeManager.shared.updateSettings { $0.suppressReadReceipts = sender.isOn }
    }
    
    // MARK: - UITableViewDelegate
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let s = Section(rawValue: indexPath.section) else { return }
        
        switch (s, indexPath.row) {
        case (.giftsAndWorkshop, 0):
            let shelfVC = GiftShelfAllViewController(userId: 777000, isCurrentAccount: true)
            navigationController?.pushViewController(shelfVC, animated: true)
            
        case (.giftsAndWorkshop, 1):
            let upgraderVC = UpgraderViewController()
            navigationController?.pushViewController(upgraderVC, animated: true)
            
        case (.giftsAndWorkshop, 2):
            let craftVC = CraftWorkshopViewController()
            navigationController?.pushViewController(craftVC, animated: true)
            
        case (.about, 1):
            if let url = URL(string: WhiteGramVersion.channelUrl) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            
        default:
            break
        }
    }
}
#endif
