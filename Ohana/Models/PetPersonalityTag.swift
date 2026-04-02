//
//  PetPersonalityTag.swift
//  Ohana
//
//  添加宠物可选「性格标签」，最多 3 个；用于首页问候语趣味变体。
//

import Foundation

// MARK: - 用户自定义标签（存 UserDefaults，id 前缀 u.）

struct CustomPersonalityTagRecord: Codable, Identifiable, Equatable {
    let id: String
    var titleZh: String
    var titleEn: String

    func title(isEnglish: Bool) -> String { isEnglish ? titleEn : titleZh }
}

enum CustomPersonalityTagStore {
    private static let key = "ohana_custom_personality_tags_v1"

    static func load() -> [CustomPersonalityTagRecord] {
        guard let data = UserDefaults.standard.string(forKey: key)?.data(using: .utf8),
              let arr = try? JSONDecoder().decode([CustomPersonalityTagRecord].self, from: data) else {
            return []
        }
        return arr
    }

    static func title(forId id: String, isEnglish: Bool) -> String? {
        load().first { $0.id == id }.map { $0.title(isEnglish: isEnglish) }
    }
}

// MARK: - Tag 目录（稳定 id 存入 Pet.personalityTagsRaw）

struct PetPersonalityTag: Identifiable, Hashable {
    let id: String
    /// 日历 / 添加页统一用 SF Symbol 纯色剪影
    let sfSymbol: String
    let titleZh: String
    let titleEn: String

    func title(isEnglish: Bool) -> String { isEnglish ? titleEn : titleZh }

    static let allTags: [PetPersonalityTag] = [
        .init(id: "curious", sfSymbol: "magnifyingglass", titleZh: "好奇宝宝", titleEn: "Curious soul"),
        .init(id: "lazy", sfSymbol: "bed.double.fill", titleZh: "小懒猪", titleEn: "Couch potato"),
        .init(id: "energetic", sfSymbol: "bolt.fill", titleZh: "精力充沛", titleEn: "Lightning mode"),
        .init(id: "clingy", sfSymbol: "figure.2.and.child.holdinghands", titleZh: "黏人精", titleEn: "Velcro baby"),
        .init(id: "smart", sfSymbol: "lightbulb.fill", titleZh: "聪明蛋", titleEn: "Little genius"),
        .init(id: "toy", sfSymbol: "gamecontroller.fill", titleZh: "玩具控", titleEn: "Toy boss"),
        .init(id: "foodie", sfSymbol: "fork.knife", titleZh: "干饭王", titleEn: "Food critic"),
        .init(id: "drama", sfSymbol: "theatermasks.fill", titleZh: "戏精", titleEn: "Drama star"),
        .init(id: "clean", sfSymbol: "sparkles", titleZh: "洁癖星人", titleEn: "Clean freak"),
        .init(id: "shy", sfSymbol: "eye.slash.fill", titleZh: "胆小鬼", titleEn: "Shy bean"),
        .init(id: "brave", sfSymbol: "shield.fill", titleZh: "勇敢崽", titleEn: "Brave heart"),
        .init(id: "sleepy", sfSymbol: "moon.zzz.fill", titleZh: "睡神", titleEn: "Sleep CEO"),
        .init(id: "social", sfSymbol: "person.3.fill", titleZh: "社交达人", titleEn: "Party animal"),
        .init(id: "gentle", sfSymbol: "heart.fill", titleZh: "温柔派", titleEn: "Gentle soul"),
        .init(id: "playful", sfSymbol: "figure.play", titleZh: "贪玩鬼", titleEn: "Play machine"),
        .init(id: "quiet", sfSymbol: "speaker.slash.fill", titleZh: "安静派", titleEn: "Quiet type"),
        .init(id: "stubborn", sfSymbol: "arrow.triangle.2.circlepath", titleZh: "倔脾气", titleEn: "Stubborn star"),
        .init(id: "vocal", sfSymbol: "waveform", titleZh: "话痨", titleEn: "Chatterbox"),
        .init(id: "greedy", sfSymbol: "takeoutbag.and.cup.and.straw.fill", titleZh: "小吃货", titleEn: "Snack gremlin"),
        .init(id: "guardian", sfSymbol: "lock.shield.fill", titleZh: "护主", titleEn: "Guard mode"),
        .init(id: "independent", sfSymbol: "figure.stand", titleZh: "独立派", titleEn: "Solo artist"),
        .init(id: "trainable", sfSymbol: "graduationcap.fill", titleZh: "好训练", titleEn: "Quick learner"),
        .init(id: "anxious", sfSymbol: "exclamationmark.triangle.fill", titleZh: "小紧张", titleEn: "Nervous bean"),
        .init(id: "mischief", sfSymbol: "flame.fill", titleZh: "捣蛋王", titleEn: "Chaos agent"),
        .init(id: "loyal", sfSymbol: "star.fill", titleZh: "忠诚", titleEn: "Loyal buddy"),
        .init(id: "chill", sfSymbol: "leaf.fill", titleZh: "佛系", titleEn: "Chill vibes"),
        .init(id: "snuggler", sfSymbol: "figure.hugging", titleZh: "抱抱怪", titleEn: "Cuddle bug"),
        .init(id: "moody", sfSymbol: "cloud.bolt.fill", titleZh: "情绪派", titleEn: "Mood swing"),
        .init(id: "spoiled", sfSymbol: "crown.fill", titleZh: "被宠坏了", titleEn: "Spoiled rotten"),
        .init(id: "detective", sfSymbol: "eye.fill", titleZh: "侦探气质", titleEn: "Little detective"),
        .init(id: "photogenic", sfSymbol: "camera.fill", titleZh: "天生模特", titleEn: "Born model"),
        .init(id: "nightowl", sfSymbol: "moon.stars.fill", titleZh: "夜猫子", titleEn: "Night owl"),
        .init(id: "sunny", sfSymbol: "sun.max.fill", titleZh: "阳光系", titleEn: "Sunshine mode"),
        .init(id: "collector", sfSymbol: "archivebox.fill", titleZh: "收藏家", titleEn: "Hoarder"),
        .init(id: "escape_artist", sfSymbol: "figure.run", titleZh: "逃跑艺术家", titleEn: "Escape artist"),
        .init(id: "zen", sfSymbol: "figure.mind.and.body", titleZh: "禅宗派", titleEn: "Zen master"),
        .init(id: "jealous", sfSymbol: "eyes", titleZh: "超吃醋", titleEn: "Jelly bean"),
        .init(id: "foodthief", sfSymbol: "hand.raised.fill", titleZh: "偷食小贼", titleEn: "Food bandit"),
        .init(id: "chatty", sfSymbol: "bubble.left.fill", titleZh: "碎碎念", titleEn: "Chatty"),
    ]

    static func lookup(_ id: String) -> PetPersonalityTag? {
        allTags.first { $0.id == id }
    }

    static func displayTitle(for id: String, isEnglish: Bool) -> String {
        if let t = lookup(id) { return t.title(isEnglish: isEnglish) }
        if id.hasPrefix("u."), let c = CustomPersonalityTagStore.title(forId: id, isEnglish: isEnglish) { return c }
        return isEnglish ? "Tag" : "标签"
    }

    static func symbolName(for id: String) -> String {
        if let t = lookup(id) { return t.sfSymbol }
        if id.hasPrefix("u.") { return "tag.fill" }
        return "sparkles"
    }
}

// MARK: - 首页副标题问候（结合时段 + 标签）

enum PetTagGreeting {
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
        if hour >= 6 && hour < 10 { return l.morningHint(name) }
        if hour >= 17 && hour < 20 { return l.eveningHint(name) }
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
              let label = CustomPersonalityTagStore.title(forId: tagId, isEnglish: l.isEn) else { return [] }
        if l.isEn {
            return [
                "\(name)’s “\(label)” energy is showing.",
                "Today’s headline: \(name) in full \(label) mode."
            ]
        }
        return [
            "\(name) 的「\(label)」属性今天也在线。",
            "一眼认出 \(name) 的 \(label) 气质。"
        ]
    }

    private static func lines(for tagId: String, name: String, hour: Int, l: L10n) -> [String] {
        let custom = customLines(tagId: tagId, name: name, l: l)
        if !custom.isEmpty { return custom }

        if l.isEn {
            switch tagId {
            case "curious":
                return ["Is \(name) already doing recon at the door?", "\(name)’s curiosity budget is unlimited today."]
            case "lazy":
                return ["\(name) declares: the blanket is the final boss.", "Maybe \(name) will move… tomorrow."]
            case "energetic":
                return ["\(name) is at 120% battery — discharge mission?", "Walk \(name) before \(name) walks you."]
            case "clingy":
                return ["\(name) has you on full radar lock.", "Human detected. \(name) is incoming."]
            case "smart":
                return ["\(name) is pretending to be innocent again.", "\(name) probably understands every word."]
            case "toy":
                return ["Shoelaces count as toys, says \(name).", "\(name) demands a play audit."]
            case "foodie":
                return ["\(name)’s tail is drumming for snacks.", "The food bowl is \(name)’s favorite TV channel."]
            case "drama":
                return ["\(name)’s daily Oscar scene is live.", "One sigh from \(name) = full storyline."]
            case "clean":
                return ["\(name) finds one hair on the floor: code red.", "\(name) runs a tight ship."]
            case "shy":
                return ["Gentle mode: \(name) needs a soft hello.", "\(name) is brave in tiny steps."]
            case "brave":
                return ["\(name) fears nothing (except the vacuum maybe).", "Captain \(name) reporting for duty."]
            case "sleepy":
                return ["\(name) is saving the world… in dreams.", "Nap equity: \(name) is fully vested."]
            case "social":
                return ["\(name) wants to say hi to the whole island.", "\(name) treats every guest like VIP."]
            case "gentle":
                return ["Soft paws, soft heart: that’s \(name).", "\(name) prefers kindness over chaos."]
            case "playful":
                return ["\(name) is live-testing gravity again.", "Play session? \(name) already voted yes."]
            case "quiet":
                return ["\(name) speaks in tiny signals today.", "Low volume, high charm — hi \(name)."]
            case "stubborn":
                return ["\(name) has opinions. Strong ones.", "Negotiation table: \(name) is chairperson."]
            case "vocal":
                return ["\(name) has notes. Many notes.", "If silence is gold, \(name) is investing elsewhere."]
            case "greedy":
                return ["Snack math is \(name)’s favorite subject.", "The treat jar blinked. \(name) noticed."]
            case "guardian":
                return ["\(name) is on perimeter watch.", "Stranger danger? \(name) filed the report."]
            case "independent":
                return ["\(name) enjoys solo missions sometimes.", "Independent \(name), still checks in."]
            case "trainable":
                return ["\(name) learns fast when treats are involved.", "Training day? \(name) brought focus."]
            case "anxious":
                return ["Gentle energy for \(name) today.", "\(name) might need a calm rhythm."]
            case "mischief":
                return ["\(name) is plotting something adorable.", "Evidence suggests \(name) touched the forbidden sock."]
            case "loyal":
                return ["\(name)’s loyalty stat is maxed.", "You + \(name) = default party."]
            case "chill":
                return ["\(name) is running on cruise control.", "Slow morning? \(name) approves."]
            default:
                return []
            }
        }

        switch tagId {
        case "curious":
            return ["\(name) 是不是又在门口当侦察兵啦？", "好奇宝宝 \(name) 今天又想破解什么新地图？"]
        case "lazy":
            return ["\(name) 表示：被窝以外，皆是远方。", "小懒猪 \(name) 正在和被窝谈判续费。"]
        case "energetic":
            return ["\(name) 电量满格，今天要不要一起放放电？", "闪电侠 \(name) 已就位，沙发危险。"]
        case "clingy":
            return ["黏人精 \(name) 的雷达已锁定你。", "\(name)：你走一步，我跟三步，很合理吧？"]
        case "smart":
            return ["聪明蛋 \(name) 又在装无辜，其实都懂对吧？", "\(name) 的眼神写着「我早就知道了」。"]
        case "toy":
            return ["玩具控 \(name) 提醒你：鞋带也属于玩具范畴。", "\(name) 的巡回赛决赛现在开始。"]
        case "foodie":
            return ["干饭王 \(name) 的尾巴已经敲成架子鼓了。", "\(name) 觉得今天的碗，还可以再满一点。"]
        case "drama":
            return ["戏精 \(name) 今日戏份还满吗？需要导演吗？", "\(name) 一个叹气能演三集连续剧。"]
        case "clean":
            return ["洁癖星人 \(name)：地上多一根毛都是大事。", "\(name) 正在默默给地板打分的路上。"]
        case "shy":
            return ["胆小鬼 \(name) 需要轻声细语版早安。", "\(name) 的勇敢是迷你款，但很珍贵。"]
        case "brave":
            return ["勇敢崽 \(name) 出门像巡山，除了吸尘器。", "\(name)：危险？我先看看香不香。"]
        case "sleepy":
            return ["睡神 \(name) 正在梦里拯救世界。", "\(name) 的 KPI 是睡满十二个太阳。"]
        case "social":
            return ["社交达人 \(name) 想跟全岛打个招呼。", "有客人？\(name) 已经切换到接待模式。"]
        case "gentle":
            return ["温柔派 \(name) 今天也想被轻声对待。", "\(name) 的温柔是慢热型宝藏。"]
        case "playful":
            return ["贪玩鬼 \(name) 正在测试重力定律。", "球一滚，\(name) 的雷达就响了。"]
        case "quiet":
            return ["安静派 \(name) 用眼神完成全部社交。", "\(name) 的话少，但戏份不少。"]
        case "stubborn":
            return ["倔脾气 \(name) 有自己的时间表。", "说服 \(name)？那是长期项目。"]
        case "vocal":
            return ["话痨 \(name) 的点评永不缺席。", "\(name) 一开口，全家都知道剧情更新了。"]
        case "greedy":
            return ["小吃货 \(name) 对零食数学特别敏感。", "开袋声一响，\(name) 已抵达现场。"]
        case "guardian":
            return ["护主模式 \(name) 已上线。", "有动静？\(name) 比你先进入警戒。"]
        case "independent":
            return ["独立派 \(name) 偶尔也想自己待会儿。", "\(name)：我需要 me time，谢谢。"]
        case "trainable":
            return ["好训练 \(name) 一学就会（在有零食的前提下）。", "\(name) 今天也想拿满分小红花。"]
        case "anxious":
            return ["小紧张 \(name) 今天需要温柔节奏。", "轻声一点，\(name) 会更安心。"]
        case "mischief":
            return ["捣蛋王 \(name) 又在策划可爱犯罪。", "案发现场总有 \(name) 的爪印。"]
        case "loyal":
            return ["忠诚 \(name) 的跟随距离是零距离。", "\(name) 的选择永远是你。"]
        case "chill":
            return ["佛系 \(name) 表示：急什么。", "\(name) 的人生信条是慢慢来。"]
        default:
            return []
        }
    }
}
