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

    @Test func shorthairCatBreedsUseGeneratedCoatOptionsAndBlackEyes() {
        let britishCoats = PetAvatarAssetCatalog.coatColors(species: "猫", breed: "英国短毛猫") ?? []
        #expect(britishCoats.map(\.name) == ["蓝色", "银虎斑", "金渐层", "黑色", "白色", "奶油色", "重点色"])

        let americanCoats = PetAvatarAssetCatalog.coatColors(species: "猫", breed: "美国短毛猫") ?? []
        #expect(americanCoats.map(\.name) == ["银虎斑", "棕虎斑", "黑色", "白色", "橘虎斑", "蓝色"])

        let eyes = PetAvatarAssetCatalog.eyeColors(species: "猫", breed: "英短", coatColor: "金渐层") ?? []
        #expect(eyes.map(\.name) == ["黑色"])
    }

    @Test func pointAndTickedCatBreedsUseGeneratedCoatOptionsAndBlackEyes() {
        let ragdollCoats = PetAvatarAssetCatalog.coatColors(species: "猫", breed: "布偶猫") ?? []
        #expect(ragdollCoats.map(\.name) == ["海豹重点色", "海豹双色", "蓝重点色", "蓝双色", "巧克力重点色", "丁香重点色", "火焰重点色"])

        let siameseCoats = PetAvatarAssetCatalog.coatColors(species: "猫", breed: "暹罗猫") ?? []
        #expect(siameseCoats.map(\.name) == ["海豹重点色", "蓝重点色", "巧克力重点色", "丁香重点色"])

        let abyssinianCoats = PetAvatarAssetCatalog.coatColors(species: "猫", breed: "阿比西尼亚猫") ?? []
        #expect(abyssinianCoats.map(\.name) == ["黄褐色", "肉桂红", "蓝色", "浅黄褐色"])

        let eyes = PetAvatarAssetCatalog.eyeColors(species: "猫", breed: "暹罗", coatColor: "蓝重点色") ?? []
        #expect(eyes.map(\.name) == ["黑色"])
    }

    @Test func maineCoonAndPartialPersianUseGeneratedCoatOptionsAndBlackEyes() {
        let maineCoonCoats = PetAvatarAssetCatalog.coatColors(species: "猫", breed: "缅因库恩猫") ?? []
        #expect(maineCoonCoats.map(\.name) == ["棕虎斑", "银虎斑", "红虎斑", "黑烟色", "蓝灰色", "黑色", "白色", "三花"])

        let persianCoats = PetAvatarAssetCatalog.coatColors(species: "猫", breed: "波斯猫") ?? []
        #expect(persianCoats.map(\.name) == ["白色", "黑色", "蓝色"])

        let eyes = PetAvatarAssetCatalog.eyeColors(species: "猫", breed: "缅因猫", coatColor: "黑烟色") ?? []
        #expect(eyes.map(\.name) == ["黑色"])
    }

    @Test func liHuaUsesGeneratedTabbyOptionsAndBlackEyes() {
        let coats = PetAvatarAssetCatalog.coatColors(species: "猫", breed: "狸花猫") ?? []
        #expect(coats.map(\.name) == ["棕狸花", "银灰狸花"])

        let eyes = PetAvatarAssetCatalog.eyeColors(species: "猫", breed: "Dragon Li", coatColor: "棕狸花") ?? []
        #expect(eyes.map(\.name) == ["黑色"])
    }

    @Test func generatedDogBreedsUseGeneratedCoatOptionsAndBlackEyes() {
        let shibaCoats = PetAvatarAssetCatalog.coatColors(species: "狗", breed: "柴犬") ?? []
        #expect(shibaCoats.map(\.name) == ["赤色", "黑褐色", "奶油色", "胡麻色"])

        let goldenCoats = PetAvatarAssetCatalog.coatColors(species: "狗", breed: "金毛") ?? []
        #expect(goldenCoats.map(\.name) == ["浅金色", "金色", "深金色"])

        let eyes = PetAvatarAssetCatalog.eyeColors(species: "狗", breed: "Golden Retriever", coatColor: "金色") ?? []
        #expect(eyes.map(\.name) == ["黑色"])
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

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "猫",
                breed: "英国短毛猫",
                gender: "female",
                coatColor: "金渐层",
                eyeColor: "蓝色"
            ) == "cat_british_shorthair_girl_golden_shaded.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "猫",
                breed: "美短",
                gender: "male",
                coatColor: "橘虎斑",
                eyeColor: "绿色"
            ) == "cat_american_shorthair_boy_orange_tabby.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "猫",
                breed: "布偶猫",
                gender: "female",
                coatColor: "海豹双色",
                eyeColor: "蓝色"
            ) == "cat_ragdoll_girl_seal_bicolor.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "猫",
                breed: "暹罗",
                gender: "male",
                coatColor: "巧克力重点色",
                eyeColor: "绿色"
            ) == "cat_siamese_boy_chocolate_point.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "猫",
                breed: "Abyssinian",
                gender: "female",
                coatColor: "黄褐色",
                eyeColor: "琥珀色"
            ) == "cat_abyssinian_girl_ruddy.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "猫",
                breed: "缅因猫",
                gender: "male",
                coatColor: "黑烟色",
                eyeColor: "绿色"
            ) == "cat_maine_coon_boy_black_smoke.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "猫",
                breed: "波斯猫",
                gender: "female",
                coatColor: "蓝色",
                eyeColor: "铜色"
            ) == "cat_persian_girl_blue.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "猫",
                breed: "波斯猫",
                gender: "male",
                coatColor: "奶油色",
                eyeColor: "黑色"
            ) == "cat_boy_standard.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "猫",
                breed: "狸花",
                gender: "female",
                coatColor: "银灰狸花",
                eyeColor: "绿色"
            ) == "cat_li_hua_girl_silver_mackerel_tabby.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "柴犬",
                gender: "male",
                coatColor: "赤色",
                eyeColor: "黑色"
            ) == "dog_shiba_inu_boy_red.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "金毛寻回犬",
                gender: "female",
                coatColor: "深金色",
                eyeColor: "黑色"
            ) == "dog_golden_retriever_girl_dark_golden.png"
        )
    }

    @Test func uncoveredCatBreedFallsBackToSpeciesStandard() {
        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "猫",
                breed: "未覆盖猫",
                gender: "female",
                coatColor: "蓝重点配白",
                eyeColor: "黑色"
            ) == "cat_girl_standard.png"
        )
    }

    @Test func uncoveredSpeciesOptionsFallBackToSpeciesStandards() {
        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "法斗",
                gender: "male",
                coatColor: "奶油色",
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
