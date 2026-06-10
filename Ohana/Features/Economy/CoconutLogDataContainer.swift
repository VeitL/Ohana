import SwiftData
import SwiftUI

struct CoconutLogView: View {
    @Query(sort: \CoconutAccount.updatedAt, order: .reverse) private var walletAccounts: [CoconutAccount]
    @Query(sort: \CoconutLedgerEntry.occurredAt, order: .reverse) private var walletLedgerEntries: [CoconutLedgerEntry]

    private let subject: CoconutLogSubject?
    private let onClose: (() -> Void)?
    private let safeTopInset: CGFloat
    private let safeBottomInset: CGFloat
    private let historyContentDelayMilliseconds: UInt64

    init(
        subject: CoconutLogSubject? = nil,
        onClose: (() -> Void)? = nil,
        safeTopInset: CGFloat = 0,
        safeBottomInset: CGFloat = 0,
        historyContentDelayMilliseconds: UInt64 = 70
    ) {
        self.subject = subject
        self.onClose = onClose
        self.safeTopInset = safeTopInset
        self.safeBottomInset = safeBottomInset
        self.historyContentDelayMilliseconds = historyContentDelayMilliseconds
    }

    var body: some View {
        CoconutLogContentView(
            walletAccounts: walletAccounts,
            walletLedgerEntries: walletLedgerEntries,
            subject: subject,
            onClose: onClose,
            safeTopInset: safeTopInset,
            safeBottomInset: safeBottomInset,
            historyContentDelayMilliseconds: historyContentDelayMilliseconds
        )
    }
}
