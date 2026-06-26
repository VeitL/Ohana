//
//  PlantCatalogLocalization.swift
//  Ohana
//
//  Localized display text and favorite persistence for the plant catalog.
//

import Foundation

nonisolated enum PlantCatalogLocalization {
    static func commonName(id _: String, zh: String, latinName: String, aliases: [String]) -> String {
        let l = L10n.current
        let english = aliases.first(where: { !$0.containsChineseCharacters }) ?? latinName
        return l.tr(zh: zh, en: english, de: english)
    }

    static func text(_ zh: String) -> String {
        let l = L10n.current
        switch zh {
        case "简单":
            return l.tr(zh: "简单", en: "Easy", de: "Einfach")
        case "中等":
            return l.tr(zh: "中等", en: "Medium", de: "Mittel")
        case "进阶":
            return l.tr(zh: "进阶", en: "Advanced", de: "Fortgeschritten")
        case "表土 2-3 cm 变干后浇透":
            return l.tr(zh: zh, en: "Water thoroughly after the top 2-3 cm of soil dries", de: "Gründlich gießen, wenn die oberen 2-3 cm Erde trocken sind")
        case "表土 2-3 cm 变干后浇透，避免盆底积水":
            return l.tr(zh: zh, en: "Water thoroughly after the top 2-3 cm of soil dries; avoid water collecting at the pot bottom", de: "Gründlich gießen, wenn die oberen 2-3 cm Erde trocken sind; Staunässe am Topfboden vermeiden")
        case "上层土干后浇透，避免长期积水":
            return l.tr(zh: zh, en: "Water thoroughly after the upper soil dries; avoid standing water", de: "Gründlich gießen, wenn die obere Erde trocken ist; Staunässe vermeiden")
        case "保持轻微湿润，冬季减少":
            return l.tr(zh: zh, en: "Keep slightly moist; reduce in winter", de: "Leicht feucht halten; im Winter reduzieren")
        case "土壤完全干透后再浇":
            return l.tr(zh: zh, en: "Water only after soil fully dries", de: "Erst gießen, wenn die Erde vollständig trocken ist")
        case "表土明显变干后浇透，保持节奏稳定":
            return l.tr(zh: zh, en: "Water thoroughly after topsoil clearly dries; keep a steady rhythm", de: "Gründlich gießen, wenn die Oberfläche klar trocken ist; Rhythmus stabil halten")
        case "土壤大半干后再浇，弱光环境延长间隔":
            return l.tr(zh: zh, en: "Water after most soil dries; extend intervals in low light", de: "Gießen, wenn der Großteil der Erde trocken ist; bei wenig Licht Intervalle verlängern")
        case "保持微湿但不积水，避免完全干透":
            return l.tr(zh: zh, en: "Keep lightly moist without waterlogging; avoid full dry-out", de: "Leicht feucht halten ohne Staunässe; nicht völlig austrocknen lassen")
        case "保持轻微湿润，避免暴晒和彻底干透":
            return l.tr(zh: zh, en: "Keep slightly moist; avoid harsh sun and complete dry-out", de: "Leicht feucht halten; starke Sonne und völliges Austrocknen vermeiden")
        case "表土变干后浇透，避免长期积水":
            return l.tr(zh: zh, en: "Water thoroughly after topsoil dries; avoid long-term waterlogging", de: "Gründlich gießen, wenn die Oberfläche trocken ist; dauerhafte Staunässe vermeiden")
        case "介质大半干后再浇，耐短暂偏干":
            return l.tr(zh: zh, en: "Water after most medium dries; tolerates brief dryness", de: "Gießen, wenn das Substrat größtenteils trocken ist; verträgt kurze Trockenheit")
        case "保持轻微湿润，避免完全干透":
            return l.tr(zh: zh, en: "Keep slightly moist; avoid full dry-out", de: "Leicht feucht halten; nicht vollständig austrocknen lassen")
        case "表土明显变干后浇透，避免忽干忽湿":
            return l.tr(zh: zh, en: "Water thoroughly after topsoil clearly dries; avoid swings between too dry and too wet", de: "Gründlich gießen, wenn die Oberfläche deutlich trocken ist; starke Wechsel vermeiden")
        case "表土变干后浇透，花期避免长期缺水":
            return l.tr(zh: zh, en: "Water thoroughly after topsoil dries; avoid long dry spells during bloom", de: "Gründlich gießen, wenn die Oberfläche trocken ist; in der Blüte nicht lange austrocknen lassen")
        case "土壤完全干透后再浇透，冬季减少":
            return l.tr(zh: zh, en: "Water thoroughly after soil fully dries; reduce in winter", de: "Gründlich gießen, wenn die Erde völlig trocken ist; im Winter reduzieren")
        case "土壤完全干透后少量浇透，冬季大幅减少":
            return l.tr(zh: zh, en: "After soil fully dries, water sparingly but thoroughly; greatly reduce in winter", de: "Nach vollständigem Austrocknen sparsam, aber gründlich gießen; im Winter stark reduzieren")
        case "介质接近干透后浇透，避免叶心积水":
            return l.tr(zh: zh, en: "Water thoroughly when medium is almost dry; avoid water in the crown", de: "Gründlich gießen, wenn das Substrat fast trocken ist; Wasser im Herz vermeiden")
        case "光照充足时保持规律浇透，盆土表层变干后再浇":
            return l.tr(zh: zh, en: "In strong light, water thoroughly on a regular rhythm after topsoil dries", de: "Bei viel Licht regelmäßig gründlich gießen, wenn die Oberfläche trocken ist")
        case "保持叶杯或介质微湿，定期换水防止腐烂":
            return l.tr(zh: zh, en: "Keep the cup or medium slightly moist; change water regularly to prevent rot", de: "Blattrosette oder Substrat leicht feucht halten; Wasser regelmäßig wechseln gegen Fäulnis")
        case "普通室内湿度即可", "普通室内湿度":
            return l.tr(zh: zh, en: "Normal indoor humidity is fine", de: "Normale Raumluftfeuchte reicht")
        case "偏高湿度更佳":
            return l.tr(zh: zh, en: "Higher humidity is better", de: "Höhere Luftfeuchte ist besser")
        case "中高湿更佳":
            return l.tr(zh: zh, en: "Medium to high humidity is better", de: "Mittlere bis hohe Luftfeuchte ist besser")
        case "中高湿更佳但要通风":
            return l.tr(zh: zh, en: "Medium to high humidity is better, with airflow", de: "Mittlere bis hohe Luftfeuchte, aber mit Luftbewegung")
        case "普通到偏高湿度":
            return l.tr(zh: zh, en: "Normal to higher humidity", de: "Normale bis höhere Luftfeuchte")
        case "普通到中高湿度":
            return l.tr(zh: zh, en: "Normal to medium-high humidity", de: "Normale bis mittelhohe Luftfeuchte")
        case "耐普通偏干环境":
            return l.tr(zh: zh, en: "Tolerates normal to drier rooms", de: "Verträgt normale bis trockenere Räume")
        case "18-30 C", "16-30 C", "16-26 C", "18-28 C":
            return zh
        case "15-27 C":
            return zh
        case "18-29 C，避免冷风":
            return l.tr(zh: zh, en: "18-29 C; avoid cold drafts", de: "18-29 C; kalte Zugluft vermeiden")
        case "18-28 C，避免冷风和干热风":
            return l.tr(zh: zh, en: "18-28 C; avoid cold drafts and dry hot air", de: "18-28 C; kalte Zugluft und trockene Heizungsluft vermeiden")
        case "16-30 C，避免低温潮湿":
            return l.tr(zh: zh, en: "16-30 C; avoid cold, wet conditions", de: "16-30 C; kalte Nässe vermeiden")
        case "18-28 C，昼夜温差有利开花":
            return l.tr(zh: zh, en: "18-28 C; day-night temperature difference helps blooming", de: "18-28 C; Tag-Nacht-Unterschied fördert Blüte")
        case "疏松排水型通用土":
            return l.tr(zh: zh, en: "Loose, well-draining all-purpose mix", de: "Lockere, gut drainierende Universalerde")
        case "排水良好的通用土":
            return l.tr(zh: zh, en: "Well-draining all-purpose soil", de: "Gut drainierende Universalerde")
        case "粗颗粒、树皮和通用土混合":
            return l.tr(zh: zh, en: "Chunky mix of bark and all-purpose soil", de: "Grobe Mischung aus Rinde und Universalerde")
        case "多肉或仙人掌型排水土":
            return l.tr(zh: zh, en: "Succulent or cactus well-draining mix", de: "Gut drainierende Sukkulenten- oder Kakteenerde")
        case "排水良好的室内观叶土":
            return l.tr(zh: zh, en: "Well-draining indoor foliage mix", de: "Gut drainierende Erde für Grünpflanzen")
        case "保水但透气的观叶土":
            return l.tr(zh: zh, en: "Foliage soil that holds moisture but stays airy", de: "Feuchtespeichernde, aber luftige Grünpflanzenerde")
        case "细颗粒保水型通用土":
            return l.tr(zh: zh, en: "Fine all-purpose mix with good moisture retention", de: "Feinkörnige Universalerde mit guter Wasserspeicherung")
        case "排水良好的棕榈或观叶土":
            return l.tr(zh: zh, en: "Well-draining palm or foliage mix", de: "Gut drainierende Palm- oder Grünpflanzenerde")
        case "仙人掌或多肉型排水土":
            return l.tr(zh: zh, en: "Cactus or succulent well-draining mix", de: "Gut drainierende Kakteenen- oder Sukkulentenerde")
        case "兰花树皮、水苔或颗粒介质":
            return l.tr(zh: zh, en: "Orchid bark, sphagnum, or chunky medium", de: "Orchideenrinde, Sphagnum oder grobes Substrat")
        case "树皮、珍珠岩和通用土混合的疏松介质":
            return l.tr(zh: zh, en: "Loose mix of bark, perlite, and all-purpose soil", de: "Lockere Mischung aus Rinde, Perlit und Universalerde")
        case "树皮、珍珠岩和粗颗粒混合介质":
            return l.tr(zh: zh, en: "Chunky mix of bark and perlite", de: "Grobe Mischung aus Rinde und Perlit")
        case "保水但透气的蕨类或观叶土":
            return l.tr(zh: zh, en: "Moisture-retentive but airy fern or foliage mix", de: "Feuchtespeichernde, luftige Farn- oder Grünpflanzenerde")
        case "排水良好的观叶或木本植物土":
            return l.tr(zh: zh, en: "Well-draining foliage or woody-plant soil", de: "Gut drainierende Erde für Grün- oder Gehölzpflanzen")
        case "疏松排水型开花植物土":
            return l.tr(zh: zh, en: "Loose, well-draining flowering-plant soil", de: "Lockere, gut drainierende Blühpflanzenerde")
        case "排水良好的通用土或香草土":
            return l.tr(zh: zh, en: "Well-draining all-purpose or herb soil", de: "Gut drainierende Universal- oder Kräutererde")
        case "凤梨或兰花型疏松介质":
            return l.tr(zh: zh, en: "Loose bromeliad or orchid-style medium", de: "Lockeres Bromelien- oder Orchideensubstrat")
        case "生长期每 4-6 周薄肥":
            return l.tr(zh: zh, en: "Light fertilizer every 4-6 weeks in growth season", de: "In der Wachstumszeit alle 4-6 Wochen schwach düngen")
        case "春夏每月薄肥", "生长期每月薄肥":
            return l.tr(zh: zh, en: "Light monthly fertilizer in growth season", de: "In der Wachstumszeit monatlich schwach düngen")
        case "生长期每 6-8 周薄肥":
            return l.tr(zh: zh, en: "Light fertilizer every 6-8 weeks in growth season", de: "In der Wachstumszeit alle 6-8 Wochen schwach düngen")
        case "生长期每 4 周半量肥":
            return l.tr(zh: zh, en: "Half-strength fertilizer every 4 weeks in growth season", de: "In der Wachstumszeit alle 4 Wochen halbe Dosis")
        case "生长期每 4-6 周低浓度肥":
            return l.tr(zh: zh, en: "Low-strength fertilizer every 4-6 weeks in growth season", de: "In der Wachstumszeit alle 4-6 Wochen niedrig dosieren")
        case "生长期 6-8 周一次薄肥", "生长期 6-8 周一次低浓度肥":
            return l.tr(zh: zh, en: "Low-strength fertilizer every 6-8 weeks in growth season", de: "In der Wachstumszeit alle 6-8 Wochen niedrig dosieren")
        case "生长期每 2-4 周低浓度兰花肥":
            return l.tr(zh: zh, en: "Low-strength orchid fertilizer every 2-4 weeks in growth season", de: "In der Wachstumszeit alle 2-4 Wochen schwachen Orchideendünger")
        case "生长期或花期每 2-4 周薄肥", "生长期每 2-4 周薄肥":
            return l.tr(zh: zh, en: "Light fertilizer every 2-4 weeks in growth or bloom season", de: "In Wachstums- oder Blütezeit alle 2-4 Wochen schwach düngen")
        case "生长期每 6-8 周低浓度肥":
            return l.tr(zh: zh, en: "Low-strength fertilizer every 6-8 weeks in growth season", de: "In der Wachstumszeit alle 6-8 Wochen niedrig dosieren")
        case "带节茎插水培或土培":
            return l.tr(zh: zh, en: "Stem cuttings with nodes in water or soil", de: "Triebstecklinge mit Knoten in Wasser oder Erde")
        case "带气根和节位扦插":
            return l.tr(zh: zh, en: "Cuttings with aerial roots and nodes", de: "Stecklinge mit Luftwurzeln und Knoten")
        case "分株或小吊兰落地":
            return l.tr(zh: zh, en: "Division or plantlets", de: "Teilung oder Kindel")
        case "分株或叶插":
            return l.tr(zh: zh, en: "Division or leaf cuttings", de: "Teilung oder Blattstecklinge")
        case "枝条扦插":
            return l.tr(zh: zh, en: "Stem cuttings", de: "Triebstecklinge")
        case "分株或茎段扦插":
            return l.tr(zh: zh, en: "Division or stem cuttings", de: "Teilung oder Stammstecklinge")
        case "分株或带节点扦插":
            return l.tr(zh: zh, en: "Division or node cuttings", de: "Teilung oder Stecklinge mit Knoten")
        case "分株或枝条扦插":
            return l.tr(zh: zh, en: "Division or stem cuttings", de: "Teilung oder Triebstecklinge")
        case "枝条扦插或分株":
            return l.tr(zh: zh, en: "Stem cuttings or division", de: "Triebstecklinge oder Teilung")
        case "带节点茎插或分株":
            return l.tr(zh: zh, en: "Node stem cuttings or division", de: "Stammstecklinge mit Knoten oder Teilung")
        case "分株、叶插或枝条扦插":
            return l.tr(zh: zh, en: "Division, leaf cuttings, or stem cuttings", de: "Teilung, Blatt- oder Triebstecklinge")
        case "枝条扦插或压条":
            return l.tr(zh: zh, en: "Stem cuttings or air layering", de: "Triebstecklinge oder Abmoosen")
        case "分株、叶插或枝条扦插，依品种而定":
            return l.tr(zh: zh, en: "Division, leaf cuttings, or stem cuttings depending on variety", de: "Teilung, Blatt- oder Triebstecklinge je nach Sorte")
        case "叶插、枝插或分株":
            return l.tr(zh: zh, en: "Leaf cuttings, stem cuttings, or division", de: "Blattstecklinge, Triebstecklinge oder Teilung")
        case "枝条扦插、分株或播种":
            return l.tr(zh: zh, en: "Stem cuttings, division, or seed", de: "Triebstecklinge, Teilung oder Aussaat")
        case "多为分株或种子，家庭繁殖较慢":
            return l.tr(zh: zh, en: "Usually division or seed; slow at home", de: "Meist Teilung oder Samen; zu Hause langsam")
        case "枝条晾干伤口后扦插":
            return l.tr(zh: zh, en: "Let cut stems callus before planting", de: "Schnittstellen antrocknen lassen, dann stecken")
        case "分株或高芽繁殖":
            return l.tr(zh: zh, en: "Division or keiki propagation", de: "Teilung oder Kindel")
        case "分株或孢子，家庭以分株为主":
            return l.tr(zh: zh, en: "Division or spores; division is easier at home", de: "Teilung oder Sporen; zu Hause meist Teilung")
        case "母株开花后侧芽分株":
            return l.tr(zh: zh, en: "Divide pups after the mother plant blooms", de: "Kindel nach der Blüte der Mutterpflanze teilen")
        case "修剪过长藤蔓，促进分枝":
            return l.tr(zh: zh, en: "Trim long vines to encourage branching", de: "Lange Ranken schneiden, um Verzweigung zu fördern")
        case "剪除老叶和过长藤蔓":
            return l.tr(zh: zh, en: "Remove old leaves and overly long vines", de: "Alte Blätter und zu lange Ranken entfernen")
        case "剪除老叶和过密枝叶":
            return l.tr(zh: zh, en: "Remove old and crowded foliage", de: "Alte und zu dichte Blätter entfernen")
        case "剪除老叶和受损叶":
            return l.tr(zh: zh, en: "Remove old and damaged leaves", de: "Alte und beschädigte Blätter entfernen")
        case "剪除干尖和老叶":
            return l.tr(zh: zh, en: "Remove dry tips and old leaves", de: "Trockene Spitzen und alte Blätter entfernen")
        case "剪除受损老叶":
            return l.tr(zh: zh, en: "Remove damaged old leaves", de: "Beschädigte alte Blätter entfernen")
        case "修剪顶部促进分枝":
            return l.tr(zh: zh, en: "Tip-prune to encourage branching", de: "Spitzen schneiden, um Verzweigung zu fördern")
        case "剪除黄叶和受损叶片":
            return l.tr(zh: zh, en: "Remove yellow and damaged leaves", de: "Gelbe und beschädigte Blätter entfernen")
        case "剪除卷曲、焦边或老叶":
            return l.tr(zh: zh, en: "Remove curled, scorched, or old leaves", de: "Eingerollte, verbrannte oder alte Blätter entfernen")
        case "修剪过密枝叶保持通风":
            return l.tr(zh: zh, en: "Thin dense growth to keep airflow", de: "Dichten Wuchs auslichten für Luftzirkulation")
        case "修剪过密枝叶，保持树形":
            return l.tr(zh: zh, en: "Thin dense growth to keep the tree shape", de: "Dichten Wuchs auslichten, um die Baumform zu halten")
        case "修剪徒长枝和受损叶":
            return l.tr(zh: zh, en: "Trim leggy stems and damaged leaves", de: "Lange Triebe und beschädigte Blätter schneiden")
        case "只剪除完全枯黄叶片":
            return l.tr(zh: zh, en: "Only remove fully yellow or dry leaves", de: "Nur vollständig gelbe oder trockene Blätter entfernen")
        case "戴手套处理折断或过长枝条":
            return l.tr(zh: zh, en: "Wear gloves when handling broken or long stems", de: "Bei gebrochenen oder langen Trieben Handschuhe tragen")
        case "花后剪除枯萎花梗":
            return l.tr(zh: zh, en: "Cut spent flower spikes after blooming", de: "Verblühte Blütenstiele nach der Blüte schneiden")
        case "带节点枝条扦插":
            return l.tr(zh: zh, en: "Stem cuttings with nodes", de: "Triebstecklinge mit Knoten")
        case "保留花梗，只修剪枯枝和过长藤蔓":
            return l.tr(zh: zh, en: "Keep flower spurs; trim only dry stems and long vines", de: "Blütenansätze erhalten; nur trockene Triebe und lange Ranken schneiden")
        case "剪除枯黄羽叶保持通风":
            return l.tr(zh: zh, en: "Remove yellowing fronds to keep airflow", de: "Vergilbte Wedel entfernen für Luftzirkulation")
        case "修剪徒长枝和交叉枝，保持株形":
            return l.tr(zh: zh, en: "Trim leggy and crossing stems to keep shape", de: "Lange und kreuzende Triebe schneiden")
        case "摘除残花和黄叶，保持通风":
            return l.tr(zh: zh, en: "Remove spent flowers and yellow leaves; keep airflow", de: "Verblühtes und gelbe Blätter entfernen; luftig halten")
        case "剪除徒长、腐烂或干枯部分":
            return l.tr(zh: zh, en: "Remove leggy, rotten, or dry parts", de: "Lange, faulige oder trockene Teile entfernen")
        case "定期摘心或修剪，保持株形和通风":
            return l.tr(zh: zh, en: "Pinch or prune regularly to keep shape and airflow", de: "Regelmäßig pinzieren oder schneiden")
        case "剪除枯花和老化叶片":
            return l.tr(zh: zh, en: "Remove spent flowers and aging leaves", de: "Verblühtes und alte Blätter entfernen")
        case "黄叶常见于过浇、低温或光照突变":
            return l.tr(zh: zh, en: "Yellow leaves often come from overwatering, cold, or sudden light changes", de: "Gelbe Blätter entstehen oft durch Überwässerung, Kälte oder plötzliche Lichtwechsel")
        case "焦边多与干燥、盐分或直晒有关":
            return l.tr(zh: zh, en: "Brown edges often relate to dryness, salts, or direct sun", de: "Braune Ränder hängen oft mit Trockenheit, Salzen oder direkter Sonne zusammen")
        case "叶尖干枯常见于干燥、盐分或缺水", "叶尖焦枯常见于低湿、盐分或缺水":
            return l.tr(zh: zh, en: "Dry tips often come from low humidity, salts, or underwatering", de: "Trockene Spitzen kommen oft von niedriger Luftfeuchte, Salzen oder Wassermangel")
        case "根腐多由过浇或盆土不透气导致":
            return l.tr(zh: zh, en: "Root rot is often caused by overwatering or poorly aerated soil", de: "Wurzelfäule entsteht oft durch Überwässerung oder schlechte Belüftung")
        case "掉叶常见于搬动、冷风、过浇或光照变化":
            return l.tr(zh: zh, en: "Leaf drop often follows moves, cold drafts, overwatering, or light changes", de: "Blattfall folgt oft auf Umstellen, kalte Zugluft, Überwässerung oder Lichtwechsel")
        case "黄叶多与积水、低温或长期弱光有关":
            return l.tr(zh: zh, en: "Yellow leaves often relate to waterlogging, cold, or long-term low light", de: "Gelbe Blätter hängen oft mit Staunässe, Kälte oder dauerhaft wenig Licht zusammen")
        case "焦边常见于低湿、硬水、盐分或直晒":
            return l.tr(zh: zh, en: "Crispy edges often come from low humidity, hard water, salts, or direct sun", de: "Trockene Ränder kommen oft von niedriger Luftfeuchte, hartem Wasser, Salzen oder direkter Sonne")
        case "干枯常见于缺水、低湿或强光":
            return l.tr(zh: zh, en: "Drying often comes from underwatering, low humidity, or strong light", de: "Vertrocknen kommt oft von Wassermangel, niedriger Luftfeuchte oder starkem Licht")
        case "徒长多与光照不足有关，焦边多与干燥有关":
            return l.tr(zh: zh, en: "Legginess often means too little light; crispy edges often mean dryness", de: "Geilwuchs deutet oft auf wenig Licht; trockene Ränder auf Trockenheit")
        case "不开花常见于光照不足或频繁移动":
            return l.tr(zh: zh, en: "Lack of blooms often comes from low light or frequent moving", de: "Ausbleibende Blüte liegt oft an wenig Licht oder häufigem Umstellen")
        case "腐烂多由低温积水导致，徒长多与光照不足有关":
            return l.tr(zh: zh, en: "Rot often comes from cold wet soil; legginess often comes from low light", de: "Fäulnis kommt oft von kalter Nässe; Geilwuchs von wenig Licht")
        case "烂根常见于介质长期潮湿或通风不足":
            return l.tr(zh: zh, en: "Root rot often comes from constantly wet medium or poor airflow", de: "Wurzelfäule kommt oft von dauerhaft nassem Substrat oder schlechter Lüftung")
        case "徒长多与光照不足有关，黄叶多与过浇有关":
            return l.tr(zh: zh, en: "Legginess often means low light; yellow leaves often mean overwatering", de: "Geilwuchs deutet auf wenig Licht; gelbe Blätter oft auf Überwässerung")
        case "焦叶常见于低湿、缺水或强光":
            return l.tr(zh: zh, en: "Scorched leaves often come from low humidity, underwatering, or strong light", de: "Verbrannte Blätter kommen oft von niedriger Luftfeuchte, Wassermangel oder starkem Licht")
        case "掉叶常见于搬动、冷风、积水或长期弱光":
            return l.tr(zh: zh, en: "Leaf drop often follows moving, cold drafts, waterlogging, or long-term low light", de: "Blattfall folgt oft auf Umstellen, kalte Zugluft, Staunässe oder dauerhaft wenig Licht")
        case "不开花常见于光照不足、温差不足或肥水不稳":
            return l.tr(zh: zh, en: "No blooms often means too little light, little temperature variation, or unstable feeding/watering", de: "Keine Blüte bedeutet oft zu wenig Licht, wenig Temperaturwechsel oder instabile Pflege")
        case "徒长多与光照不足有关，根腐多与过浇有关":
            return l.tr(zh: zh, en: "Legginess often means low light; root rot often means overwatering", de: "Geilwuchs deutet auf wenig Licht; Wurzelfäule oft auf Überwässerung")
        case "徒长常见于光照不足，萎蔫常见于缺水或根系受损":
            return l.tr(zh: zh, en: "Legginess often means low light; wilting often means underwatering or root damage", de: "Geilwuchs deutet auf wenig Licht; Welken oft auf Wassermangel oder Wurzelschäden")
        case "叶心腐烂常见于积水不换或低温":
            return l.tr(zh: zh, en: "Crown rot often comes from stagnant water or cold", de: "Herzfäule kommt oft von stehendem Wasser oder Kälte")
        case "对猫狗和儿童有刺激性，避免误食":
            return l.tr(zh: zh, en: "Irritating to cats, dogs, and children if eaten", de: "Reizend für Katzen, Hunde und Kinder beim Verschlucken")
        case "对猫狗有轻中度风险，避免误食":
            return l.tr(zh: zh, en: "Mild to moderate risk for cats and dogs if eaten", de: "Leichtes bis mittleres Risiko für Katzen und Hunde beim Verschlucken")
        case "对猫狗和儿童有刺激性，避免误食汁液":
            return l.tr(zh: zh, en: "Sap can irritate cats, dogs, and children; avoid ingestion", de: "Saft kann Katzen, Hunde und Kinder reizen; Verschlucken vermeiden")
        case "通常对猫狗低风险":
            return l.tr(zh: zh, en: "Usually low risk for cats and dogs", de: "Meist geringes Risiko für Katzen und Hunde")
        case "对猫狗有误食风险，儿童也应避免入口":
            return l.tr(zh: zh, en: "Ingestion risk for cats and dogs; children should avoid eating it too", de: "Verschluckrisiko für Katzen und Hunde; auch Kinder sollten sie nicht essen")
        case "可能刺激宠物或儿童口腔，避免误食":
            return l.tr(zh: zh, en: "May irritate pets' or children's mouths; avoid ingestion", de: "Kann Maul/Mund von Haustieren oder Kindern reizen; Verschlucken vermeiden")
        case "汁液可能刺激猫狗和儿童，避免误食":
            return l.tr(zh: zh, en: "Sap may irritate cats, dogs, and children; avoid ingestion", de: "Saft kann Katzen, Hunde und Kinder reizen; Verschlucken vermeiden")
        case "白色汁液有刺激性，远离猫狗和儿童":
            return l.tr(zh: zh, en: "White sap is irritating; keep away from cats, dogs, and children", de: "Weißer Saft reizt; von Katzen, Hunden und Kindern fernhalten")
        case "含刺激性草酸钙，远离猫狗和儿童":
            return l.tr(zh: zh, en: "Contains irritating calcium oxalate; keep away from cats, dogs, and children", de: "Enthält reizendes Calciumoxalat; von Katzen, Hunden und Kindern fernhalten")
        case "可能刺激猫狗或儿童，避免误食":
            return l.tr(zh: zh, en: "May irritate cats, dogs, or children if eaten", de: "Kann Katzen, Hunde oder Kinder beim Verschlucken reizen")
        case "可能对猫狗和儿童有误食风险":
            return l.tr(zh: zh, en: "Possible ingestion risk for cats, dogs, and children", de: "Mögliches Verschluckrisiko für Katzen, Hunde und Kinder")
        case "可能对猫狗有误食风险，放在够不到处":
            return l.tr(zh: zh, en: "Possible ingestion risk for cats and dogs; keep out of reach", de: "Mögliches Verschluckrisiko für Katzen und Hunde; außer Reichweite stellen")
        default:
            return zh
        }
    }
}

private extension String {
    nonisolated var containsChineseCharacters: Bool {
        range(of: "\\p{Han}", options: .regularExpression) != nil
    }
}

nonisolated enum PlantCatalogFavoriteStore {
    static let favoritesKey = "ohana_plant_catalog_favorite_ids_v1"

    static func favoriteIDs(defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: favoritesKey) ?? [])
    }

    static func isFavorite(id: String, defaults: UserDefaults = .standard) -> Bool {
        favoriteIDs(defaults: defaults).contains(id)
    }

    static func setFavoriteIDs(_ ids: Set<String>, defaults: UserDefaults = .standard) {
        defaults.set(Array(ids).sorted(), forKey: favoritesKey)
    }

    @discardableResult
    static func toggleFavorite(id: String, defaults: UserDefaults = .standard) -> Bool {
        guard PlantCatalog.entry(id: id) != nil else { return false }
        var ids = favoriteIDs(defaults: defaults)
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
        setFavoriteIDs(ids, defaults: defaults)
        return ids.contains(id)
    }

    static func clearFavorites(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: favoritesKey)
    }
}
