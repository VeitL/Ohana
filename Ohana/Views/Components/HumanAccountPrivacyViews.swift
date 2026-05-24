//
//  HumanAccountPrivacyViews.swift
//  Ohana
//
//  Local account switching, passcode management, and privacy test helpers.
//

import SwiftUI
import SwiftData

struct HumanAccountSwitcherSheet: View {
    var onSwitched: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @AppStorage("currentActiveHumanId") private var activeHumanId = ""

    @State private var pendingHuman: Human? = nil
    @State private var pin = ""
    @State private var statusMessage = ""
    @State private var isError = false
    @State private var now = Date()
    @State private var pendingPurpose: PendingPurpose = .switchAccount
    @State private var securityHuman: Human? = nil

    private enum PendingPurpose {
        case switchAccount
        case manageSecurity

        var prompt: String {
            switch self {
            case .switchAccount:
                return "验证通过后会切换到该账户"
            case .manageSecurity:
                return "验证通过后打开密码与隐私设置"
            }
        }
    }

    private var activeHuman: Human? {
        humans.first { $0.id.uuidString == activeHumanId && !$0.hasPassedAway }
    }

    private var switchableHumans: [Human] {
        humans.filter { !$0.hasPassedAway }
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    activeAccountCard
                    accountList
                    if let pendingHuman {
                        pinPanel(for: pendingHuman)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 26)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .animation(GoMotion.feedback, value: pendingHuman?.id)
        .sheet(item: $securityHuman) { human in
            HumanAccountSecuritySheet(human: human)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "person.2.badge.key.fill")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 42, height: 42)
                .background(Color.goPrimary.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text("切换人类账户")
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text("成员与密码")
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 38, height: 34)
                    .background(Color.ohanaControlFill, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    @ViewBuilder
    private var activeAccountCard: some View {
        if let activeHuman {
            HStack(spacing: 12) {
                accountAvatar(activeHuman, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text("当前账户")
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Text(displayName(activeHuman))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                }
                Spacer()
                lockButton(for: activeHuman)
            }
            .padding(14)
            .goTranslucentCard(cornerRadius: 18)
        }
    }

    private var accountList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("成员")
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
                .padding(.horizontal, 2)

            ForEach(switchableHumans) { human in
                accountRow(for: human)
            }
        }
    }

    private func accountRow(for human: Human) -> some View {
        HStack(spacing: 10) {
            Button {
                choose(human)
            } label: {
                HStack(spacing: 12) {
                    accountAvatar(human, size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(displayName(human))
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(human.roleText)
                            .font(OhanaFont.caption2(.bold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    Spacer()
                    statusBadge(for: human)
                }
            }
            .buttonStyle(ScaleButtonStyle())

            lockButton(for: human)
        }
        .padding(13)
        .background(pendingHuman?.id == human.id ? Color.goPrimary.opacity(0.16) : Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(pendingHuman?.id == human.id ? Color.goPrimary.opacity(0.44) : Color.clear, lineWidth: 1)
        }
    }

    @ViewBuilder
    private func statusBadge(for human: Human) -> some View {
        if human.id.uuidString == activeHumanId {
            Text("当前")
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(Color.arkInk)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.goPrimary, in: Capsule())
        } else if HumanPasscodeService.hasPasscode(human) {
            Text("需密码")
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(Color.goYellow)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.goYellow.opacity(0.14), in: Capsule())
        } else {
            Text("可切换")
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.ohanaControlFill, in: Capsule())
        }
    }

    private func lockButton(for human: Human) -> some View {
        Button {
            openSecurity(for: human)
        } label: {
            Image(systemName: HumanPasscodeService.hasPasscode(human) ? "lock.fill" : "lock.open.fill")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(HumanPasscodeService.hasPasscode(human) ? Color.goYellow : Color.ohanaTertiaryText)
                .frame(width: 36, height: 36)
                .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("密码与隐私")
    }

    private func pinPanel(for human: Human) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                accountAvatar(human, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text("输入 \(displayName(human)) 的 4 位密码")
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(statusMessage.isEmpty ? pendingPurpose.prompt : statusMessage)
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(isError ? Color.goRed : Color.ohanaSecondaryText)
                }
                Spacer()
            }

            HumanPasscodePad(pin: $pin, accent: Color(hex: human.themeColor)) {
                verifyPendingPasscode()
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
    }

    private func choose(_ human: Human) {
        UISelectionFeedbackGenerator().selectionChanged()
        pendingPurpose = .switchAccount
        guard human.id.uuidString != activeHumanId else {
            dismiss()
            return
        }
        guard HumanPasscodeService.hasPasscode(human) else {
            switchTo(human)
            return
        }
        now = Date()
        if let seconds = HumanPasscodeService.remainingLockoutSeconds(for: human, now: now) {
            pendingHuman = human
            pin = ""
            isError = true
            statusMessage = "请 \(seconds) 秒后再试"
            return
        }
        pendingHuman = human
        pin = ""
        isError = false
        statusMessage = ""
    }

    private func openSecurity(for human: Human) {
        UISelectionFeedbackGenerator().selectionChanged()
        guard human.id.uuidString != activeHumanId else {
            pendingHuman = nil
            pin = ""
            securityHuman = human
            return
        }
        guard HumanPasscodeService.hasPasscode(human) else {
            activateAndManageSecurity(human)
            return
        }
        now = Date()
        pendingPurpose = .manageSecurity
        pendingHuman = human
        pin = ""
        if let seconds = HumanPasscodeService.remainingLockoutSeconds(for: human, now: now) {
            isError = true
            statusMessage = "请 \(seconds) 秒后再试"
        } else {
            isError = false
            statusMessage = ""
        }
    }

    private func verifyPendingPasscode() {
        guard let human = pendingHuman else { return }
        now = Date()
        switch HumanPasscodeService.verify(pin, for: human, now: now) {
        case .success:
            modelContext.safeSave()
            completePendingAccess(for: human)
        case .incorrect(let remaining):
            modelContext.safeSave()
            pin = ""
            isError = true
            statusMessage = "密码不正确，还可尝试 \(remaining) 次"
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .locked(let until):
            modelContext.safeSave()
            pin = ""
            isError = true
            statusMessage = "尝试过多，请 \(max(1, Int(ceil(until.timeIntervalSince(now))))) 秒后再试"
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .invalidFormat:
            pin = ""
            isError = true
            statusMessage = "请输入 4 位数字"
        case .noPasscode:
            completePendingAccess(for: human)
        }
    }

    private func completePendingAccess(for human: Human) {
        switch pendingPurpose {
        case .switchAccount:
            switchTo(human)
        case .manageSecurity:
            activateAndManageSecurity(human)
        }
    }

    private func activateAndManageSecurity(_ human: Human) {
        activeHumanId = human.id.uuidString
        pendingHuman = nil
        pin = ""
        statusMessage = ""
        isError = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onSwitched?()
        securityHuman = human
    }

    private func switchTo(_ human: Human) {
        activeHumanId = human.id.uuidString
        pendingHuman = nil
        pin = ""
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onSwitched?()
        dismiss()
    }

    @ViewBuilder
    private func accountAvatar(_ human: Human, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: human.themeColor).opacity(0.18))
                .frame(width: size, height: size)
            if let data = human.avatarImageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Text(human.avatarEmoji.isEmpty ? "👤" : human.avatarEmoji)
                    .font(.system(size: size * 0.45))
            }
        }
    }

    private func displayName(_ human: Human) -> String {
        let name = human.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "未命名成员" : name
    }
}

struct HumanExecutorSwitchSheet: View {
    var onSwitched: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @AppStorage("currentActiveHumanId") private var activeHumanId = ""

    @State private var pendingHuman: Human? = nil
    @State private var pin = ""
    @State private var statusMessage = ""
    @State private var isError = false
    @State private var now = Date()

    private var activeHuman: Human? {
        humans.first { $0.id.uuidString == activeHumanId && !$0.hasPassedAway }
    }

    private var switchableHumans: [Human] {
        humans.filter { !$0.hasPassedAway }
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()

            VStack(alignment: .leading, spacing: 14) {
                header
                if pendingHuman == nil {
                    accountRows
                }
                if let pendingHuman {
                    pinPanel(for: pendingHuman)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 20)
        }
        .presentationDetents([.height(pendingHuman == nil ? 330 : 430)])
        .presentationDragIndicator(.hidden)
        .animation(GoMotion.feedback, value: pendingHuman?.id)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 42, height: 42)
                .background(Color.goPrimary.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text("切换执行人")
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text("后续打卡会记录到当前账户")
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .frame(width: 34, height: 34)
                    .background(Color.primary.opacity(0.08), in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private var accountRows: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 9) {
                ForEach(switchableHumans) { human in
                    accountRow(for: human)
                }
            }
            .padding(.vertical, 1)
        }
        .frame(maxHeight: 190)
    }

    private func accountRow(for human: Human) -> some View {
        let isActive = human.id.uuidString == activeHumanId
        return Button {
            choose(human)
        } label: {
            HStack(spacing: 12) {
                accountAvatar(human, size: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName(human))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(isActive ? "当前执行人" : (HumanPasscodeService.hasPasscode(human) ? "需要 4 位密码" : "可直接切换"))
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(Color.goPrimary)
                } else if HumanPasscodeService.hasPasscode(human) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Color.goYellow)
                        .frame(width: 30, height: 30)
                        .background(Color.goYellow.opacity(0.14), in: Circle())
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
            .padding(12)
            .background(
                Color.primary.opacity(pendingHuman?.id == human.id ? 0.11 : (isActive ? 0.09 : 0.055)),
                in: RoundedRectangle(cornerRadius: 17, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .strokeBorder(pendingHuman?.id == human.id ? Color.goPrimary.opacity(0.52) : Color.primary.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func pinPanel(for human: Human) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                accountAvatar(human, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("输入 \(displayName(human)) 的 4 位密码")
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(statusMessage.isEmpty ? "验证后切换执行人" : statusMessage)
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(isError ? Color.goRed : .secondary)
                }
                Spacer()
                Button {
                    pendingHuman = nil
                    pin = ""
                    statusMessage = ""
                    isError = false
                } label: {
                    Text("换人")
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.goPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.goPrimary.opacity(0.14), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }

            HumanPasscodePad(pin: $pin, accent: Color(hex: human.themeColor)) {
                verifyPendingPasscode()
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.075), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
        }
    }

    private func choose(_ human: Human) {
        UISelectionFeedbackGenerator().selectionChanged()
        guard human.id.uuidString != activeHumanId else {
            dismiss()
            return
        }
        guard HumanPasscodeService.hasPasscode(human) else {
            switchTo(human)
            return
        }
        now = Date()
        pendingHuman = human
        pin = ""
        if let seconds = HumanPasscodeService.remainingLockoutSeconds(for: human, now: now) {
            isError = true
            statusMessage = "请 \(seconds) 秒后再试"
        } else {
            isError = false
            statusMessage = ""
        }
    }

    private func verifyPendingPasscode() {
        guard let human = pendingHuman else { return }
        now = Date()
        switch HumanPasscodeService.verify(pin, for: human, now: now) {
        case .success, .noPasscode:
            modelContext.safeSave()
            switchTo(human)
        case .incorrect(let remaining):
            modelContext.safeSave()
            pin = ""
            isError = true
            statusMessage = "密码不正确，还可尝试 \(remaining) 次"
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .locked(let until):
            modelContext.safeSave()
            pin = ""
            isError = true
            statusMessage = "尝试过多，请 \(max(1, Int(ceil(until.timeIntervalSince(now))))) 秒后再试"
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .invalidFormat:
            pin = ""
            isError = true
            statusMessage = "请输入 4 位数字"
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func switchTo(_ human: Human) {
        activeHumanId = human.id.uuidString
        pendingHuman = nil
        pin = ""
        statusMessage = ""
        isError = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onSwitched?()
        dismiss()
    }

    @ViewBuilder
    private func accountAvatar(_ human: Human, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: human.themeColor).opacity(0.18))
                .frame(width: size, height: size)
            if let data = human.avatarImageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Text(human.avatarEmoji.isEmpty ? "👤" : human.avatarEmoji)
                    .font(.system(size: size * 0.45))
            }
        }
    }

    private func displayName(_ human: Human) -> String {
        let name = human.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "未命名成员" : name
    }
}

struct HumanPasscodeManagementSheet: View {
    let human: Human

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var mode: Mode
    @State private var currentPin = ""
    @State private var newPin = ""
    @State private var confirmPin = ""
    @State private var message = ""
    @State private var isError = false

    private enum Mode {
        case set
        case overview
        case change
        case remove
    }

    private enum PinInputTarget: Hashable {
        case current
        case new
        case confirm
    }

    @State private var activePinTarget: PinInputTarget?

    init(human: Human) {
        self.human = human
        self._mode = State(initialValue: HumanPasscodeService.hasPasscode(human) ? .overview : .set)
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()

            VStack(alignment: .leading, spacing: 18) {
                header
                content
                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .presentationDetents([.height(470), .medium])
        .presentationDragIndicator(.hidden)
        .onChange(of: currentPin) { _, value in currentPin = sanitized(value) }
        .onChange(of: newPin) { _, value in newPin = sanitized(value) }
        .onChange(of: confirmPin) { _, value in confirmPin = sanitized(value) }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: HumanPasscodeService.hasPasscode(human) ? "lock.shield.fill" : "lock.open.fill")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color.goYellow)
                .frame(width: 42, height: 42)
                .background(Color.goYellow.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text("账户 4 位密码")
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text("用于在同一设备上切换到 \(displayName(human)) 时验证")
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .frame(width: 34, height: 34)
                    .background(Color.primary.opacity(0.08), in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .overview:
            VStack(spacing: 12) {
                statusCard(title: "已开启", subtitle: "其他成员切换到此账户时需要输入 4 位密码", icon: "checkmark.shield.fill", tint: Color.goPrimary)
                Button { resetInputs(); mode = .change } label: {
                    actionRow(title: "修改密码", icon: "key.fill", tint: Color.goPrimary)
                }
                .buttonStyle(ScaleButtonStyle())
                Button { resetInputs(); mode = .remove } label: {
                    actionRow(title: "关闭密码", icon: "lock.open.fill", tint: Color.goRed)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        case .set:
            formContent(
                title: "设置 4 位密码",
                needsCurrent: false,
                primaryTitle: "开启密码",
                primaryAction: setPasscode
            )
        case .change:
            formContent(
                title: "修改 4 位密码",
                needsCurrent: true,
                primaryTitle: "保存新密码",
                primaryAction: changePasscode
            )
        case .remove:
            VStack(spacing: 14) {
                statusCard(title: "关闭后可直接切换", subtitle: "请输入当前密码确认关闭", icon: "exclamationmark.lock.fill", tint: Color.goRed)
                pinField("当前密码", text: $currentPin, target: .current)
                messageView
                HStack(spacing: 10) {
                    secondaryButton("返回") { resetInputs(); mode = .overview }
                    primaryButton("关闭密码", tint: Color.goRed, foreground: .white, action: removePasscode)
                }
            }
        }
    }

    private func formContent(title: String, needsCurrent: Bool, primaryTitle: String, primaryAction: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            if needsCurrent {
                pinField("当前密码", text: $currentPin, target: .current)
            }
            pinField("新密码", text: $newPin, target: .new)
            pinField("确认新密码", text: $confirmPin, target: .confirm)
            messageView
            HStack(spacing: 10) {
                if HumanPasscodeService.hasPasscode(human) {
                    secondaryButton("返回") { resetInputs(); mode = .overview }
                }
                primaryButton(primaryTitle, tint: Color.goPrimary, action: primaryAction)
            }
        }
    }

    private func statusCard(title: String, subtitle: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(subtitle)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func actionRow(title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            Text(title)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(Color.ohanaSecondaryText.opacity(0.5))
        }
        .padding(14)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func pinField(_ title: String, text: Binding<String>, target: PinInputTarget) -> some View {
        VStack(spacing: 8) {
            Button {
                GoKeyboard.dismiss()
                withAnimation(GoMotion.feedback) {
                    activePinTarget = activePinTarget == target ? nil : target
                }
            } label: {
                HStack {
                    Text(title)
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Spacer()
                    HStack(spacing: 7) {
                        ForEach(0..<4, id: \.self) { index in
                            Circle()
                                .fill(index < text.wrappedValue.count ? Color.goPrimary : Color.ohanaControlFill)
                                .frame(width: 10, height: 10)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(activePinTarget == target ? Color.goPrimary.opacity(0.42) : Color.primary.opacity(0.10), lineWidth: 1)
                }
            }
            .buttonStyle(ScaleButtonStyle())

            if activePinTarget == target {
                HumanPasscodePad(pin: text, accent: Color.goPrimary) {
                    withAnimation(GoMotion.feedback) {
                        activePinTarget = nil
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
    }

    @ViewBuilder
    private var messageView: some View {
        if !message.isEmpty {
            Text(message)
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(isError ? Color.goRed : Color.goPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func primaryButton(_ title: String, tint: Color, foreground: Color = Color.arkInk, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(tint, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.72))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func setPasscode() {
        guard validateNewPins() else { return }
        do {
            try HumanPasscodeService.setPasscode(newPin, for: human)
            modelContext.safeSave()
            successAndDismiss("密码已开启")
        } catch {
            showError("请输入 4 位数字")
        }
    }

    private func changePasscode() {
        guard validateNewPins() else { return }
        do {
            let result = try HumanPasscodeService.changePasscode(currentPin: currentPin, newPin: newPin, for: human)
            handleManagementResult(result, success: "密码已修改")
        } catch {
            showError("请输入 4 位数字")
        }
    }

    private func removePasscode() {
        do {
            let result = try HumanPasscodeService.removePasscode(currentPin: currentPin, for: human)
            handleManagementResult(result, success: "密码已关闭")
        } catch {
            showError("请输入当前 4 位密码")
        }
    }

    private func handleManagementResult(_ result: HumanPasscodeVerification, success: String) {
        switch result {
        case .success:
            modelContext.safeSave()
            successAndDismiss(success)
        case .incorrect(let remaining):
            modelContext.safeSave()
            showError("当前密码不正确，还可尝试 \(remaining) 次")
        case .locked(let until):
            modelContext.safeSave()
            showError("尝试过多，请 \(max(1, Int(ceil(until.timeIntervalSince(Date()))))) 秒后再试")
        case .invalidFormat:
            showError("请输入 4 位数字")
        case .noPasscode:
            showError("此账户还没有密码")
        }
    }

    private func validateNewPins() -> Bool {
        guard HumanPasscodeService.isValidPin(newPin) else {
            showError("新密码需要是 4 位数字")
            return false
        }
        guard newPin == confirmPin else {
            showError("两次输入不一致")
            return false
        }
        return true
    }

    private func successAndDismiss(_ text: String) {
        isError = false
        message = text
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    private func showError(_ text: String) {
        isError = true
        message = text
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    private func resetInputs() {
        currentPin = ""
        newPin = ""
        confirmPin = ""
        message = ""
        isError = false
        activePinTarget = nil
    }

    private func sanitized(_ value: String) -> String {
        String(value.filter { $0.isNumber }.prefix(4))
    }

    private func displayName(_ human: Human) -> String {
        let name = human.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "未命名成员" : name
    }
}

struct HumanAccountSecuritySheet: View {
    let human: Human

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showingPasscodeSheet = false

    private var hasPasscode: Bool {
        HumanPasscodeService.hasPasscode(human)
    }

    private var privateCount: Int {
        HumanPrivateField.allCases.filter { human.privateFields.contains($0.rawValue) }.count
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    passcodeCard
                    privacyCard
                }
                .padding(20)
                .padding(.bottom, 10)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .sheet(isPresented: $showingPasscodeSheet) {
            HumanPasscodeManagementSheet(human: human)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            accountAvatar(size: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text("密码与隐私")
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(displayName(human))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .frame(width: 34, height: 34)
                    .background(Color.primary.opacity(0.08), in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private var passcodeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: hasPasscode ? "lock.shield.fill" : "lock.open.fill")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(hasPasscode ? Color.goYellow : Color.goPrimary)
                    .frame(width: 40, height: 40)
                    .background((hasPasscode ? Color.goYellow : Color.goPrimary).opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("账户密码")
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(hasPasscode ? "切换到此账户时需要 4 位密码" : "当前为公开切换，可直接进入")
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                Text(hasPasscode ? "隐私" : "公开")
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(hasPasscode ? Color.goYellow : Color.arkInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(hasPasscode ? Color.goYellow.opacity(0.14) : Color.goPrimary, in: Capsule())
            }

            Button {
                showingPasscodeSheet = true
            } label: {
                Label(hasPasscode ? "修改或关闭密码" : "设置 4 位密码", systemImage: "key.fill")
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 20)
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("资料可见性")
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(privateCount == 0 ? "所有敏感资料对家庭成员公开" : "\(privateCount) 项设为仅本人可见")
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                Button {
                    setAllPrivate(false)
                } label: {
                    Text("全公开")
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(Color.goPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.goPrimary.opacity(0.12), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                Button {
                    setAllPrivate(true)
                } label: {
                    Text("全隐私")
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(Color.goYellow)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.goYellow.opacity(0.14), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }

            ForEach(HumanPrivateField.allCases) { field in
                privacyToggleRow(field)
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 20)
    }

    private func privacyToggleRow(_ field: HumanPrivateField) -> some View {
        Toggle(isOn: Binding(
            get: { human.privateFields.contains(field.rawValue) },
            set: { isPrivate in
                human.setPrivate(field, isPrivate)
                modelContext.safeSave()
                UISelectionFeedbackGenerator().selectionChanged()
            }
        )) {
            HStack(spacing: 10) {
                Image(systemName: icon(for: field))
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.goYellow)
                    .frame(width: 30, height: 30)
                    .background(Color.goYellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(field.title)
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(human.privateFields.contains(field.rawValue) ? "仅本人可见" : "家庭成员可见")
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
        }
        .tint(Color.goYellow)
        .padding(.vertical, 4)
    }

    private func setAllPrivate(_ isPrivate: Bool) {
        for field in HumanPrivateField.allCases {
            human.setPrivate(field, isPrivate)
        }
        modelContext.safeSave()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    @ViewBuilder
    private func accountAvatar(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: human.themeColor).opacity(0.18))
                .frame(width: size, height: size)
            if let data = human.avatarImageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Text(human.avatarEmoji.isEmpty ? "👤" : human.avatarEmoji)
                    .font(.system(size: size * 0.45))
            }
        }
    }

    private func icon(for field: HumanPrivateField) -> String {
        switch field {
        case .weight: return "scalemass.fill"
        case .workout: return "figure.run"
        case .medication: return "pills.fill"
        case .wishlist: return "gift.fill"
        case .expense: return "creditcard.fill"
        case .note: return "note.text"
        }
    }

    private func displayName(_ human: Human) -> String {
        let name = human.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "未命名成员" : name
    }
}

struct HumanPasscodePad: View {
    @Binding var pin: String
    var accent: Color
    var onComplete: () -> Void

    private let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "delete"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 9) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index < pin.count ? accent : Color.primary.opacity(0.16))
                        .frame(width: 12, height: 12)
                        .animation(GoMotion.feedback, value: pin.count)
                }
            }
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(keys, id: \.self) { key in
                    if key.isEmpty {
                        Color.clear.frame(height: 46)
                    } else {
                        Button {
                            press(key)
                        } label: {
                            Group {
                                if key == "delete" {
                                    Image(systemName: "delete.left.fill")
                                        .font(.system(size: 17, weight: .black))
                                } else {
                                    Text(key)
                                        .font(.system(size: 22, weight: .black, design: .rounded))
                                }
                            }
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
        }
    }

    private func press(_ key: String) {
        if key == "delete" {
            if !pin.isEmpty { pin.removeLast() }
            return
        }
        guard pin.count < 4 else { return }
        pin.append(key)
        if pin.count == 4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                onComplete()
            }
        }
    }
}

struct HumanPrivacyTestView: View {
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @AppStorage("currentActiveHumanId") private var activeHumanId = ""

    @State private var viewerId = ""
    @State private var targetId = ""

    private var viewer: Human? {
        humans.first { $0.id.uuidString == viewerId }
    }

    private var target: Human? {
        humans.first { $0.id.uuidString == targetId }
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    summaryCard
                    pickerSection
                    matrixSection
                }
                .padding(16)
            }
        }
        .navigationTitle("隐私测试")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: ensureSelection)
        .onChange(of: humans.map(\.id)) { _, _ in ensureSelection() }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.goYellow)
                    .frame(width: 38, height: 38)
                    .background(Color.goYellow.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("人类隐私检查")
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text("只显示可见/锁定结果，不展示任何私密内容")
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 20)
    }

    private var pickerSection: some View {
        VStack(spacing: 12) {
            pickerRow(title: "查看者", selection: $viewerId)
            pickerRow(title: "目标成员", selection: $targetId)
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 20)
    }

    @ViewBuilder
    private var matrixSection: some View {
        if let target {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("字段矩阵")
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Spacer()
                    Text(viewer?.id == target.id ? "本人视角" : "他人视角")
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.goPrimary, in: Capsule())
                }

                visibleRow(title: "基础身份", subtitle: "名字、头像、角色、性别入口", isLocked: false)
                ForEach(HumanPrivateField.allCases) { field in
                    visibleRow(
                        title: field.title,
                        subtitle: target.privateFields.contains(field.rawValue) ? "目标成员设为仅本人" : "目标成员设为公开",
                        isLocked: PrivacyService.isLocked(field, for: target, viewedBy: viewer?.id)
                    )
                }
            }
            .padding(16)
            .goTranslucentCard(cornerRadius: 20)
        } else {
            Text("请先创建人类成员")
                .font(OhanaFont.callout(.bold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .frame(maxWidth: .infinity)
                .padding(20)
                .goTranslucentCard(cornerRadius: 20)
        }
    }

    private func pickerRow(title: String, selection: Binding<String>) -> some View {
        HStack {
            Text(title)
                .font(OhanaFont.callout(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
            Picker(title, selection: selection) {
                ForEach(humans) { human in
                    Text(displayName(human)).tag(human.id.uuidString)
                }
            }
            .pickerStyle(.menu)
            .tint(Color.goPrimary)
        }
    }

    private func visibleRow(title: String, subtitle: String, isLocked: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isLocked ? "lock.fill" : "eye.fill")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(isLocked ? Color.goYellow : Color.goPrimary)
                .frame(width: 32, height: 32)
                .background((isLocked ? Color.goYellow : Color.goPrimary).opacity(0.13), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(subtitle)
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            Text(isLocked ? "锁定" : "可见")
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(isLocked ? Color.goYellow : Color.arkInk)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(isLocked ? Color.goYellow.opacity(0.14) : Color.goPrimary, in: Capsule())
        }
        .padding(.vertical, 4)
    }

    private func ensureSelection() {
        guard !humans.isEmpty else { return }
        if viewerId.isEmpty || !humans.contains(where: { $0.id.uuidString == viewerId }) {
            viewerId = humans.first(where: { $0.id.uuidString == activeHumanId })?.id.uuidString ?? humans[0].id.uuidString
        }
        if targetId.isEmpty || !humans.contains(where: { $0.id.uuidString == targetId }) {
            targetId = humans.first(where: { $0.id.uuidString != viewerId })?.id.uuidString ?? humans[0].id.uuidString
        }
    }

    private func displayName(_ human: Human) -> String {
        let name = human.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "未命名成员" : name
    }
}
