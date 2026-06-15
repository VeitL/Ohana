//
//  CalendarView+Header.swift
//  Ohana
//

import SwiftData
import SwiftUI

extension CalendarView {
    // MARK: - Classic Calendar Header
    var embeddedCalendarHeader: some View {
        HStack(spacing: 10) {
            calendarHeaderTitle(fontSize: 19)

            Spacer(minLength: 8)

            HStack(spacing: 2) {
                iconModeBtn(systemName: "calendar", mode: .month)
                iconModeBtn(systemName: "list.bullet.rectangle.fill", mode: .list)
            }
            .padding(3)
            .background(Color.ohanaControlFill, in: Capsule())
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    var classicCalendarHeader: some View {
        let l = L10n(AppLanguage.code)
        return HStack(spacing: 12) {
            calendarHeaderTitle(fontSize: 20)

            Spacer()

            // 视图切换胶囊
            HStack(spacing: 2) {
                iconModeBtn(systemName: "calendar", mode: .month)
                iconModeBtn(systemName: "list.bullet.rectangle.fill", mode: .list)
            }
            .padding(3)
            .goGlassBackground(Capsule())

            // 添加事件按钮
            Button { requestAddEventPresentation() } label: {
                Label(l.tr(zh: "添加事件", en: "Add event", de: "Ereignis hinzufügen"), systemImage: "plus")
                    .labelStyle(.iconOnly)
                    .font(OhanaFont.headline(.bold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(width: 44, height: 44)
                    .background(Color.goPrimary, in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "添加事件", en: "Add event", de: "Ereignis hinzufügen"))
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    func calendarHeaderTitle(fontSize: CGFloat) -> some View {
        let l = L10n(AppLanguage.code)
        return Button {
            returnCalendarToToday()
        } label: {
            Text(calendarHeaderDate, format: .dateTime.year().month(.wide))
                .font(.system(size: fontSize, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(l.tr(zh: "返回今天", en: "Return to today", de: "Zu heute springen"))
        .accessibilityValue(calendarHeaderDate.formatted(.dateTime.year().month(.wide)))
    }

    // MARK: - Sticky Calendar Header (Material)
    var calStickyHeader: some View {
        let bg: Color = colorScheme == .light ? Color(hex: "F5F5F7") : Color(hex: "0A0A0C")
        let accent = Color(hex: "FF5A00")
        let l = L10n(AppLanguage.code)
        return HStack(spacing: 10) {
            // Add event
            Button { requestAddEventPresentation() } label: {
                Label(l.tr(zh: "添加事件", en: "Add event", de: "Ereignis hinzufügen"), systemImage: "calendar.badge.plus")
                    .labelStyle(.iconOnly)
                    .font(OhanaFont.title3(.semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(width: 44, height: 44)
                    .background(accent, in: Circle())
                    .shadow(color: accent.opacity(0.35), radius: 8, x: 0, y: 2) // ui-v4: allow legacy material calendar floating action depth
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "添加事件", en: "Add event", de: "Ereignis hinzufügen"))

            // View toggle pill
            HStack(spacing: 2) {
                iconModeBtn(systemName: "calendar", mode: .month)
                iconModeBtn(systemName: "list.bullet.rectangle.fill", mode: .list)
            }
            .padding(4)
            .goGlassBackground(Capsule())
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2) // ui-v4: allow legacy material calendar segmented depth

            Spacer()

            // Coconut count (rightmost, matches home)
            CoconutBalanceCapsule(balance: calendarCoconutBalance) {
                presentCoconutLog()
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(
            bg.opacity(0.92)
                .background(Color.ohanaCardSurface.opacity(0.88))
                .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - Go Week Strip (本周快速预览)
    var goWeekStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(thisWeekDays, id: \.self) { day in
                    let isToday = Calendar.current.isDateInToday(day)
                    let isSelected = Calendar.current.isDate(day, inSameDayAs: selectedDate)
                    let dayNumber = Calendar.current.component(.day, from: day)
                    let dayEvents = filteredEvents.filter {
                        eventOccursOnDate($0, date: day) &&
                            shouldShowEventOccurrence($0, occurrenceDate: day)
                    }
                    let hasEvents = !dayEvents.isEmpty
                    // 每个事件对应的宠物主题色（去重，最多3种）
                    let dotColors: [Color] = {
                        var seen: [String] = []
                        var colors: [Color] = []
                        for ev in dayEvents {
                            if let pet = MemberLifecycleActiveScheduleResolver.petTarget(for: ev, pets: pets) {
                                let hex = pet.themeColorHex
                                if !seen.contains(hex) {
                                    seen.append(hex)
                                    colors.append(Color(hex: hex))
                                }
                            } else if let plantId = DomainEntityLinkRegistry.plantId(for: ev),
                                let plant = plants.first(where: { $0.id == plantId }) {
                                let hex = plant.themeColorHex
                                if !seen.contains(hex) {
                                    seen.append(hex)
                                    colors.append(Color(hex: hex))
                                }
                            } else if !seen.contains("default") {
                                seen.append("default")
                                colors.append(chipAccent)
                            }
                            if colors.count >= 3 { break }
                        }
                        return colors
                    }()

                    Button {
                        withAnimation(GoMotion.feedback) { selectedDate = day }
                    } label: {
                        VStack(spacing: 5) {
                            Text(day, format: .dateTime.weekday(.abbreviated))
                                .font(OhanaFont.caption2(.bold))
                                .foregroundStyle(isSelected ? chipSelFg : (isMaterial ? Color(hex: "8E8E93") : classicSoftText))

                            Text("\(dayNumber)")
                                .font(OhanaFont.title3(.black))
                                .foregroundStyle(isSelected ? chipSelFg : (isToday ? chipAccent : (isMaterial ? .primary : classicPrimaryText)))
                                .ohanaNumericMotion(dayNumber)

                            // 事件点（宠物主题色，多宠物时最多3个彩点）
                            ZStack {
                                if hasEvents, !isSelected {
                                    HStack(spacing: 2) {
                                        ForEach(0 ..< dotColors.count, id: \.self) { i in
                                            Circle().fill(dotColors[i]).frame(width: 5, height: 5) // a11y: allow decorative event density dot
                                        }
                                    }
                                } else {
                                    Circle()
                                        .fill(hasEvents && isSelected ? chipSelFg.opacity(0.7) : Color.clear)
                                        .frame(width: 5, height: 5) // a11y: allow decorative event density dot
                                }
                            }

                            // 首个事件剪影图标
                            if let first = dayEvents.first {
                                Image(systemName: first.silhouetteListSymbol)
                                    .font(OhanaFont.caption(.bold))
                                    .symbolRenderingMode(.monochrome)
                                    .foregroundStyle(isSelected ? chipSelFg.opacity(0.9) : (isMaterial ? Color.primary.opacity(0.5) : classicPrimaryText.opacity(0.55)))
                            } else {
                                Color.clear.frame(height: 16)
                            }
                        }
                        .frame(width: 44)
                        .padding(.vertical, 8)
                        .background(
                            isSelected ? chipAccent : (isToday ? chipAccent.opacity(isMaterial ? 0.12 : 0.08) : Color.clear),
                            in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Go View Mode Toggle（图标版）
    var goViewModeToggle: some View {
        HStack(spacing: 2) {
            iconModeBtn(systemName: "calendar", mode: .month)
            iconModeBtn(systemName: "list.bullet.rectangle.fill", mode: .list)
        }
        .padding(3)
        .goGlassBackground(Capsule())
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    func iconModeBtn(systemName: String, mode: CalendarViewMode) -> some View {
        let unselectedTint: Color = {
            if isMaterial { return Color(hex: "8E8E93") }
            return Color.ohanaSecondaryText
        }()
        let l = L10n(AppLanguage.code)
        let label = mode == .month
            ? l.tr(zh: "月视图", en: "Month view", de: "Monatsansicht")
            : l.tr(zh: "列表视图", en: "List view", de: "Listenansicht")
        return Button {
            selectCalendarViewMode(mode)
        } label: {
            Label(label, systemImage: systemName)
                .labelStyle(.iconOnly)
                .font(OhanaFont.callout(.bold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(viewMode == mode ? chipSelFg : unselectedTint)
                .frame(width: 44, height: 44)
                .background { if viewMode == mode { Capsule().fill(chipAccent) } }
        }
        .buttonStyle(ScaleButtonStyle())
        .ohanaSelectionMotion(isSelected: viewMode == mode, scale: 1.018)
        .accessibilityLabel(label)
        .accessibilityValue(viewMode == mode
            ? l.tr(zh: "已选中", en: "Selected", de: "Ausgewählt")
            : l.tr(zh: "未选中", en: "Not selected", de: "Nicht ausgewählt"))
    }
}
