import Testing
@testable import Ohana

struct PetAvatarAssetCatalogTests {
    @Test func devonRexCoatOptionsUseUnifiedBlackEyes() {
        let coats = PetAvatarAssetCatalog.coatColors(species: "猫", breed: "德文卷毛猫") ?? []
        #expect(coats.map(\.name) == ["黑色", "白色", "蓝灰色", "奶油色", "棕虎斑", "黑白", "海豹重点色", "蓝重点色", "巧克力重点色", "火焰重点色"])

        let bluePointEyes = PetAvatarAssetCatalog.eyeColors(species: "猫", breed: "德文卷毛猫", coatColor: "蓝重点色") ?? []
        #expect(bluePointEyes.map(\.name) == ["黑色"])

        let flamePointEyes = PetAvatarAssetCatalog.eyeColors(species: "猫", breed: "德文卷毛猫", coatColor: "火焰重点色") ?? []
        #expect(flamePointEyes.map(\.name) == ["黑色"])
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

    @Test func nextCatBatchUsesBreedDatabaseCoatNamesAndBlackEyes() {
        let russianBlueCoats = PetAvatarAssetCatalog.coatColors(species: "猫", breed: "俄罗斯蓝猫") ?? []
        #expect(russianBlueCoats.map(\.name) == ["蓝灰色"])

        let silverShadedCoats = PetAvatarAssetCatalog.coatColors(species: "猫", breed: "银渐层") ?? []
        #expect(silverShadedCoats.map(\.name) == ["银底渐层", "浅银色"])

        let goldenShadedCoats = PetAvatarAssetCatalog.coatColors(species: "猫", breed: "金渐层") ?? []
        #expect(goldenShadedCoats.map(\.name) == ["金底渐层", "深金色"])

        let bengalCoats = PetAvatarAssetCatalog.coatColors(species: "猫", breed: "孟加拉猫") ?? []
        #expect(bengalCoats.map(\.name) == ["棕豹纹", "银豹纹", "雪色豹纹", "蓝豹纹"])

        let somaliCoats = PetAvatarAssetCatalog.coatColors(species: "猫", breed: "索马里猫") ?? []
        #expect(somaliCoats.map(\.name) == ["黄褐色", "红色", "蓝色", "栗色"])

        let eyes = PetAvatarAssetCatalog.eyeColors(species: "猫", breed: "Bengal", coatColor: "雪色豹纹") ?? []
        #expect(eyes.map(\.name) == ["黑色"])
    }

    @Test func newestCatBreedsUseGeneratedCoatOptionsAndBlackEyes() {
        let scottishFoldCoats = PetAvatarAssetCatalog.coatColors(species: "猫", breed: "苏格兰折耳猫") ?? []
        #expect(scottishFoldCoats.map(\.name) == ["蓝灰色", "白色", "黑色", "金色", "银色", "虎斑", "玳瑁"])

        let norwegianForestCoats = PetAvatarAssetCatalog.coatColors(species: "猫", breed: "Norwegian Forest Cat") ?? []
        #expect(norwegianForestCoats.map(\.name) == ["棕虎斑白", "黑白", "红白", "蓝白", "奶油色"])

        let burmeseCoats = PetAvatarAssetCatalog.coatColors(species: "猫", breed: "缅甸猫") ?? []
        #expect(burmeseCoats.map(\.name) == ["貂褐色", "蓝色", "巧克力色", "丁香色", "红色", "奶油色"])

        let sphynxCoats = PetAvatarAssetCatalog.coatColors(species: "猫", breed: "Sphynx") ?? []
        #expect(sphynxCoats.map(\.name) == ["桃色肤色", "黑色肤色", "蓝色肤色", "虎纹肤色"])

        let turkishAngoraCoats = PetAvatarAssetCatalog.coatColors(species: "猫", breed: "土耳其安哥拉猫") ?? []
        #expect(turkishAngoraCoats.map(\.name) == ["白色", "黑色", "蓝色", "红色"])

        let domesticShorthairCoats = PetAvatarAssetCatalog.coatColors(species: "猫", breed: "Chinese Domestic Cat") ?? []
        #expect(domesticShorthairCoats.map(\.name) == ["橘猫", "黑猫", "白猫", "三花（黑白橘）", "狸花（虎斑）", "玳瑁", "奶牛（黑白）"])

        let eyes = PetAvatarAssetCatalog.eyeColors(species: "猫", breed: "中华田园猫", coatColor: "奶牛（黑白）") ?? []
        #expect(eyes.map(\.name) == ["黑色"])
    }

    @Test func generatedDogBreedsUseGeneratedCoatOptionsAndBlackEyes() {
        let shibaCoats = PetAvatarAssetCatalog.coatColors(species: "狗", breed: "柴犬") ?? []
        #expect(shibaCoats.map(\.name) == ["赤色", "黑褐色", "奶油色", "胡麻色"])

        let goldenCoats = PetAvatarAssetCatalog.coatColors(species: "狗", breed: "金毛") ?? []
        #expect(goldenCoats.map(\.name) == ["浅金色"])

        let frenchBulldogCoats = PetAvatarAssetCatalog.coatColors(species: "狗", breed: "法斗") ?? []
        #expect(frenchBulldogCoats.map(\.name) == ["虎斑", "奶油色", "白色", "花斑", "蓝灰色", "巧克力色"])

        let labradorCoats = PetAvatarAssetCatalog.coatColors(species: "狗", breed: "拉布拉多犬") ?? []
        #expect(labradorCoats.map(\.name) == ["黑色", "黄色", "巧克力色"])

        let corgiCoats = PetAvatarAssetCatalog.coatColors(species: "狗", breed: "柯基") ?? []
        #expect(corgiCoats.map(\.name) == ["红白", "貂色白", "黑白三色"])

        let beagleCoats = PetAvatarAssetCatalog.coatColors(species: "狗", breed: "比格犬") ?? []
        #expect(beagleCoats.map(\.name) == ["黑棕白三色", "棕白", "柠檬白"])

        let bichonCoats = PetAvatarAssetCatalog.coatColors(species: "狗", breed: "Bichon Frise") ?? []
        #expect(bichonCoats.map(\.name) == ["纯白", "奶白"])

        let dalmatianCoats = PetAvatarAssetCatalog.coatColors(species: "狗", breed: "斑点狗") ?? []
        #expect(dalmatianCoats.map(\.name) == ["白底黑斑", "白底肝斑"])

        let dobermanCoats = PetAvatarAssetCatalog.coatColors(species: "狗", breed: "杜宾") ?? []
        #expect(dobermanCoats.map(\.name) == ["黑棕色", "蓝棕色", "红棕色"])

        let malteseCoats = PetAvatarAssetCatalog.coatColors(species: "狗", breed: "马尔济斯犬") ?? []
        #expect(malteseCoats.map(\.name) == ["纯白", "乳白"])

        let afghanCoats = PetAvatarAssetCatalog.coatColors(species: "狗", breed: "阿富汗猎犬") ?? []
        #expect(afghanCoats.map(\.name) == ["奶油色", "黑色", "红棕色"])

        let yorkshireCoats = PetAvatarAssetCatalog.coatColors(species: "狗", breed: "Yorkie") ?? []
        #expect(yorkshireCoats.map(\.name) == ["钢蓝背棕腿", "金棕色"])

        let samoyedCoats = PetAvatarAssetCatalog.coatColors(species: "狗", breed: "萨摩耶") ?? []
        #expect(samoyedCoats.map(\.name) == ["纯白", "奶白色"])

        let poodleCoats = PetAvatarAssetCatalog.coatColors(species: "狗", breed: "泰迪/贵宾犬") ?? []
        #expect(poodleCoats.map(\.name) == ["白色", "杏色", "红色", "黑色", "棕色", "银色", "蓝灰色"])

        let shihTzuCoats = PetAvatarAssetCatalog.coatColors(species: "狗", breed: "西施犬") ?? []
        #expect(shihTzuCoats.map(\.name) == ["金白色", "黑白", "红白"])

        let chineseRuralDogCoats = PetAvatarAssetCatalog.coatColors(species: "狗", breed: "Chinese Native Dog") ?? []
        #expect(chineseRuralDogCoats.map(\.name) == ["黄色", "黑色", "白色", "花斑"])

        let schnauzerCoats = PetAvatarAssetCatalog.coatColors(species: "狗", breed: "迷你雪纳瑞") ?? []
        #expect(schnauzerCoats.map(\.name) == ["椒盐色", "黑色", "黑银色", "白色"])

        let malamuteCoats = PetAvatarAssetCatalog.coatColors(species: "狗", breed: "阿拉斯加") ?? []
        #expect(malamuteCoats.map(\.name) == ["黑白", "灰白", "红白", "纯白"])

        let australianShepherdCoats = PetAvatarAssetCatalog.coatColors(species: "狗", breed: "Australian Shepherd") ?? []
        #expect(australianShepherdCoats.map(\.name) == ["蓝灰色", "红色", "黑色", "花斑色"])

        let borderCollieCoats = PetAvatarAssetCatalog.coatColors(species: "狗", breed: "Border Collie") ?? []
        #expect(borderCollieCoats.map(\.name) == ["黑白", "蓝白", "红白", "三色"])

        let pomeranianCoats = PetAvatarAssetCatalog.coatColors(species: "狗", breed: "Pomeranian") ?? []
        #expect(pomeranianCoats.map(\.name) == ["橙色", "白色", "黑色", "奶油色", "棕色"])

        let cavalierCoats = PetAvatarAssetCatalog.coatColors(species: "狗", breed: "Cavalier King Charles Spaniel") ?? []
        #expect(cavalierCoats.map(\.name) == ["红宝石色", "黑棕色", "三色", "布伦海姆色"])

        let cockerCoats = PetAvatarAssetCatalog.coatColors(species: "狗", breed: "Cocker Spaniel") ?? []
        #expect(cockerCoats.map(\.name) == ["黑色", "金色", "巧克力色", "花斑"])

        let huskyCoats = PetAvatarAssetCatalog.coatColors(species: "狗", breed: "Siberian Husky") ?? []
        #expect(huskyCoats.map(\.name) == ["黑白", "灰白", "红白", "纯白", "银白"])

        let germanShepherdCoats = PetAvatarAssetCatalog.coatColors(species: "狗", breed: "German Shepherd") ?? []
        #expect(germanShepherdCoats.map(\.name) == ["黑棕（鞍形）", "黑红色", "纯黑", "纯白"])

        let dachshundCoats = PetAvatarAssetCatalog.coatColors(species: "狗", breed: "Dachshund") ?? []
        #expect(dachshundCoats.map(\.name) == ["红色", "巧克力棕", "黑棕", "奶油色", "花斑"])

        let westieCoats = PetAvatarAssetCatalog.coatColors(species: "狗", breed: "Westie") ?? []
        #expect(westieCoats.map(\.name) == ["白色", "黑色"])

        let eyes = PetAvatarAssetCatalog.eyeColors(species: "狗", breed: "Golden Retriever", coatColor: "金色") ?? []
        #expect(eyes.map(\.name) == ["黑色"])
    }

    @Test func breedDatabaseCoatNamesMapToGeneratedAvatarAssets() {
        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "柴犬",
                gender: "male",
                coatColor: "红柴",
                eyeColor: "深棕色"
            ) == "dog_shiba_inu_boy_red.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "金毛寻回犬",
                gender: "female",
                coatColor: "金黄色",
                eyeColor: "棕色"
            ) == "dog_golden_retriever_girl_light_golden.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "猫",
                breed: "英国短毛猫",
                gender: "female",
                coatColor: "蓝灰色",
                eyeColor: "铜色"
            ) == "cat_british_shorthair_girl_blue.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "猫",
                breed: "布偶猫",
                gender: "female",
                coatColor: "海豹重点配白",
                eyeColor: "蓝色"
            ) == "cat_ragdoll_girl_seal_bicolor.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "猫",
                breed: "缅因库恩猫",
                gender: "male",
                coatColor: "银色",
                eyeColor: "绿色"
            ) == "cat_maine_coon_boy_silver_tabby.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "法国斗牛犬",
                gender: "female",
                coatColor: "蓝灰色",
                eyeColor: "深棕色"
            ) == "dog_french_bulldog_girl_blue_gray.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "拉布拉多犬",
                gender: "male",
                coatColor: "巧克力色",
                eyeColor: "棕色"
            ) == "dog_labrador_retriever_boy_chocolate.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "柯基犬",
                gender: "female",
                coatColor: "黑白三色",
                eyeColor: "深棕色"
            ) == "dog_corgi_girl_black_white_tricolor.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "比格犬",
                gender: "male",
                coatColor: "黑棕白三色",
                eyeColor: "棕色"
            ) == "dog_beagle_boy_black_brown_white_tricolor.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "比熊犬",
                gender: "female",
                coatColor: "奶白",
                eyeColor: "黑色"
            ) == "dog_bichon_frise_girl_cream_white.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "大麦町犬",
                gender: "male",
                coatColor: "白底肝斑",
                eyeColor: "棕色"
            ) == "dog_dalmatian_boy_liver_spotted.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "Doberman",
                gender: "female",
                coatColor: "蓝棕色",
                eyeColor: "深棕色"
            ) == "dog_doberman_girl_blue_tan.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "马尔济斯",
                gender: "male",
                coatColor: "乳白",
                eyeColor: "黑色"
            ) == "dog_maltese_boy_ivory.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "阿富汗猎犬",
                gender: "female",
                coatColor: "红棕色",
                eyeColor: "深棕色"
            ) == "dog_afghan_hound_girl_red_brown.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "约克夏梗",
                gender: "male",
                coatColor: "钢蓝背棕腿",
                eyeColor: "黑色"
            ) == "dog_yorkshire_terrier_boy_steel_blue_tan.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "Samoyed",
                gender: "female",
                coatColor: "奶白色",
                eyeColor: "黑色"
            ) == "dog_samoyed_girl_cream_white.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "Poodle",
                gender: "female",
                coatColor: "杏色",
                eyeColor: "琥珀色"
            ) == "dog_poodle_girl_apricot.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "Shih Tzu",
                gender: "female",
                coatColor: "金白色",
                eyeColor: "深棕色"
            ) == "dog_shih_tzu_girl_golden_white.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "中华田园犬",
                gender: "male",
                coatColor: "花斑",
                eyeColor: "棕色"
            ) == "dog_chinese_rural_dog_boy_pied.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "迷你雪纳瑞",
                gender: "male",
                coatColor: "椒盐色",
                eyeColor: "深棕色"
            ) == "dog_miniature_schnauzer_boy_salt_pepper.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "Alaskan Malamute",
                gender: "female",
                coatColor: "灰白",
                eyeColor: "棕色"
            ) == "dog_alaskan_malamute_girl_gray_white.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "澳大利亚牧羊犬",
                gender: "male",
                coatColor: "蓝灰色",
                eyeColor: "蓝色"
            ) == "dog_australian_shepherd_boy_blue_gray.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "Aussie",
                gender: "female",
                coatColor: "花斑色",
                eyeColor: "异瞳"
            ) == "dog_australian_shepherd_girl_dapple.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "边境牧羊犬",
                gender: "male",
                coatColor: "黑白",
                eyeColor: "棕色"
            ) == "dog_border_collie_boy_black_white.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "Border Collie",
                gender: "female",
                coatColor: "三色",
                eyeColor: "异瞳"
            ) == "dog_border_collie_girl_tricolor.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "博美犬",
                gender: "male",
                coatColor: "橙色",
                eyeColor: "深棕色"
            ) == "dog_pomeranian_boy_orange.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "Pomeranian",
                gender: "female",
                coatColor: "奶油色",
                eyeColor: "黑色"
            ) == "dog_pomeranian_girl_cream.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "查理王骑士犬",
                gender: "male",
                coatColor: "布伦海姆色",
                eyeColor: "深棕色"
            ) == "dog_cavalier_king_charles_spaniel_boy_blenheim.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "Cavalier",
                gender: "female",
                coatColor: "黑棕色",
                eyeColor: "黑色"
            ) == "dog_cavalier_king_charles_spaniel_girl_black_tan.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "可卡犬",
                gender: "male",
                coatColor: "金色",
                eyeColor: "棕色"
            ) == "dog_cocker_spaniel_boy_golden.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "Cocker",
                gender: "female",
                coatColor: "花斑",
                eyeColor: "榛色"
            ) == "dog_cocker_spaniel_girl_parti.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "西伯利亚哈士奇",
                gender: "male",
                coatColor: "灰白",
                eyeColor: "冰蓝色"
            ) == "dog_siberian_husky_boy_gray_white.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "Husky",
                gender: "female",
                coatColor: "银白",
                eyeColor: "异瞳"
            ) == "dog_siberian_husky_girl_silver_white.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "德国牧羊犬",
                gender: "male",
                coatColor: "黑棕（鞍形）",
                eyeColor: "棕色"
            ) == "dog_german_shepherd_boy_black_tan_saddle.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "German Shepherd",
                gender: "female",
                coatColor: "纯白",
                eyeColor: "黑色"
            ) == "dog_german_shepherd_girl_solid_white.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "腊肠犬",
                gender: "female",
                coatColor: "巧克力棕",
                eyeColor: "棕色"
            ) == "dog_dachshund_girl_chocolate_brown.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "Dachshund",
                gender: "male",
                coatColor: "花斑",
                eyeColor: "蓝色"
            ) == "dog_dachshund_boy_dapple.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "西高地白梗",
                gender: "female",
                coatColor: "白色",
                eyeColor: "深棕色"
            ) == "dog_west_highland_white_terrier_girl_white.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "West Highland White Terrier",
                gender: "male",
                coatColor: "白色",
                eyeColor: "黑色"
            ) == "dog_west_highland_white_terrier_boy_white.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "狗",
                breed: "Westie",
                gender: "female",
                coatColor: "黑色",
                eyeColor: "黑色"
            ) == "dog_west_highland_white_terrier_girl_black.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "猫",
                breed: "俄罗斯蓝猫",
                gender: "female",
                coatColor: "蓝灰色",
                eyeColor: "翠绿色"
            ) == "cat_russian_blue_girl_blue_gray.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "猫",
                breed: "银渐层",
                gender: "male",
                coatColor: "浅银色",
                eyeColor: "绿色"
            ) == "cat_silver_shaded_boy_light_silver.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "猫",
                breed: "Golden Shaded",
                gender: "female",
                coatColor: "深金色",
                eyeColor: "铜绿色"
            ) == "cat_golden_shaded_girl_dark_golden.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "猫",
                breed: "孟加拉猫",
                gender: "male",
                coatColor: "棕豹纹",
                eyeColor: "金色"
            ) == "cat_bengal_boy_brown_rosetted.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "猫",
                breed: "Somali",
                gender: "female",
                coatColor: "栗色",
                eyeColor: "琥珀色"
            ) == "cat_somali_girl_fawn.png"
        )
    }

    @Test func newestCatBreedDatabaseCoatNamesMapToGeneratedAvatarAssets() {
        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "猫",
                breed: "苏格兰折耳猫",
                gender: "female",
                coatColor: "虎斑",
                eyeColor: "金色"
            ) == "cat_scottish_fold_girl_tabby.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "猫",
                breed: "Norwegian Forest Cat",
                gender: "male",
                coatColor: "棕虎斑白",
                eyeColor: "绿色"
            ) == "cat_norwegian_forest_boy_brown_tabby_white.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "猫",
                breed: "缅甸猫",
                gender: "female",
                coatColor: "貂褐色",
                eyeColor: "金色"
            ) == "cat_burmese_girl_sable.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "猫",
                breed: "Sphynx",
                gender: "male",
                coatColor: "虎纹肤色",
                eyeColor: "蓝色"
            ) == "cat_sphynx_boy_tabby_skin.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "猫",
                breed: "土耳其安哥拉猫",
                gender: "female",
                coatColor: "白色",
                eyeColor: "异瞳"
            ) == "cat_turkish_angora_girl_white.png"
        )

        #expect(
            PetAvatarAssetCatalog.avatarFilename(
                species: "猫",
                breed: "Chinese Domestic Cat",
                gender: "female",
                coatColor: "奶牛（黑白）",
                eyeColor: "黄色"
            ) == "cat_domestic_shorthair_girl_black_white.png"
        )
    }

    @Test func dachshundAvatarAssetsAreBundled() {
        for coat in ["红色", "巧克力棕", "黑棕", "奶油色", "花斑"] {
            #expect(
                PetAvatarAssetCatalog.avatarData(
                    species: "狗",
                    breed: "腊肠犬",
                    gender: "male",
                    coatColor: coat,
                    eyeColor: "黑色"
                ) != nil
            )

            #expect(
                PetAvatarAssetCatalog.avatarData(
                    species: "狗",
                    breed: "Dachshund",
                    gender: "female",
                    coatColor: coat,
                    eyeColor: "棕色"
                ) != nil
            )
        }
    }

    @Test func australianShepherdAvatarAssetsAreBundled() {
        for coat in ["蓝灰色", "红色", "黑色", "花斑色"] {
            #expect(
                PetAvatarAssetCatalog.avatarData(
                    species: "狗",
                    breed: "澳牧",
                    gender: "male",
                    coatColor: coat,
                    eyeColor: "蓝色"
                ) != nil
            )

            #expect(
                PetAvatarAssetCatalog.avatarData(
                    species: "狗",
                    breed: "Australian Shepherd",
                    gender: "female",
                    coatColor: coat,
                    eyeColor: "异瞳"
                ) != nil
            )
        }
    }

    @Test func borderCollieAvatarAssetsAreBundled() {
        for coat in ["黑白", "蓝白", "红白", "三色"] {
            #expect(
                PetAvatarAssetCatalog.avatarData(
                    species: "狗",
                    breed: "边牧",
                    gender: "male",
                    coatColor: coat,
                    eyeColor: "棕色"
                ) != nil
            )

            #expect(
                PetAvatarAssetCatalog.avatarData(
                    species: "狗",
                    breed: "Border Collie",
                    gender: "female",
                    coatColor: coat,
                    eyeColor: "蓝色"
                ) != nil
            )
        }
    }

    @Test func pomeranianAvatarAssetsAreBundled() {
        for coat in ["橙色", "白色", "黑色", "奶油色", "棕色"] {
            #expect(
                PetAvatarAssetCatalog.avatarData(
                    species: "狗",
                    breed: "博美",
                    gender: "male",
                    coatColor: coat,
                    eyeColor: "深棕色"
                ) != nil
            )

            #expect(
                PetAvatarAssetCatalog.avatarData(
                    species: "狗",
                    breed: "Pomeranian",
                    gender: "female",
                    coatColor: coat,
                    eyeColor: "黑色"
                ) != nil
            )
        }
    }

    @Test func cavalierKingCharlesSpanielAvatarAssetsAreBundled() {
        for coat in ["红宝石色", "黑棕色", "三色", "布伦海姆色"] {
            #expect(
                PetAvatarAssetCatalog.avatarData(
                    species: "狗",
                    breed: "查理王",
                    gender: "male",
                    coatColor: coat,
                    eyeColor: "深棕色"
                ) != nil
            )

            #expect(
                PetAvatarAssetCatalog.avatarData(
                    species: "狗",
                    breed: "Cavalier King Charles Spaniel",
                    gender: "female",
                    coatColor: coat,
                    eyeColor: "黑色"
                ) != nil
            )
        }
    }

    @Test func cockerSpanielAvatarAssetsAreBundled() {
        for coat in ["黑色", "金色", "巧克力色", "花斑"] {
            #expect(
                PetAvatarAssetCatalog.avatarData(
                    species: "狗",
                    breed: "可卡",
                    gender: "male",
                    coatColor: coat,
                    eyeColor: "棕色"
                ) != nil
            )

            #expect(
                PetAvatarAssetCatalog.avatarData(
                    species: "狗",
                    breed: "Cocker Spaniel",
                    gender: "female",
                    coatColor: coat,
                    eyeColor: "榛色"
                ) != nil
            )
        }
    }

    @Test func siberianHuskyAvatarAssetsAreBundled() {
        for coat in ["黑白", "灰白", "红白", "纯白", "银白"] {
            #expect(
                PetAvatarAssetCatalog.avatarData(
                    species: "狗",
                    breed: "哈士奇",
                    gender: "male",
                    coatColor: coat,
                    eyeColor: "冰蓝色"
                ) != nil
            )

            #expect(
                PetAvatarAssetCatalog.avatarData(
                    species: "狗",
                    breed: "Siberian Husky",
                    gender: "female",
                    coatColor: coat,
                    eyeColor: "异瞳"
                ) != nil
            )
        }
    }

    @Test func germanShepherdAvatarAssetsAreBundled() {
        for coat in ["黑棕（鞍形）", "黑红色", "纯黑", "纯白"] {
            #expect(
                PetAvatarAssetCatalog.avatarData(
                    species: "狗",
                    breed: "德牧",
                    gender: "male",
                    coatColor: coat,
                    eyeColor: "棕色"
                ) != nil
            )

            #expect(
                PetAvatarAssetCatalog.avatarData(
                    species: "狗",
                    breed: "German Shepherd",
                    gender: "female",
                    coatColor: coat,
                    eyeColor: "黑色"
                ) != nil
            )
        }
    }

    @Test func westHighlandWhiteTerrierAvatarAssetsAreBundled() {
        for coat in ["白色", "黑色"] {
            #expect(
                PetAvatarAssetCatalog.avatarData(
                    species: "狗",
                    breed: "西高地",
                    gender: "male",
                    coatColor: coat,
                    eyeColor: "黑色"
                ) != nil
            )

            #expect(
                PetAvatarAssetCatalog.avatarData(
                    species: "狗",
                    breed: "Westie",
                    gender: "female",
                    coatColor: coat,
                    eyeColor: "深棕色"
                ) != nil
            )
        }
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
            ) == "dog_golden_retriever_girl_light_golden.png"
        )
    }

    @Test func devonRexAvatarAssetsAreBundled() {
        for coat in ["黑色", "白色", "蓝灰色", "奶油色", "棕虎斑", "黑白", "海豹重点色", "蓝重点色", "巧克力重点色", "火焰重点色"] {
            #expect(
                PetAvatarAssetCatalog.avatarData(
                    species: "猫",
                    breed: "德文卷毛猫",
                    gender: "male",
                    coatColor: coat,
                    eyeColor: "黑色"
                ) != nil
            )

            #expect(
                PetAvatarAssetCatalog.avatarData(
                    species: "猫",
                    breed: "Devon Rex",
                    gender: "female",
                    coatColor: coat,
                    eyeColor: "黑色"
                ) != nil
            )
        }
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
                breed: "未覆盖狗",
                gender: "male",
                coatColor: "黑白",
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
