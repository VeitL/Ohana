//
//  PetMomentsHubView.swift
//  Ohana
//
//  V4 pet diary and photo hub.
//

import SwiftUI
import SwiftData
import PhotosUI

private enum PetMomentsTab: String, CaseIterable {
    case timeline
    case photos
}

private struct PetDiaryEntry: Identifiable {
    enum Kind {
        case moment
        case milestone
    }

    let id: String
    let kind: Kind
    let date: Date
    let title: String
    let subtitle: String
    let photos: [PetPhotoLog]
    let milestone: PetMilestone?

    var hasPhotos: Bool { !photos.isEmpty }
}

private enum PetGeneratedMomentCategory {
    case birthday
    case together
    case remembrance
}

struct PetMomentsHubView: View {
    let pet: Pet

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    @State private var tab: PetMomentsTab = .timeline
    @State private var photosPickerItems: [PhotosPickerItem] = []
    @State private var showingQuickMoment = false

    private var l: L10n { L10n(appLanguage) }
    private var themeColor: Color { Color(hex: pet.safeThemeColorHex) }
    private var diaryEntries: [PetDiaryEntry] { buildDiaryEntries() }

    private var realPhotos: [PetPhotoLog] {
        pet.photoLogs
            .filter { renderableImage(from: $0) != nil }
            .sorted { $0.date > $1.date }
    }

    private var textMomentCount: Int {
        pet.photoLogs.filter {
            renderableImage(from: $0) == nil &&
            !$0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
    }

    private var thisMonthStoryCount: Int {
        let cal = Calendar.current
        return diaryEntries.filter { cal.isDate($0.date, equalTo: Date(), toGranularity: .month) }.count
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                OhanaAppBackground().ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 16)
                        .padding(.top, 18)
                        .padding(.bottom, 12)

                    overview
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)

                    tabSwitch
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)

                    if tab == .timeline {
                        timelineScroll
                    } else {
                        PetPhotoAlbumView(pet: pet, hubPickerSelection: $photosPickerItems)
                    }
                }
                .onChange(of: photosPickerItems) { _, newItems in
                    PetPhotoAlbumView.consumePickerItems(newItems, pet: pet, modelContext: modelContext)
                    photosPickerItems = []
                }

                activeAddButton
                    .padding(.trailing, 18)
                    .padding(.bottom, 24)
            }
            .toolbar(.hidden, for: .navigationBar)
            .overlay {
                if showingQuickMoment {
                    QuickMomentSheet(
                        pet: pet,
                        onRemove: nil,
                        onClose: {
                            showingQuickMoment = false
                        }
                    )
                    .ignoresSafeArea()
                    .zIndex(100)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            FeatureHubAvatar(
                imageData: pet.avatarImageData,
                emoji: pet.avatarEmoji,
                fallback: pet.speciesEmoji,
                tint: themeColor
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(zh: "记录中心", en: "Moments", de: "Momente"))
                    .font(OhanaFont.title2(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text("\(pet.name) · \(l.tr(zh: "时光和相册", en: "diary and photos", de: "Tagebuch und Fotos"))")
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private var overview: some View {
        HStack(spacing: 10) {
            metric(l.tr(zh: "故事", en: "Stories", de: "Storys"), "\(diaryEntries.count)")
            metric(l.tr(zh: "照片", en: "Photos", de: "Fotos"), "\(realPhotos.count)")
            metric(l.tr(zh: "本月", en: "This month", de: "Monat"), "\(thisMonthStoryCount)")
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
            Text(value)
                .font(OhanaFont.headline(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var tabSwitch: some View {
        HStack(spacing: 8) {
            tabButton(.timeline, title: l.tr(zh: "时光", en: "Diary", de: "Tagebuch"), icon: "sparkles")
            tabButton(.photos, title: l.tr(zh: "相册", en: "Album", de: "Album"), icon: "photo.on.rectangle")
        }
        .padding(5)
        .background(Color.ohanaControlFill, in: Capsule())
    }

    private func tabButton(_ target: PetMomentsTab, title: String, icon: String) -> some View {
        Button {
            withAnimation(GoMotion.feedback) { tab = target }
        } label: {
            Label(title, systemImage: icon)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(tab == target ? Color.arkInk : Color.ohanaSecondaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(tab == target ? Color.goPrimary : Color.clear, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var timelineScroll: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                if diaryEntries.isEmpty {
                    emptyState
                } else {
                    Text(l.tr(
                        zh: "只保留主动记录和重要成长事件",
                        en: "Only saved moments and meaningful milestones",
                        de: "Nur gespeicherte Momente und wichtige Meilensteine"
                    ))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .padding(.horizontal, 20)

                    ForEach(groupedEntries, id: \.day) { group in
                        diaryDaySection(title: group.title, entries: group.entries)
                    }
                }
            }
            .padding(.top, 2)
            .padding(.bottom, 110)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 38, weight: .black))
                .foregroundStyle(Color.goPrimary)
            Text(l.tr(zh: "还没有时光记录", en: "No moments yet", de: "Noch keine Momente"))
                .font(OhanaFont.title3(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(l.tr(
                zh: "写一句话、拍一张照片，慢慢就会变成 \(pet.name) 的故事。",
                en: "A line or a photo becomes \(pet.name)'s story over time.",
                de: "Ein Satz oder Foto wird mit der Zeit zu \(pet.name)s Geschichte."
            ))
            .font(OhanaFont.callout(.semibold))
            .foregroundStyle(Color.ohanaSecondaryText)
            .multilineTextAlignment(.center)
            Button { showingQuickMoment = true } label: {
                Text(l.tr(zh: "记录第一刻", en: "Add First Moment", de: "Ersten Moment speichern"))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 20)
                    .frame(height: 46)
                    .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 42)
        .padding(.horizontal, 20)
    }

    private var addMomentButton: some View {
        Button { showingQuickMoment = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .black))
                Text(l.tr(zh: "记录", en: "Add", de: "Speichern"))
                    .font(OhanaFont.callout(.black))
            }
            .foregroundStyle(Color.arkInk)
            .padding(.horizontal, 22)
            .frame(height: 54)
            .background(Color.goPrimary, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    @ViewBuilder
    private var activeAddButton: some View {
        if tab == .photos {
            PhotosPicker(selection: $photosPickerItems, maxSelectionCount: 12, matching: .images) {
                addButtonLabel(
                    icon: "plus",
                    title: l.tr(zh: "添加", en: "Add", de: "Hinzufügen")
                )
            }
            .buttonStyle(ScaleButtonStyle())
        } else {
            addMomentButton
        }
    }

    private func addButtonLabel(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .black))
            Text(title)
                .font(OhanaFont.callout(.black))
        }
        .foregroundStyle(Color.arkInk)
        .padding(.horizontal, 22)
        .frame(height: 54)
        .background(Color.goPrimary, in: Capsule())
    }

    private var groupedEntries: [(day: Date, title: String, entries: [PetDiaryEntry])] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: diaryEntries) { cal.startOfDay(for: $0.date) }
        return groups
            .map { day, entries in
                (day, friendlyDayTitle(day), entries.sorted { $0.date > $1.date })
            }
            .sorted { $0.day > $1.day }
    }

    private func diaryDaySection(title: String, entries: [PetDiaryEntry]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
                .padding(.horizontal, 20)
            ForEach(entries) { entry in
                diaryEntryCard(entry)
            }
        }
    }

    private func diaryEntryCard(_ entry: PetDiaryEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: entry.kind == .moment ? "sparkles" : "flag.checkered")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(entry.kind == .moment ? Color.goPrimary : themeColor)
                Text(entry.title)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                Spacer()
                Text(entry.date, format: .dateTime.hour().minute())
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            if entry.hasPhotos {
                photoCollage(entry.photos)
            } else if entry.kind == .milestone, let data = entry.milestone?.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 164)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            if !entry.subtitle.isEmpty {
                Text(entry.subtitle)
                    .font(OhanaFont.callout(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func photoCollage(_ photos: [PetPhotoLog]) -> some View {
        let validPhotos = photos.compactMap { renderableImage(from: $0) }
        if validPhotos.count == 1, let image = validPhotos.first {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 182)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else if !validPhotos.isEmpty {
            HStack(spacing: 6) {
                ForEach(Array(validPhotos.prefix(3).enumerated()), id: \.offset) { _, image in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    private func buildDiaryEntries() -> [PetDiaryEntry] {
        let photoEntries = groupedMomentLogs().map { group -> PetDiaryEntry in
            let first = group[0]
            let cleanNote = first.note.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = group.contains { renderableImage(from: $0) != nil }
                ? (group.count > 1 ? l.tr(zh: "\(group.count) 张照片", en: "\(group.count) photos", de: "\(group.count) Fotos") : l.tr(zh: "照片时刻", en: "Photo Moment", de: "Foto-Moment"))
                : l.tr(zh: "文字时刻", en: "Note Moment", de: "Notiz-Moment")
            return PetDiaryEntry(
                id: "moment-\(first.id.uuidString)",
                kind: .moment,
                date: first.date,
                title: title,
                subtitle: cleanNote,
                photos: group.filter { renderableImage(from: $0) != nil },
                milestone: nil
            )
        }

        let pastMilestones = pet.milestones.filter { isMomentVisibleDate($0.date) }
        let milestoneEntries = pastMilestones.map { milestone in
            PetDiaryEntry(
                id: "milestone-\(milestone.id.uuidString)",
                kind: .milestone,
                date: milestone.date,
                title: milestone.title.isEmpty ? "\(milestone.emoji) \(l.tr(zh: "重要时刻", en: "Milestone", de: "Meilenstein"))" : "\(milestone.emoji) \(milestone.title)",
                subtitle: milestone.notes,
                photos: [],
                milestone: milestone
            )
        }

        return (photoEntries + milestoneEntries + generatedMeaningfulMoments(existingMilestones: pastMilestones))
            .sorted { $0.date > $1.date }
    }

    private func groupedMomentLogs() -> [[PetPhotoLog]] {
        let sorted = pet.photoLogs
            .filter { $0.date <= Date() }
            .sorted { $0.date < $1.date }
        var groups: [[PetPhotoLog]] = []

        for log in sorted {
            guard let lastGroup = groups.indices.last,
                  let last = groups[lastGroup].last,
                  abs(log.date.timeIntervalSince(last.date)) < 2,
                  normalizedMomentKey(log) == normalizedMomentKey(last)
            else {
                groups.append([log])
                continue
            }
            groups[lastGroup].append(log)
        }

        return groups.sorted { ($0.first?.date ?? .distantPast) > ($1.first?.date ?? .distantPast) }
    }

    private func generatedMeaningfulMoments(existingMilestones: [PetMilestone]) -> [PetDiaryEntry] {
        var entries: [PetDiaryEntry] = []
        let cal = Calendar.current
        let now = Date()
        let today = cal.startOfDay(for: now)
        let lifeEnd = pet.passedAwayDate.map { min($0, now) } ?? now

        if let birthday = pet.birthday,
           let birthYear = cal.dateComponents([.year], from: birthday).year,
           let currentYear = cal.dateComponents([.year], from: today).year {
            let birthdayComponents = cal.dateComponents([.month, .day], from: birthday)
            for year in birthYear...currentYear {
                let age = year - birthYear
                guard age > 0 else { continue }
                var components = DateComponents()
                components.year = year
                components.month = birthdayComponents.month
                components.day = birthdayComponents.day
                guard let date = cal.date(from: components),
                      isMomentVisibleDate(date),
                      date <= lifeEnd,
                      !hasExistingMilestone(on: date, category: .birthday, in: existingMilestones)
                else { continue }
                entries.append(generatedEntry(
                    id: "birthday-\(year)",
                    date: date,
                    title: birthdayTitle(age: age),
                    subtitle: l.tr(
                        zh: "\(pet.name) 的生日",
                        en: "\(pet.name)'s birthday",
                        de: "\(pet.name)s Geburtstag"
                    ),
                    emoji: "🎂"
                ))
            }
        }

        if let homeDate = pet.homeDate {
            for days in togetherMilestoneDays {
                guard let date = cal.date(byAdding: .day, value: days, to: homeDate),
                      isMomentVisibleDate(date),
                      date <= lifeEnd,
                      !hasExistingMilestone(on: date, category: .together, in: existingMilestones)
                else { continue }
                entries.append(generatedEntry(
                    id: "together-\(days)",
                    date: date,
                    title: togetherTitle(days),
                    subtitle: l.tr(
                        zh: "从到家那天开始计算",
                        en: "Counted from the day \(pet.name) came home",
                        de: "Gezählt seit \(pet.name)s Einzug"
                    ),
                    emoji: days >= 1000 ? "🏆" : "🎉"
                ))
            }
        }

        if let passedAwayDate = pet.passedAwayDate, passedAwayDate <= now {
            for days in remembranceMilestoneDays {
                guard let date = cal.date(byAdding: .day, value: days, to: passedAwayDate),
                      isMomentVisibleDate(date),
                      !hasExistingMilestone(on: date, category: .remembrance, in: existingMilestones)
                else { continue }
                entries.append(generatedEntry(
                    id: "remembrance-\(days)",
                    date: date,
                    title: remembranceTitle(days),
                    subtitle: l.tr(
                        zh: "彩虹桥后的思念",
                        en: "Remembering after the rainbow bridge",
                        de: "Erinnerung nach der Regenbogenbrücke"
                    ),
                    emoji: "🌈"
                ))
            }
        }

        return entries
    }

    private var togetherMilestoneDays: [Int] {
        [100, 365, 500, 730, 1000, 1095, 1500, 1825, 2000, 2190, 2500, 3000]
    }

    private var remembranceMilestoneDays: [Int] {
        [30, 100, 365, 500, 730, 1000, 1095, 1500, 1825]
    }

    private func generatedEntry(id: String, date: Date, title: String, subtitle: String, emoji: String) -> PetDiaryEntry {
        PetDiaryEntry(
            id: "generated-\(id)",
            kind: .milestone,
            date: date,
            title: "\(emoji) \(title)",
            subtitle: subtitle,
            photos: [],
            milestone: nil
        )
    }

    private func isMomentVisibleDate(_ date: Date) -> Bool {
        Calendar.current.startOfDay(for: date) <= Calendar.current.startOfDay(for: Date())
    }

    private func hasExistingMilestone(
        on date: Date,
        category: PetGeneratedMomentCategory,
        in milestones: [PetMilestone]
    ) -> Bool {
        let cal = Calendar.current
        return milestones.contains { milestone in
            cal.isDate(milestone.date, inSameDayAs: date) &&
            milestoneCategory(for: milestone) == category
        }
    }

    private func milestoneCategory(for milestone: PetMilestone) -> PetGeneratedMomentCategory? {
        let text = "\(milestone.title) \(milestone.notes)".lowercased()
        if text.contains("生日") || text.contains("birthday") || text.contains("geburtstag") {
            return .birthday
        }
        if text.contains("思念") || text.contains("remember") || text.contains("erinner") || text.contains("rainbow") || text.contains("彩虹桥") {
            return .remembrance
        }
        if text.contains("共度") || text.contains("相伴") || text.contains("together") || text.contains("days") || text.contains("tage") || text.contains("纪念") {
            return .together
        }
        return nil
    }

    private func birthdayTitle(age: Int) -> String {
        l.tr(
            zh: age == 1 ? "一岁生日" : "\(age) 岁生日",
            en: age == 1 ? "First Birthday" : "\(age)th Birthday",
            de: age == 1 ? "Erster Geburtstag" : "\(age). Geburtstag"
        )
    }

    private func togetherTitle(_ days: Int) -> String {
        switch days {
        case 365:
            return l.tr(zh: "相伴一年", en: "One Year Together", de: "Ein Jahr zusammen")
        case 730:
            return l.tr(zh: "相伴两年", en: "Two Years Together", de: "Zwei Jahre zusammen")
        case 1095:
            return l.tr(zh: "相伴三年", en: "Three Years Together", de: "Drei Jahre zusammen")
        case 1825:
            return l.tr(zh: "相伴五年", en: "Five Years Together", de: "Fünf Jahre zusammen")
        default:
            return l.tr(zh: "共度 \(days) 天", en: "\(days) Days Together", de: "\(days) Tage zusammen")
        }
    }

    private func remembranceTitle(_ days: Int) -> String {
        switch days {
        case 365:
            return l.tr(zh: "思念一年", en: "One Year Remembered", de: "Ein Jahr Erinnerung")
        case 730:
            return l.tr(zh: "思念两年", en: "Two Years Remembered", de: "Zwei Jahre Erinnerung")
        case 1095:
            return l.tr(zh: "思念三年", en: "Three Years Remembered", de: "Drei Jahre Erinnerung")
        case 1825:
            return l.tr(zh: "思念五年", en: "Five Years Remembered", de: "Fünf Jahre Erinnerung")
        default:
            return l.tr(zh: "思念 \(days) 天", en: "\(days) Days Remembered", de: "\(days) Tage Erinnerung")
        }
    }

    private func normalizedMomentKey(_ log: PetPhotoLog) -> String {
        [
            log.note.trimmingCharacters(in: .whitespacesAndNewlines),
            log.locationPlacename.trimmingCharacters(in: .whitespacesAndNewlines)
        ].joined(separator: "|")
    }

    private func renderableImage(from log: PetPhotoLog) -> UIImage? {
        guard let image = UIImage(data: log.imageData),
              image.size.width > 2,
              image.size.height > 2
        else { return nil }
        return image
    }

    private func friendlyDayTitle(_ day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return l.tr(zh: "今天", en: "Today", de: "Heute") }
        if cal.isDateInYesterday(day) { return l.tr(zh: "昨天", en: "Yesterday", de: "Gestern") }
        return day.formatted(date: .abbreviated, time: .omitted)
    }
}
