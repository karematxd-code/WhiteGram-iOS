import Foundation

public struct WhiteGramVersion {
    public static let string: String = "0.5.3-beta"
    public static let buildNumber: Int = 530
    public static let clientName: String = "WhiteGram iOS"
    public static let channelUrl: String = "https://t.me/xWhiteGram"
    public static let developerUrl: String = "https://t.me/likecry"
    public static let bundleId: String = "org.whitegram.messenger"
    
    public static var fullDescription: String {
        return "\(clientName) v\(string) (\(buildNumber))"
    }
}
