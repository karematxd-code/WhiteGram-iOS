import Foundation
import WhiteGramCore

#if canImport(UIKit)
import UIKit
#endif

public final class GiftsModule {
    public static let shared = GiftsModule()
    
    private init() {}
    
    public func initialize(for userId: Int64) {
        GiftStorage.shared.seedInitialDataIfNeeded(for: userId)
    }
    
    #if canImport(UIKit)
    public func makeProfileShelfView(for userId: Int64, isCurrentAccount: Bool = true) -> GiftProfileShelfView {
        let view = GiftProfileShelfView()
        view.userId = userId
        view.isCurrentAccount = isCurrentAccount
        return view
    }
    
    public func presentTransferDialog(
        for gift: WhiteGramGift,
        fromUserId: Int64,
        on presentingViewController: UIViewController,
        completion: ((WhiteGramGift, Int64) -> Void)? = nil
    ) {
        let transferVC = GiftTransferController(gift: gift, currentUserId: fromUserId)
        transferVC.onTransferCompleted = completion
        let nav = UINavigationController(rootViewController: transferVC)
        nav.modalPresentationStyle = .formSheet
        presentingViewController.present(nav, animated: true)
    }
    #endif
}
