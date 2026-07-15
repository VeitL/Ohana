//
//  PetPersonalityTag.swift
//  Ohana
//
//  添加宠物可选「性格标签」，最多 3 个；用于问候语与轻量互动反馈。
//

import Foundation

// MARK: - 用户自定义标签（存 UserDefaults，id 前缀 u.）

nonisolated struct CustomPersonalityTagRecord: Codable, Identifiable, Equatable {
    let id: String
    var titleZh: String
    var titleEn: String

    func title(isEnglish: Bool) -> String { isEnglish ? titleEn : titleZh }
    func title(l: L10n) -> String { l.tr(zh: titleZh, en: titleEn, de: titleEn) }
}

nonisolated enum CustomPersonalityTagPreferenceStore {
    private static let key = "ohana_custom_personality_tags_v1"
    private static let defaults = UserDefaults.standard

    static func load() -> [CustomPersonalityTagRecord] {
        guard let data = defaults.string(forKey: key)?.data(using: .utf8),
              let arr = try? JSONDecoder().decode([CustomPersonalityTagRecord].self, from: data) else {
            return []
        }
        return arr
    }
}

nonisolated enum CustomPersonalityTagStore {
    static func load() -> [CustomPersonalityTagRecord] {
        CustomPersonalityTagPreferenceStore.load()
    }

    static func title(forId id: String, isEnglish: Bool) -> String? {
        load().first { $0.id == id }.map { $0.title(isEnglish: isEnglish) }
    }

    static func title(forId id: String, l: L10n) -> String? {
        load().first { $0.id == id }.map { $0.title(l: l) }
    }
}

// MARK: - Tag 目录（稳定 id 存入 Pet.personalityTagsRaw）

nonisolated struct PetPersonalityTag: Identifiable, Hashable {
    let id: String
    /// 日历 / 添加页统一用 SF Symbol 纯色剪影
    let sfSymbol: String
    let titleZh: String
    let titleEn: String
    let titleDe: String

    func title(isEnglish: Bool) -> String { isEnglish ? titleEn : titleZh }
    func title(l: L10n) -> String { l.tr(zh: titleZh, en: titleEn, de: titleDe) }

    init(id: String, sfSymbol: String, titleZh: String, titleEn: String, titleDe: String? = nil) {
        self.id = id
        self.sfSymbol = sfSymbol
        self.titleZh = titleZh
        self.titleEn = titleEn
        self.titleDe = titleDe ?? titleEn
    }

    static let allTags: [PetPersonalityTag] = [
        .init(id: "curious", sfSymbol: "magnifyingglass", titleZh: "好奇宝宝", titleEn: "Curious soul", titleDe: "Neugierig"),
        .init(id: "lazy", sfSymbol: "bed.double.fill", titleZh: "小懒猪", titleEn: "Couch potato", titleDe: "Sofamodus"),
        .init(id: "energetic", sfSymbol: "bolt.fill", titleZh: "精力充沛", titleEn: "Lightning mode", titleDe: "Blitzmodus"),
        .init(id: "clingy", sfSymbol: "figure.2.and.child.holdinghands", titleZh: "黏人精", titleEn: "Velcro baby", titleDe: "Klebeherz"),
        .init(id: "smart", sfSymbol: "lightbulb.fill", titleZh: "聪明蛋", titleEn: "Little genius", titleDe: "Köpfchen"),
        .init(id: "toy", sfSymbol: "gamecontroller.fill", titleZh: "玩具控", titleEn: "Toy boss", titleDe: "Spielzeugboss"),
        .init(id: "foodie", sfSymbol: "fork.knife", titleZh: "干饭王", titleEn: "Food critic", titleDe: "Feinschmecker"),
        .init(id: "drama", sfSymbol: "theatermasks.fill", titleZh: "戏精", titleEn: "Drama star", titleDe: "Drama-Star"),
        .init(id: "clean", sfSymbol: "sparkles", titleZh: "洁癖星人", titleEn: "Clean freak", titleDe: "Putzprofi"),
        .init(id: "shy", sfSymbol: "eye.slash.fill", titleZh: "胆小鬼", titleEn: "Shy bean", titleDe: "Schüchtern"),
        .init(id: "brave", sfSymbol: "shield.fill", titleZh: "勇敢崽", titleEn: "Brave heart", titleDe: "Mutig"),
        .init(id: "sleepy", sfSymbol: "moon.zzz.fill", titleZh: "睡神", titleEn: "Sleep CEO", titleDe: "Schlafprofi"),
        .init(id: "social", sfSymbol: "person.3.fill", titleZh: "社交达人", titleEn: "Party animal", titleDe: "Partymodus"),
        .init(id: "gentle", sfSymbol: "heart.fill", titleZh: "温柔派", titleEn: "Gentle soul", titleDe: "Sanft"),
        .init(id: "playful", sfSymbol: "figure.play", titleZh: "贪玩鬼", titleEn: "Play machine", titleDe: "Spielkind"),
        .init(id: "quiet", sfSymbol: "speaker.slash.fill", titleZh: "安静派", titleEn: "Quiet type", titleDe: "Leise"),
        .init(id: "stubborn", sfSymbol: "arrow.triangle.2.circlepath", titleZh: "倔脾气", titleEn: "Stubborn star", titleDe: "Sturkopf"),
        .init(id: "vocal", sfSymbol: "waveform", titleZh: "话痨", titleEn: "Chatterbox", titleDe: "Plaudertasche"),
        .init(id: "greedy", sfSymbol: "takeoutbag.and.cup.and.straw.fill", titleZh: "小吃货", titleEn: "Snack fan", titleDe: "Snackfan"),
        .init(id: "guardian", sfSymbol: "lock.shield.fill", titleZh: "护主", titleEn: "Guard mode", titleDe: "Beschützer"),
        .init(id: "independent", sfSymbol: "figure.stand", titleZh: "独立派", titleEn: "Solo artist", titleDe: "Solo-Typ"),
        .init(id: "trainable", sfSymbol: "graduationcap.fill", titleZh: "好训练", titleEn: "Quick learner", titleDe: "Lernt schnell"),
        .init(id: "anxious", sfSymbol: "exclamationmark.triangle.fill", titleZh: "小紧张", titleEn: "Nervous bean", titleDe: "Etwas nervös"),
        .init(id: "mischief", sfSymbol: "flame.fill", titleZh: "捣蛋王", titleEn: "Chaos agent", titleDe: "Unsinnsprofi"),
        .init(id: "loyal", sfSymbol: "star.fill", titleZh: "忠诚", titleEn: "Loyal buddy", titleDe: "Treu"),
        .init(id: "chill", sfSymbol: "leaf.fill", titleZh: "佛系", titleEn: "Chill vibes", titleDe: "Ganz entspannt"),
        .init(id: "snuggler", sfSymbol: "figure.hugging", titleZh: "抱抱怪", titleEn: "Cuddle bug", titleDe: "Kuschelprofi"),
        .init(id: "moody", sfSymbol: "cloud.bolt.fill", titleZh: "情绪派", titleEn: "Mood swing", titleDe: "Launenwelle"),
        .init(id: "spoiled", sfSymbol: "crown.fill", titleZh: "被宠坏了", titleEn: "Spoiled rotten", titleDe: "Sehr verwöhnt"),
        .init(id: "detective", sfSymbol: "eye.fill", titleZh: "侦探气质", titleEn: "Little detective", titleDe: "Detektivblick"),
        .init(id: "photogenic", sfSymbol: "camera.fill", titleZh: "天生模特", titleEn: "Born model", titleDe: "Fotostar"),
        .init(id: "nightowl", sfSymbol: "moon.stars.fill", titleZh: "夜猫子", titleEn: "Night owl", titleDe: "Nachtmodus"),
        .init(id: "sunny", sfSymbol: "sun.max.fill", titleZh: "阳光系", titleEn: "Sunshine mode", titleDe: "Sonnig"),
        .init(id: "collector", sfSymbol: "archivebox.fill", titleZh: "收藏家", titleEn: "Collector", titleDe: "Sammler"),
        .init(id: "escape_artist", sfSymbol: "figure.run", titleZh: "逃跑艺术家", titleEn: "Escape artist", titleDe: "Ausbruchskünstler"),
        .init(id: "zen", sfSymbol: "figure.mind.and.body", titleZh: "禅宗派", titleEn: "Zen master", titleDe: "Zen-Modus"),
        .init(id: "jealous", sfSymbol: "eyes", titleZh: "超吃醋", titleEn: "Jelly bean", titleDe: "Eifersüchtig"),
        .init(id: "foodthief", sfSymbol: "hand.raised.fill", titleZh: "偷食小贼", titleEn: "Food bandit", titleDe: "Futterdieb"),
        .init(id: "chatty", sfSymbol: "bubble.left.fill", titleZh: "碎碎念", titleEn: "Chatty", titleDe: "Plaudrig")
    ]

    /// 现有宠物编辑页继续使用的精简目录。
    static let primaryChoices = Array(allTags.prefix(8))

    /// 创建流专用的精简目录。编辑页继续使用 `primaryChoices`，
    /// 避免首次创建的信息架构调整扩散到已有档案编辑。
    static let creationChoices: [PetPersonalityTag] = {
        let ids = [
            "curious", "lazy", "energetic", "clingy", "smart",
            "toy", "foodie", "drama", "clean", "shy",
            "brave", "social", "gentle", "quiet", "stubborn",
            "vocal", "guardian", "independent", "loyal", "chill"
        ]
        return ids.compactMap(lookup)
    }()

    static func lookup(_ id: String) -> PetPersonalityTag? {
        allTags.first { $0.id == id }
    }

    static func displayTitle(for id: String, isEnglish: Bool) -> String {
        if let t = lookup(id) { return t.title(isEnglish: isEnglish) }
        if id.hasPrefix("u."), let c = CustomPersonalityTagStore.title(forId: id, isEnglish: isEnglish) { return c }
        return isEnglish ? "Tag" : "标签"
    }

    static func displayTitle(for id: String, l: L10n) -> String {
        if let t = lookup(id) { return t.title(l: l) }
        if id.hasPrefix("u."), let c = CustomPersonalityTagStore.title(forId: id, l: l) { return c }
        return l.tr(zh: "标签", en: "Tag", de: "Tag")
    }

    static func symbolName(for id: String) -> String {
        if let t = lookup(id) { return t.sfSymbol }
        if id.hasPrefix("u.") { return "tag.fill" }
        return "sparkles"
    }
}

// MARK: - 首页副标题问候（结合时段 + 标签）

nonisolated enum PetTagGreeting {
    /// 稳定轮换：同一天同一时段内文案不变，避免闪烁
    static func homeSubtitleHint(pet: Pet, hour: Int, l: L10n) -> String {
        let ids = pet.personalityTagIdList
        guard !ids.isEmpty else {
            return defaultTimeHint(name: pet.name, hour: hour, l: l)
        }

        let day = Calendar.current.component(.day, from: Date())
        let month = Calendar.current.component(.month, from: Date())
        var pool: [String] = []
        for tid in ids {
            pool.append(contentsOf: lines(for: tid, name: pet.name, hour: hour, l: l))
        }
        pool.append(defaultTimeHint(name: pet.name, hour: hour, l: l))
        let idx = stableIndex(seed: "\(pet.id.uuidString)-\(day)-\(month)-\(hour)", count: pool.count)
        return pool[idx]
    }

    private static func defaultTimeHint(name: String, hour: Int, l: L10n) -> String {
        if hour >= 6, hour < 10 { return l.morningHint(name) }
        if hour >= 17, hour < 20 { return l.eveningHint(name) }
        return l.defaultHint(name)
    }

    private static func stableIndex(seed: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        var h = 0
        for u in seed.unicodeScalars {
            h = 31 &* h &+ Int(u.value)
        }
        return abs(h) % count
    }

    private static func customLines(tagId: String, name: String, l: L10n) -> [String] {
        guard tagId.hasPrefix("u."),
              let label = CustomPersonalityTagStore.title(forId: tagId, l: l) else { return [] }
        return [
            l.tr(
                zh: "\(name) 的「\(label)」属性今天也在线。",
                en: "\(name)’s “\(label)” energy is showing.",
                de: "\(name) zeigt heute \(label)-Energie."
            ),
            l.tr(
                zh: "一眼认出 \(name) 的 \(label) 气质。",
                en: "Today’s headline: \(name) in full \(label) mode.",
                de: "Heute im Programm: \(name) im \(label)-Modus."
            )
        ]
    }

    private static func lines(for tagId: String, name: String, hour _: Int, l: L10n) -> [String] {
        let custom = customLines(tagId: tagId, name: name, l: l)
        if !custom.isEmpty { return custom }

        switch tagId {
        case "curious":
            return tagLines(name: name, tagId: tagId, l: l, zh: "\(name) 是不是又在门口当侦察兵啦？", en: "Is \(name) already doing recon at the door?", zh2: "好奇宝宝 \(name) 今天又想破解什么新地图？", en2: "\(name)’s curiosity budget is unlimited today.")
        case "lazy":
            return tagLines(name: name, tagId: tagId, l: l, zh: "\(name) 表示：被窝以外，皆是远方。", en: "\(name) declares: the blanket is the final boss.", zh2: "小懒猪 \(name) 正在和被窝谈判续费。", en2: "Maybe \(name) will move… tomorrow.")
        case "energetic":
            return tagLines(name: name, tagId: tagId, l: l, zh: "\(name) 电量满格，今天要不要一起放放电？", en: "\(name) is at 120% battery — discharge mission?", zh2: "闪电侠 \(name) 已就位，沙发危险。", en2: "Walk \(name) before \(name) walks you.")
        case "clingy":
            return tagLines(name: name, tagId: tagId, l: l, zh: "黏人精 \(name) 的雷达已锁定你。", en: "\(name) has you on full radar lock.", zh2: "\(name)：你走一步，我跟三步，很合理吧？", en2: "Human detected. \(name) is incoming.")
        case "smart":
            return tagLines(name: name, tagId: tagId, l: l, zh: "聪明蛋 \(name) 又在装无辜，其实都懂对吧？", en: "\(name) is pretending to be innocent again.", zh2: "\(name) 的眼神写着「我早就知道了」。", en2: "\(name) probably understands every word.")
        case "toy":
            return tagLines(name: name, tagId: tagId, l: l, zh: "玩具控 \(name) 提醒你：鞋带也属于玩具范畴。", en: "Shoelaces count as toys, says \(name).", zh2: "\(name) 的巡回赛决赛现在开始。", en2: "\(name) demands a play audit.")
        case "foodie":
            return tagLines(name: name, tagId: tagId, l: l, zh: "干饭王 \(name) 的尾巴已经敲成架子鼓了。", en: "\(name)’s tail is drumming for snacks.", zh2: "\(name) 觉得今天的碗，还可以再满一点。", en2: "The food bowl is \(name)’s favorite TV channel.")
        case "drama":
            return tagLines(name: name, tagId: tagId, l: l, zh: "戏精 \(name) 今日戏份还满吗？需要导演吗？", en: "\(name)’s daily Oscar scene is live.", zh2: "\(name) 一个叹气能演三集连续剧。", en2: "One sigh from \(name) = full storyline.")
        case "clean":
            return tagLines(name: name, tagId: tagId, l: l, zh: "洁癖星人 \(name)：地上多一根毛都是大事。", en: "\(name) finds one hair on the floor: code red.", zh2: "\(name) 正在默默给地板打分的路上。", en2: "\(name) runs a tight ship.")
        case "shy":
            return tagLines(name: name, tagId: tagId, l: l, zh: "胆小鬼 \(name) 需要轻声细语版早安。", en: "Gentle mode: \(name) needs a soft hello.", zh2: "\(name) 的勇敢是迷你款，但很珍贵。", en2: "\(name) is brave in tiny steps.")
        case "brave":
            return tagLines(name: name, tagId: tagId, l: l, zh: "勇敢崽 \(name) 出门像巡山，除了吸尘器。", en: "\(name) fears nothing (except the vacuum maybe).", zh2: "\(name)：危险？我先看看香不香。", en2: "Captain \(name) reporting for duty.")
        case "sleepy":
            return tagLines(name: name, tagId: tagId, l: l, zh: "睡神 \(name) 正在梦里拯救世界。", en: "\(name) is saving the world… in dreams.", zh2: "\(name) 的 KPI 是睡满十二个太阳。", en2: "Nap equity: \(name) is fully vested.")
        case "social":
            return tagLines(name: name, tagId: tagId, l: l, zh: "社交达人 \(name) 想跟全岛打个招呼。", en: "\(name) wants to say hi to the whole island.", zh2: "有客人？\(name) 已经切换到接待模式。", en2: "\(name) treats every guest like VIP.")
        case "gentle":
            return tagLines(name: name, tagId: tagId, l: l, zh: "温柔派 \(name) 今天也想被轻声对待。", en: "Soft paws, soft heart: that’s \(name).", zh2: "\(name) 的温柔是慢热型宝藏。", en2: "\(name) prefers kindness over chaos.")
        case "playful":
            return tagLines(name: name, tagId: tagId, l: l, zh: "贪玩鬼 \(name) 正在测试重力定律。", en: "\(name) is live-testing gravity again.", zh2: "球一滚，\(name) 的雷达就响了。", en2: "Play session? \(name) already voted yes.")
        case "quiet":
            return tagLines(name: name, tagId: tagId, l: l, zh: "安静派 \(name) 用眼神完成全部社交。", en: "\(name) speaks in tiny signals today.", zh2: "\(name) 的话少，但戏份不少。", en2: "Low volume, high charm — hi \(name).")
        case "stubborn":
            return tagLines(name: name, tagId: tagId, l: l, zh: "倔脾气 \(name) 有自己的时间表。", en: "\(name) has opinions. Strong ones.", zh2: "说服 \(name)？那是长期项目。", en2: "Negotiation table: \(name) is chairperson.")
        case "vocal":
            return tagLines(name: name, tagId: tagId, l: l, zh: "话痨 \(name) 的点评永不缺席。", en: "\(name) has notes. Many notes.", zh2: "\(name) 一开口，全家都知道剧情更新了。", en2: "If silence is gold, \(name) is investing elsewhere.")
        case "greedy":
            return tagLines(name: name, tagId: tagId, l: l, zh: "小吃货 \(name) 对零食数学特别敏感。", en: "Snack math is \(name)’s favorite subject.", zh2: "开袋声一响，\(name) 已抵达现场。", en2: "The treat jar blinked. \(name) noticed.")
        case "guardian":
            return tagLines(name: name, tagId: tagId, l: l, zh: "护主模式 \(name) 已上线。", en: "\(name) is on perimeter watch.", zh2: "有动静？\(name) 比你先进入警戒。", en2: "Stranger danger? \(name) filed the report.")
        case "independent":
            return tagLines(name: name, tagId: tagId, l: l, zh: "独立派 \(name) 偶尔也想自己待会儿。", en: "\(name) enjoys solo missions sometimes.", zh2: "\(name)：我需要 me time，谢谢。", en2: "Independent \(name), still checks in.")
        case "trainable":
            return tagLines(name: name, tagId: tagId, l: l, zh: "好训练 \(name) 一学就会（在有零食的前提下）。", en: "\(name) learns fast when treats are involved.", zh2: "\(name) 今天也想拿满分小红花。", en2: "Training day? \(name) brought focus.")
        case "anxious":
            return tagLines(name: name, tagId: tagId, l: l, zh: "小紧张 \(name) 今天需要温柔节奏。", en: "Gentle energy for \(name) today.", zh2: "轻声一点，\(name) 会更安心。", en2: "\(name) might need a calm rhythm.")
        case "mischief":
            return tagLines(name: name, tagId: tagId, l: l, zh: "捣蛋王 \(name) 又在策划可爱犯罪。", en: "\(name) is plotting something adorable.", zh2: "案发现场总有 \(name) 的爪印。", en2: "Evidence suggests \(name) touched the forbidden sock.")
        case "loyal":
            return tagLines(name: name, tagId: tagId, l: l, zh: "忠诚 \(name) 的跟随距离是零距离。", en: "\(name)’s loyalty stat is maxed.", zh2: "\(name) 的选择永远是你。", en2: "You + \(name) = default party.")
        case "chill":
            return tagLines(name: name, tagId: tagId, l: l, zh: "佛系 \(name) 表示：急什么。", en: "\(name) is running on cruise control.", zh2: "\(name) 的人生信条是慢慢来。", en2: "Slow morning? \(name) approves.")
        default:
            return l.isDe ? genericTagLines(name: name, tagId: tagId, l: l) : []
        }
    }

    private static func tagLines(
        name: String,
        tagId: String,
        l: L10n,
        zh: String,
        en: String,
        zh2: String,
        en2: String
    ) -> [String] {
        let generic = genericTagLines(name: name, tagId: tagId, l: l)
        return [
            l.tr(zh: zh, en: en, de: generic[0]),
            l.tr(zh: zh2, en: en2, de: generic[1])
        ]
    }

    private static func genericTagLines(name: String, tagId: String, l: L10n) -> [String] {
        let label = PetPersonalityTag.displayTitle(for: tagId, l: l)
        return [
            "\(name) ist heute ganz \(label).",
            "\(name)s \(label)-Modus ist an."
        ]
    }
}

// MARK: - 主性格编辑与照护反馈

nonisolated enum PetPrimaryPersonalitySelection {
    static func replacingPrimary(in existingIDs: [String], with newPrimaryID: String) -> [String] {
        let normalizedExisting = normalized(existingIDs)
        let primary = newPrimaryID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !primary.isEmpty else { return normalizedExisting }
        guard normalizedExisting.first != primary else { return normalizedExisting }

        let preservedSecondary = normalizedExisting
            .dropFirst()
            .filter { $0 != primary }
        return normalized([primary] + preservedSecondary)
    }

    static func normalized(_ ids: [String]) -> [String] {
        var seen: Set<String> = []
        return Array(
            ids
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && seen.insert($0).inserted }
                .prefix(3)
        )
    }
}

nonisolated enum PetPersonalityCareReaction {
    static func line(petName: String, primaryTagID: String?, l: L10n) -> String {
        let name = petName.isEmpty ? l.tr(zh: "小家伙", en: "Your pet", de: "Dein Tier") : petName
        switch primaryTagID {
        case "curious", "detective", "collector", "escape_artist":
            return l.tr(zh: "\(name) 已认真检查：这次照护合格。", en: "\(name) inspected everything: care approved.", de: "\(name) hat alles geprüft: Pflege genehmigt.")
        case "lazy", "sleepy", "chill", "zen":
            return l.tr(zh: "\(name) 舒服得决定再躺五分钟。", en: "\(name) is comfy enough for five more minutes of lounging.", de: "\(name) ist bequem genug für fünf Minuten mehr Pause.")
        case "energetic", "playful", "sunny":
            return l.tr(zh: "\(name) 电量回满，又准备出发了。", en: "\(name)'s battery is full and ready to go again.", de: "\(name)s Akku ist voll und bereit für die nächste Runde.")
        case "clingy", "snuggler", "loyal", "jealous":
            return l.tr(zh: "\(name) 贴过来确认：这次也算抱抱吧？", en: "\(name) leans in: this counts as a cuddle too, right?", de: "\(name) rückt näher: Das zählt auch als Kuscheln, oder?")
        case "smart", "trainable":
            return l.tr(zh: "\(name) 点点头：流程通过。", en: "\(name) gives a knowing nod: process approved.", de: "\(name) nickt wissend: Ablauf genehmigt.")
        case "toy", "mischief":
            return l.tr(zh: "\(name)：照护完成，现在轮到玩了吧？", en: "\(name): care done — playtime now?", de: "\(name): Pflege fertig — jetzt spielen?")
        case "foodie", "greedy", "foodthief":
            return l.tr(zh: "\(name)：做得不错，奖励在哪里？", en: "\(name): nicely done. Where is the reward?", de: "\(name): Gut gemacht. Wo ist die Belohnung?")
        case "drama", "vocal", "moody", "chatty":
            return l.tr(zh: "\(name) 已为这次照护献上完整谢幕。", en: "\(name) gives this care moment a full curtain call.", de: "\(name) gibt diesem Pflegemoment einen großen Schlussapplaus.")
        case "clean":
            return l.tr(zh: "\(name) 对这次清爽程度表示满意。", en: "\(name) approves the fresh-and-clean result.", de: "\(name) ist mit dem frischen Ergebnis zufrieden.")
        case "shy", "anxious", "gentle", "quiet":
            return l.tr(zh: "\(name) 悄悄给了你一个开心的小信号。", en: "\(name) sends you one tiny, happy signal.", de: "\(name) schickt dir ein kleines, glückliches Zeichen.")
        case "brave", "guardian", "independent", "stubborn":
            return l.tr(zh: "\(name) 很认真地点头：可以。", en: "\(name) gives one very serious nod: acceptable.", de: "\(name) nickt sehr ernst: akzeptiert.")
        case "social":
            return l.tr(zh: "\(name) 已经准备把照护成果告诉全家。", en: "\(name) is ready to announce the result to everyone.", de: "\(name) möchte das Ergebnis gleich allen erzählen.")
        case "spoiled":
            return l.tr(zh: "\(name) 完成验收：本次服务符合标准。", en: "\(name)'s inspection is complete: service meets expectations.", de: "\(name)s Abnahme ist fertig: Service entspricht den Erwartungen.")
        case "photogenic":
            return l.tr(zh: "\(name) 表示：照护后照片可以安排了。", en: "\(name) says the after-care photo can happen now.", de: "\(name) meint: Jetzt kann das Nachher-Foto kommen.")
        case "nightowl":
            return l.tr(zh: "\(name) 先收下照护，夸奖留到夜里再说。", en: "\(name) accepts the care and saves the compliments for later.", de: "\(name) nimmt die Pflege an und spart das Lob für später.")
        case let .some(tagID):
            let tag = PetPersonalityTag.displayTitle(for: tagID, l: l)
            return l.tr(zh: "\(name) 的「\(tag)」模式表示：收到。", en: "\(name)'s \(tag) side says: care accepted.", de: "\(name)s \(tag)-Seite sagt: Pflege angenommen.")
        case .none:
            return l.tr(zh: "\(name) 认真收下了这次照护。", en: "\(name) happily accepts this bit of care.", de: "\(name) nimmt diese Pflege gern an.")
        }
    }
}
