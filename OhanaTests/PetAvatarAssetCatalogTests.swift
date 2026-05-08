import Testing
@testable import Ohana

struct PetAvatarAssetCatalogTests {
    @Test func devonRexCoatOptionsUseUnifiedBlackEyes() {
        let coats = PetAvatarAssetCatalog.coatColors(species: "猫", breed: "德文卷毛猫") ?? []
        #expect(coats.map(\.name).contains("海豹重点色"))
        #expect(coats.map(\.name).contains("蓝山猫重点色"))

        let bluePointEyes = PetAvatarAssetCatalog.eyeColors(species: "猫", breed: "德文卷毛猫", coatColor: "蓝重点色") ?? []
        #expect(bluePointEyes.map(\.name) == ["黑色"])

        let tortieEyes = PetAvatarAssetCatalog.eyeColors(species: "猫", breed: "德文卷毛猫", coatColor: "玳瑁") ?? []
        #expect(tortieEyes.map(\.name) == ["黑色"])
    }

    @Test func devonRexAvatarFilenameFallsBackToGenderStandardForCustomColors() {
        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "猫",
                breed: "德文卷毛猫",
                gender: "female",
                coatColor: "自定义",
                eyeColor: "蓝色"
            ) == "cat_girl_standard.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "猫",
                breed: "德文卷毛猫",
                gender: "male",
                coatColor: "自定义",
                eyeColor: "黑色"
            ) == "cat_boy_standard.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "猫",
                breed: "德文卷毛猫",
                gender: "male",
                coatColor: "蓝重点色",
                eyeColor: "黑色"
            ) == "cat_devon_rex_boy_blue_point.png"
        )
    }

    @Test func uncoveredCatBreedFallsBackToSpeciesStandard() {
        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "猫",
                breed: "英国短毛猫",
                gender: "female",
                coatColor: "蓝色",
                eyeColor: "黑色"
            ) == "cat_girl_standard.png"
        )
    }

    @Test func uncoveredSpeciesOptionsFallBackToSpeciesStandards() {
        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "柴犬",
                gender: "male",
                coatColor: "赤色",
                eyeColor: "黑色"
            ) == "dog_boy_standard.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "兔子",
                breed: "垂耳兔",
                gender: "female",
                coatColor: "白色",
                eyeColor: "黑色"
            ) == "rabbit_girl_standard.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "鱼",
                breed: "金鱼",
                gender: "female",
                coatColor: "红色",
                eyeColor: "黑色"
            ) == "fish_girl_standard.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "鸟",
                breed: "文鸟",
                gender: "male",
                coatColor: "灰色",
                eyeColor: "黑色"
            ) == "bird_boy_standard.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "爬宠",
                breed: "乌龟",
                gender: "male",
                coatColor: "绿色",
                eyeColor: "棕色"
            ) == "reptile_boy_standard.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "仓鼠",
                breed: "叙利亚仓鼠（金熊）",
                gender: "female",
                coatColor: "金黄色",
                eyeColor: "红色（白化）"
            ) == "hamster_girl_standard.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "其他",
                breed: "雪貂",
                gender: "female",
                coatColor: "奶油色",
                eyeColor: "黑色"
            ) == "other_girl_standard.png"
        )
    }
}
