#if DEBUG
import SwiftData
import SwiftUI

@MainActor
private final class ProfileDetailPreviewFixtures {
    let container: ModelContainer
    let services: AppServices
    let human: Human
    let pet: Pet
    let plant: Plant

    init() throws {
        container = try SharedModelContainer.makePreview()
        services = AppServices(modelContainer: container)

        human = Human(
            name: "一位名字非常非常长的家庭成员",
            birthday: Calendar.current.date(byAdding: .year, value: -32, to: Date()),
            bloodType: "AB",
            avatarEmoji: "👩",
            role: "owner",
            genderIdentityRaw: "女",
            nationality: "中国",
            city: "柏林"
        )
        human.heightCm = 168
        human.mbti = "INFJ"
        human.notes = "喜欢安静的周末、手冲咖啡和很长很长的家庭旅行记录。这里用于验证多行文本、最大动态字体和纪念状态下的只读层级。"
        human.passedAwayDate = Calendar.current.date(byAdding: .year, value: -1, to: Date())

        pet = Pet(
            name: "Milo",
            species: "cat",
            avatarEmoji: "🐈",
            themeColorHex: "4ECDC4"
        )

        plant = Plant(
            name: "客厅里那盆名字特别长的龟背竹",
            species: "Monstera deliciosa",
            location: "南窗边的木质花架",
            avatarEmoji: "🌿",
            themeColorHex: "2F806B",
            roomNameRaw: "客厅",
            potDiameterCm: 28,
            potMaterialRaw: "陶盆",
            soilTypeRaw: "树皮颗粒混合土",
            windowDirection: .south,
            lightLevel: .brightIndirect,
            acquiredDate: Calendar.current.date(byAdding: .year, value: -3, to: Date()),
            acquisitionSourceRaw: "朋友分株",
            currentHeightCm: 142,
            currentSpreadCm: 96,
            healthStatus: .stable,
            isToxicToCats: true
        )
        plant.archivedAt = Calendar.current.date(byAdding: .month, value: -2, to: Date())
        plant.notes = "这段长备注用于核对折行、分区间距、深浅色与 RTL 布局。归档后仍应保留全部档案，但不挂载护理 Dashboard。"

        container.mainContext.insert(human)
        container.mainContext.insert(pet)
        container.mainContext.insert(plant)
        try container.mainContext.save()
    }
}

#Preview("Profile · Human memorial · Long text") {
    if let fixtures = try? ProfileDetailPreviewFixtures() {
        NavigationStack {
            HumanBasicInfoDetailContentView(
                human: fixtures.human
            )
        }
        .modelContainer(fixtures.container)
        .environment(fixtures.services)
        .ohanaLocalizedEnvironment("zh")
        .preferredColorScheme(.dark)
    }
}

#Preview("Profile · Pet empty · AX5") {
    if let fixtures = try? ProfileDetailPreviewFixtures() {
        NavigationStack {
            PetBasicInfoDetailView(pet: fixtures.pet)
        }
        .modelContainer(fixtures.container)
        .environment(fixtures.services)
        .ohanaLocalizedEnvironment("en")
        .environment(\.dynamicTypeSize, .accessibility5)
    }
}

#Preview("Profile · Plant archived · RTL") {
    if let fixtures = try? ProfileDetailPreviewFixtures() {
        NavigationStack {
            PlantBasicInfoDetailView(plant: fixtures.plant)
        }
        .modelContainer(fixtures.container)
        .environment(fixtures.services)
        .ohanaLocalizedEnvironment("de")
        .environment(\.layoutDirection, .rightToLeft)
    }
}
#endif
