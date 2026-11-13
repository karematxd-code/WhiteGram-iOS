#if canImport(UIKit)
import UIKit
import WhiteGramCore

public final class WhiteGramTheme {
    public static let shared = WhiteGramTheme()
    
    public var accentColor: UIColor {
        get {
            if let hex = WhiteGramStorage.shared.get(forKey: "theme_accent_color") as? String {
                return UIColor(hex: hex) ?? defaultAccentColor
            }
            return defaultAccentColor
        }
        set {
            WhiteGramStorage.shared.set(newValue.toHexString(), forKey: "theme_accent_color")
        }
    }
    
    public var defaultAccentColor: UIColor {
        return UIColor(red: 0.18, green: 0.58, blue: 0.94, alpha: 1.0) // Telegram / WhiteGram Azure
    }
    
    public var secondaryColor: UIColor {
        return UIColor(red: 0.40, green: 0.22, blue: 0.88, alpha: 1.0) // WhiteGram Purple / Nebula
    }
    
    public var backgroundColor: UIColor {
        return .systemBackground
    }
    
    public var secondaryBackgroundColor: UIColor {
        return .secondarySystemBackground
    }
    
    public var cardBackgroundColor: UIColor {
        return .tertiarySystemBackground
    }
    
    public var textColor: UIColor {
        return .label
    }
    
    public var secondaryTextColor: UIColor {
        return .secondaryLabel
    }
    
    public var animationSpeedMultiplier: Double {
        get {
            let speed = WhiteGramStorage.shared.get(forKey: "animation_speed") as? Double ?? 1.0
            return max(0.25, min(3.0, speed))
        }
        set {
            WhiteGramStorage.shared.set(newValue, forKey: "animation_speed")
        }
    }
}

extension UIColor {
    convenience init?(hex: String) {
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
    
    func toHexString(includeAlpha: Bool = false) -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        
        if includeAlpha {
            return String(format: "#%02X%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255), Int(a * 255))
        } else {
            return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        }
    }
}
#endif
