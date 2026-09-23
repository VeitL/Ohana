import Foundation
import SwiftData
import Testing
@testable import Ohana

struct TaskCenterSystemJourneyGuideTests {
    @Test
    func petInlineCopyHasExactValuesForEverySupportedLanguage() throws {
        let expected: [String: [String]] = [
            "zh": ["生日", "到家日", "♂ 男孩", "♀ 女孩", "毛色（可选）", "粮食品牌", "每日份量（克）", "请输入大于 0 的数字", "已保存"],
            "en": ["Birthday", "Home date", "♂ Boy", "♀ Girl", "Coat color (optional)", "Food brand", "Daily portion (g)", "Enter a number greater than 0", "Saved"],
            "de": ["Geburtstag", "Einzugsdatum", "♂ Junge", "♀ Mädchen", "Fellfarbe (optional)", "Futtermarke", "Tagesportion (g)", "Zahl größer als 0 eingeben", "Gespeichert"],
            "es": ["Cumpleaños", "Fecha de llegada", "♂ Macho", "♀ Hembra", "Color del pelaje (opcional)", "Marca de alimento", "Porción diaria (g)", "Introduce un número mayor que 0", "Guardado"],
            "pt": ["Aniversário", "Data de chegada", "♂ Macho", "♀ Fêmea", "Cor da pelagem (opcional)", "Marca da ração", "Porção diária (g)", "Insira um número maior que 0", "Salvo"],
            "fr": ["Anniversaire", "Date d’arrivée", "♂ Mâle", "♀ Femelle", "Couleur du pelage (facultatif)", "Marque d’aliment", "Portion quotidienne (g)", "Saisissez un nombre supérieur à 0", "Enregistré"],
            "ja": ["誕生日", "お迎え日", "♂ 男の子", "♀ 女の子", "毛色（任意）", "フードブランド", "1日の量（g）", "0より大きい数値を入力", "保存済み"],
            "ko": ["생일", "입양일", "♂ 남아", "♀ 여아", "털 색상(선택)", "사료 브랜드", "하루 급여량(g)", "0보다 큰 숫자를 입력하세요", "저장됨"],
            "it": ["Compleanno", "Data di arrivo", "♂ Maschio", "♀ Femmina", "Colore del mantello (facoltativo)", "Marca del cibo", "Porzione giornaliera (g)", "Inserisci un numero maggiore di 0", "Salvato"]
        ]

        #expect(Set(expected.keys) == Set(AppLanguage.supported.map(\.code)))
        for language in AppLanguage.supported {
            let expectedValues = try #require(expected[language.code])
            #expect(TaskCenterPetProfileInlineCopy.exactValues(L10n(language.code)) == expectedValues)
        }
    }

    @Test
    func simplifiedJourneyCopyHasExactValuesForEverySupportedLanguage() throws {
        let expected: [String: [String]] = [
            "zh": ["资料", "进度", "证件与保障", "紧急联系", "疫苗与保健", "照护计划", "记录一次照护", "只记录真实完成的照护。", "只记录真实发生的保健事实；不要为了完成任务编造记录。"],
            "en": ["Profile", "Progress", "Documents & protection", "Emergency contact", "Preventive care", "Care plan", "Record care", "Only completed care counts.", "Record only real preventive-care facts. Never invent a health record to finish a task."],
            "de": ["Profil", "Fortschritt", "Dokumente & Schutz", "Notfallkontakt", "Vorsorge", "Pflegeplan", "Pflege erfassen", "Nur erledigte Pflege zählt.", "Erfasse nur echte Vorsorge. Erfinde keine Gesundheitsdaten für eine Aufgabe."],
            "es": ["Perfil", "Progreso", "Documentos y protección", "Contacto de emergencia", "Cuidados preventivos", "Plan de cuidados", "Registrar cuidado", "Solo cuenta el cuidado realizado.", "Registra solo cuidados preventivos reales; no inventes datos para completar una tarea."],
            "pt": ["Perfil", "Progresso", "Documentos e proteção", "Contato de emergência", "Cuidados preventivos", "Plano de cuidados", "Registrar cuidado", "Só contam cuidados concluídos.", "Registre apenas cuidados preventivos reais; não invente dados para concluir uma tarefa."],
            "fr": ["Profil", "Progression", "Documents et protection", "Contact d’urgence", "Soins préventifs", "Plan de soins", "Enregistrer un soin", "Seuls les soins effectués comptent.", "N’enregistrez que des soins préventifs réels ; n’inventez rien pour terminer une tâche."],
            "ja": ["プロフィール", "進捗", "書類と保障", "緊急連絡先", "予防ケア", "ケアプラン", "ケアを記録", "実際に完了したケアのみ記録します。", "実際に行った予防ケアだけを記録し、タスクのために記録を作らないでください。"],
            "ko": ["프로필", "진행", "서류 및 보호", "긴급 연락처", "예방 관리", "돌봄 계획", "돌봄 기록", "실제로 완료한 돌봄만 기록하세요.", "실제로 한 예방 관리만 기록하고, 과제를 위해 기록을 만들지 마세요."],
            "it": ["Profilo", "Avanzamento", "Documenti e protezione", "Contatto di emergenza", "Cure preventive", "Piano di cura", "Registra una cura", "Conta solo la cura effettivamente completata.", "Registra solo cure preventive reali; non inventare dati per completare un’attività."]
        ]

        #expect(Set(expected.keys) == Set(AppLanguage.supported.map(\.code)))
        for language in AppLanguage.supported {
            let expectedValues = try #require(expected[language.code])
            #expect(TaskCenterSystemJourneyCopy.exactValues(L10n(language.code)) == expectedValues)
        }
    }

    @Test @MainActor
    func inlinePetDatesPreserveEveryUnrelatedProfileField() {
        let originalBirthday = Date(timeIntervalSince1970: 1_000_000)
        let nextHomeDate = Date(timeIntervalSince1970: 3_000_000)
        let pet = Pet(
            name: "Mochi",
            species: "dog",
            breed: "Shiba",
            birthday: originalBirthday,
            gender: "girl",
            avatarEmoji: "🐕"
        )
        pet.coatColor = "sesame"
        pet.microchipID = "chip-1"
        pet.vetContact = "123"
        pet.foodBrand = "Good Food"
        pet.dailyPortionGrams = 120.5
        pet.personalityTagsRaw = "curious,lazy"

        let input = TaskCenterPetProfileInlineInputBuilder.input(
            for: pet,
            applying: .lifeStage(birthday: originalBirthday, homeDate: nextHomeDate)
        )

        #expect(input.name == "Mochi")
        #expect(input.species == "dog")
        #expect(input.breed == "Shiba")
        #expect(input.gender == "girl")
        #expect(input.birthday == Calendar.current.startOfDay(for: originalBirthday))
        #expect(input.homeDate == Calendar.current.startOfDay(for: nextHomeDate))
        #expect(input.coatColor == "sesame")
        #expect(input.microchipID == "chip-1")
        #expect(input.vetContact == "123")
        #expect(input.foodBrand == "Good Food")
        #expect(input.dailyPortionGrams == 120.5)
        #expect(input.personalityTagIDs == ["curious", "lazy"])
    }

    @Test @MainActor
    func inlinePetEditorsCompleteOnlyTheirMatchingCategory() {
        let pet = Pet(name: "Mochi", gender: "unknown")
        #expect(!TaskCenterPetProfileInlineInputBuilder.isSatisfied(.petBodyProfile, by: pet))
        #expect(!TaskCenterPetProfileInlineInputBuilder.isSatisfied(.petDailyCare, by: pet))

        let bodyInput = TaskCenterPetProfileInlineInputBuilder.input(
            for: pet,
            applying: .bodyProfile(gender: "boy", coatColor: "")
        )
        pet.gender = bodyInput.gender
        #expect(TaskCenterPetProfileInlineInputBuilder.isSatisfied(.petBodyProfile, by: pet))
        #expect(!TaskCenterPetProfileInlineInputBuilder.isSatisfied(.petDailyCare, by: pet))

        let careInput = TaskCenterPetProfileInlineInputBuilder.input(
            for: pet,
            applying: .dailyCare(foodBrand: "Good Food", dailyPortionGrams: 80)
        )
        pet.foodBrand = careInput.foodBrand ?? ""
        pet.dailyPortionGrams = careInput.dailyPortionGrams ?? 0
        #expect(TaskCenterPetProfileInlineInputBuilder.isSatisfied(.petDailyCare, by: pet))
    }

    @Test @MainActor
    func inlineHumanProfileUpdatesOnlyTheActiveCardFields() {
        let originalBirthday = Date(timeIntervalSince1970: 1_000_000)
        let nextBirthday = Date(timeIntervalSince1970: 2_000_000)
        let human = Human(
            name: "Ada",
            birthday: originalBirthday,
            bloodType: "AB",
            avatarEmoji: "🧑‍🚀",
            role: "member",
            genderIdentityRaw: "female",
            nationality: "DE",
            city: "Berlin"
        )
        human.heightCm = 171.5
        human.mbti = "INTJ"
        human.notes = "关系:本人｜Keep this"

        let input = TaskCenterHumanProfileInlineInputBuilder.input(
            for: human,
            applying: .birthday(nextBirthday)
        )

        #expect(input.name == "Ada")
        #expect(input.birthday == Calendar.current.startOfDay(for: nextBirthday))
        #expect(input.gender == "female")
        #expect(input.bloodType == "AB")
        #expect(input.heightText == "171.5")
        #expect(input.mbti == "INTJ")
        #expect(input.nationality == "DE")
        #expect(input.city == "Berlin")
        #expect(input.notes == "Keep this")
        #expect(input.preservedNoteParts == ["关系:本人"])
    }

    @Test @MainActor
    func inlineOptionalDetailsBuildACompleteProfileWithoutTouchingIdentity() {
        let human = Human(name: "Ada", genderIdentityRaw: "private")
        let input = TaskCenterHumanProfileInlineInputBuilder.input(
            for: human,
            applying: .optionalDetails(
                bloodType: "O",
                heightText: "168",
                notes: "Loves long walks"
            )
        )

        #expect(input.gender == "private")
        #expect(input.bloodType == "O")
        #expect(input.heightText == "168")
        #expect(input.notes == "Loves long walks")

        human.bloodType = input.bloodType
        human.heightCm = 168
        human.notes = input.notes
        #expect(TaskCenterHumanProfileInlineInputBuilder.isSatisfied(
            .humanPersonalityContext,
            by: human
        ))
        #expect(!TaskCenterHumanProfileInlineInputBuilder.isSatisfied(
            .humanLifeStage,
            by: human
        ))
    }

    @Test @MainActor
    func inlineHumanDraftNormalizationPreventsRepeatedEquivalentSaves() {
        let human = Human(name: "Ada", genderIdentityRaw: "private")
        let normalized = TaskCenterHumanProfileInlineUpdate.optionalDetails(
            bloodType: "O",
            heightText: "168",
            notes: "Keeps calm"
        )
        let raw = TaskCenterHumanProfileInlineUpdate.optionalDetails(
            bloodType: " O ",
            heightText: "168.0",
            notes: "  Keeps calm  "
        )
        let input = TaskCenterHumanProfileInlineInputBuilder.input(for: human, applying: raw)

        #expect(input.bloodType == "O")
        #expect(input.heightText == "168")
        #expect(input.notes == "Keeps calm")
        #expect(TaskCenterHumanProfileInlineNormalization.pendingUpdate(
            normalized,
            lastSuccessfulUpdate: normalized
        ) == nil)

        let avatar = TaskCenterHumanProfileInlineUpdate.avatarImageData(Data([0x01, 0x02]))
        #expect(TaskCenterHumanProfileInlineNormalization.pendingUpdate(
            avatar,
            lastSuccessfulUpdate: avatar
        ) == nil)
    }

    @Test @MainActor
    func persistedBirthdayRestoresZodiacAndChangingBirthdayUpdatesIt() throws {
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: Schema(ArkSchemaV99.models),
            configurations: [configuration]
        )
        let originalBirthday = localDate(year: 1990, month: 3, day: 21)
        let nextBirthday = localDate(year: 1990, month: 4, day: 20)
        let writeContext = ModelContext(container)
        let human = Human(name: "Ada", birthday: originalBirthday)
        let humanID = human.id
        writeContext.insert(human)
        try writeContext.save()

        let firstReadContext = ModelContext(container)
        let firstRead = try #require(firstReadContext.fetch(
            FetchDescriptor<Human>(predicate: #Predicate { $0.id == humanID })
        ).first)
        let l = L10n("zh")
        #expect(Human.westernZodiacDisplay(for: try #require(firstRead.birthday), l: l) == "白羊座")

        let input = TaskCenterHumanProfileInlineInputBuilder.input(
            for: firstRead,
            applying: .birthday(nextBirthday)
        )
        firstRead.birthday = input.birthday
        try firstReadContext.save()

        let secondReadContext = ModelContext(container)
        let secondRead = try #require(secondReadContext.fetch(
            FetchDescriptor<Human>(predicate: #Predicate { $0.id == humanID })
        ).first)
        #expect(Human.westernZodiacDisplay(for: try #require(secondRead.birthday), l: l) == "金牛座")
    }

    @Test func everyStarterTaskProducesAStableQuestionFlow() {
        let expected: [HouseholdStarterJourneyTask: [HouseholdStarterJourneyCheckpoint?]] = [
            .humanProfile: [
                .humanAppearance,
                .humanLifeStage,
                .humanBodyProfile,
                .humanPersonalityContext
            ],
            .petProfile: [.petLifeStage, .petBodyProfile, .petPersonalityAppearance, .petDailyCare],
            .identityProtection: [.petIdentityDocuments, .petEmergencyContact],
            .healthProtection: [.petHealthProtection],
            .carePlan: [.acceptedRecommendedCarePlan],
            .firstCare: [nil]
        ]

        for task in HouseholdStarterJourneyTask.allCases {
            let guide = TaskCenterSystemJourneyGuide(task: task)
            #expect(guide.questions.map(\.checkpoint) == expected[task])
            #expect(guide.requiredCheckpointCount == HouseholdStarterJourneyPolicy.requiredCheckpointCount(for: task))
        }
    }

    @Test func petProfileCompletesAfterAnyThreeQuestionsAndSkipsAnsweredCards() {
        let completed: Set<HouseholdStarterJourneyCheckpoint> = [
            .petLifeStage,
            .petPersonalityAppearance
        ]
        let guide = TaskCenterSystemJourneyGuide(
            task: .petProfile,
            completedCheckpoints: completed,
            availableResolutionCheckpoints: Set(HouseholdStarterJourneyTask.petProfile.checkpoints)
        )

        #expect(guide.completedCheckpointCount == 2)
        #expect(guide.initialQuestionIndex == 1)
        #expect(guide.nextIncompleteQuestionIndex(after: 1) == 3)

        let completedGuide = TaskCenterSystemJourneyGuide(
            task: .petProfile,
            completedCheckpoints: completed.union([.petBodyProfile]),
            availableResolutionCheckpoints: Set(HouseholdStarterJourneyTask.petProfile.checkpoints)
        )
        #expect(completedGuide.isComplete)
        #expect(completedGuide.completedCheckpointCount == 3)
        #expect(completedGuide.nextIncompleteQuestionIndex(after: 1) == nil)
    }

    @Test func privacyChoicesStayCheckpointScopedAndFirstCareHasNoShortcut() throws {
        let human = TaskCenterSystemJourneyGuide(
            task: .humanProfile,
            availableResolutionCheckpoints: Set(HouseholdStarterJourneyTask.humanProfile.checkpoints)
        )
        let appearance = try #require(human.questions.first)
        #expect(human.allowedResolutions(for: appearance) == [.reviewed, .preferNotToSay])

        let optionalDetails = try #require(human.questions.last)
        #expect(human.allowedResolutions(for: optionalDetails) == [.reviewed, .unknown, .notApplicable, .preferNotToSay])

        let firstCare = TaskCenterSystemJourneyGuide(task: .firstCare)
        let action = try #require(firstCare.questions.first)
        #expect(action.checkpoint == nil)
        #expect(firstCare.allowedResolutions(for: action).isEmpty)
        #expect(!firstCare.isComplete)
    }

    @Test func everyResolutionWhitelistUsesTheExplicitCheckpointPolicyInStableOrder() throws {
        let expected: [
            HouseholdStarterJourneyCheckpoint: [HouseholdStarterJourneyResolution]
        ] = [
            .humanAppearance: [.reviewed, .preferNotToSay],
            .humanLifeStage: [],
            .humanBodyProfile: [],
            .humanPersonalityContext: [.reviewed, .unknown, .notApplicable, .preferNotToSay],
            .humanOptionalDetails: [.reviewed, .unknown, .notApplicable, .preferNotToSay],
            .petLifeStage: [.reviewed, .unknown, .notApplicable, .preferNotToSay],
            .petBodyProfile: [.reviewed, .unknown, .notApplicable, .preferNotToSay],
            .petPersonalityAppearance: [.reviewed, .unknown, .notApplicable, .preferNotToSay],
            .petDailyCare: [.reviewed, .unknown, .notApplicable, .preferNotToSay],
            .petIdentityDocuments: [.reviewed, .unknown, .notApplicable, .preferNotToSay],
            .petEmergencyContact: [.reviewed, .unknown, .notApplicable, .preferNotToSay],
            .petHealthProtection: [.reviewed, .unknown, .notApplicable, .preferNotToSay],
            .acceptedRecommendedCarePlan: []
        ]

        for checkpoint in HouseholdStarterJourneyTask.allCases.flatMap(\.checkpoints) {
            let guide = TaskCenterSystemJourneyGuide(
                task: checkpoint.task,
                availableResolutionCheckpoints: [checkpoint]
            )
            let question = try #require(
                guide.questions.first(where: { $0.checkpoint == checkpoint })
            )
            #expect(guide.allowedResolutions(for: question) == expected[checkpoint])
        }
    }

    @Test func everyThreeOfFourPetProfileAnswerPathCompletesButEveryTwoAnswerPathStaysOpen() {
        let checkpoints = HouseholdStarterJourneyTask.petProfile.checkpoints

        for omitted in checkpoints {
            let completed = Set(checkpoints.filter { $0 != omitted })
            let guide = TaskCenterSystemJourneyGuide(
                task: .petProfile,
                completedCheckpoints: completed,
                availableResolutionCheckpoints: Set(checkpoints)
            )
            #expect(guide.completedCheckpointCount == 3)
            #expect(guide.isComplete)
            #expect(guide.nextIncompleteQuestionIndex(after: 0) == nil)
        }

        for firstIndex in checkpoints.indices {
            for secondIndex in checkpoints.indices where secondIndex > firstIndex {
                let guide = TaskCenterSystemJourneyGuide(
                    task: .petProfile,
                    completedCheckpoints: [checkpoints[firstIndex], checkpoints[secondIndex]],
                    availableResolutionCheckpoints: Set(checkpoints)
                )
                #expect(guide.completedCheckpointCount == 2)
                #expect(!guide.isComplete)
                let nextIndex = guide.nextIncompleteQuestionIndex(after: secondIndex)
                #expect(nextIndex != nil)
                if let nextIndex {
                    #expect(!guide.isCompleted(guide.questions[nextIndex]))
                }
            }
        }
    }

    @Test func humanProfileNeedsBirthdayAndGenderEvenAtSeventyFivePercent() {
        let required = HouseholdStarterJourneyTask.humanProfile.requiredActualCheckpoints
        #expect(required == [.humanLifeStage, .humanBodyProfile])

        for optional in [
            HouseholdStarterJourneyCheckpoint.humanAppearance,
            .humanPersonalityContext
        ] {
            let guide = TaskCenterSystemJourneyGuide(
                task: .humanProfile,
                completedCheckpoints: required.union([optional]),
                availableResolutionCheckpoints: Set(
                    HouseholdStarterJourneyTask.humanProfile.checkpoints
                )
            )
            #expect(guide.completedCheckpointCount == 3)
            #expect(guide.isComplete)
        }

        for missingRequired in required {
            let completed = Set(
                HouseholdStarterJourneyTask.humanProfile.checkpoints
                    .filter { $0 != missingRequired }
            )
            let guide = TaskCenterSystemJourneyGuide(
                task: .humanProfile,
                completedCheckpoints: completed,
                availableResolutionCheckpoints: Set(
                    HouseholdStarterJourneyTask.humanProfile.checkpoints
                )
            )
            #expect(guide.completedCheckpointCount == 3)
            #expect(!guide.isComplete)
        }
    }

    @Test func incompleteQuestionNavigationClampsAndWrapsWithoutReopeningAnsweredCards() {
        let guide = TaskCenterSystemJourneyGuide(
            task: .humanProfile,
            completedCheckpoints: [.humanAppearance],
            availableResolutionCheckpoints: Set(HouseholdStarterJourneyTask.humanProfile.checkpoints)
        )

        #expect(guide.initialQuestionIndex == 1)
        #expect(guide.nextIncompleteQuestionIndex(after: -100) == 1)
        #expect(guide.nextIncompleteQuestionIndex(after: 100) == 1)
    }

    @Test func persistedProgressAndLocalAnswersMergeWithoutExceedingRequirement() {
        let guide = TaskCenterSystemJourneyGuide(
            task: .humanProfile,
            persistedCompletedCheckpointCount: 1,
            completedCheckpoints: [.humanAppearance, .humanLifeStage, .humanBodyProfile],
            availableResolutionCheckpoints: Set(HouseholdStarterJourneyTask.humanProfile.checkpoints)
        )

        #expect(guide.completedCheckpointCount == 3)
        #expect(guide.isComplete)
    }

    @Test func profileGuideReportsRealPercentageAndCompletesAtSeventyFivePercent() {
        let state = HouseholdStarterJourneyTaskState(
            task: .humanProfile,
            status: .actionRequired,
            rewardCoconuts: 100,
            completedCheckpointCount: 2,
            requiredCheckpointCount: 3,
            completionPercent: 50,
            requiredCompletionPercent: 75,
            targetID: UUID(),
            completedCheckpoints: [.humanAppearance, .humanLifeStage],
            checkpointResolutions: [:],
            availableResolutionCheckpoints: Set(HouseholdStarterJourneyTask.humanProfile.checkpoints)
        )

        let pending = TaskCenterSystemJourneyGuide(state: state)
        #expect(pending.completionPercent == 50)
        #expect(!pending.isComplete)

        let complete = TaskCenterSystemJourneyGuide(
            state: state,
            locallyCompletedCheckpoints: [.humanBodyProfile]
        )
        #expect(complete.completionPercent == 75)
        #expect(complete.isComplete)
    }

    @Test func eachQuestionRoutesToThePageThatCanAnswerIt() throws {
        let expected: [HouseholdStarterJourneyCheckpoint: TaskCenterSystemDestination] = [
            .humanAppearance: .completeHumanProfile,
            .humanLifeStage: .completeHumanProfile,
            .humanBodyProfile: .completeHumanProfile,
            .humanPersonalityContext: .completeHumanProfile,
            .petLifeStage: .completeFirstPetProfile,
            .petBodyProfile: .completeFirstPetProfile,
            .petPersonalityAppearance: .completeFirstPetProfile,
            .petDailyCare: .configureFirstCarePlan,
            .petIdentityDocuments: .confirmPetIdentityProtection,
            .petEmergencyContact: .completeFirstPetProfile,
            .petHealthProtection: .confirmPetPreventiveCare,
            .acceptedRecommendedCarePlan: .configureFirstCarePlan
        ]

        for checkpoint in HouseholdStarterJourneyTask.allCases.flatMap(\.checkpoints) {
            let guide = TaskCenterSystemJourneyGuide(task: checkpoint.task)
            let question = try #require(guide.questions.first(where: { $0.checkpoint == checkpoint }))
            #expect(guide.systemDestination(for: question) == expected[checkpoint])
        }

        let firstCare = TaskCenterSystemJourneyGuide(task: .firstCare)
        let firstCareQuestion = try #require(firstCare.questions.first)
        #expect(firstCare.systemDestination(for: firstCareQuestion) == .recordFirstCare)
    }

    @Test func carePlanNeverOffersAResolutionShortcut() throws {
        let unavailable = TaskCenterSystemJourneyGuide(task: .carePlan)
        let unavailableQuestion = try #require(unavailable.questions.first)
        #expect(unavailable.allowedResolutions(for: unavailableQuestion).isEmpty)

        let available = TaskCenterSystemJourneyGuide(
            task: .carePlan,
            availableResolutionCheckpoints: [.acceptedRecommendedCarePlan]
        )
        let availableQuestion = try #require(available.questions.first)
        #expect(available.allowedResolutions(for: availableQuestion).isEmpty)
    }

    @Test func actionRequiredSheetNeverHotSwitchesIntoRewardClaim() {
        #expect(
            TaskCenterSystemJourneySheetMode.resolve(
                openedAs: .actionRequired,
                guideIsComplete: true
            ) == .completedThisSession
        )
        #expect(
            TaskCenterSystemJourneySheetMode.resolve(
                openedAs: .rewardReady,
                guideIsComplete: true
            ) == .rewardClaim
        )
    }

    @Test func sheetModeCoversFreshCompletedAndRewardReadyPresentationPaths() {
        #expect(TaskCenterSystemJourneySheetMode.resolve(openedAs: nil, guideIsComplete: false) == .questions)
        #expect(TaskCenterSystemJourneySheetMode.resolve(openedAs: nil, guideIsComplete: true) == .completedThisSession)
        #expect(
            TaskCenterSystemJourneySheetMode.resolve(
                openedAs: .actionRequired,
                guideIsComplete: false
            ) == .questions
        )
    }

    @Test func rewardReadyStarterRowsClaimDirectlyWhileSetupAndStarterGiftStillOpenTheirDestinations() {
        let directClaimDestinations: [TaskCenterSystemDestination] = [
            .completeHumanProfile,
            .completeFirstPetProfile,
            .confirmPetIdentityProtection,
            .confirmPetPreventiveCare,
            .configureFirstCarePlan,
            .recordFirstCare
        ]

        for destination in directClaimDestinations {
            #expect(TaskCenterSystemJourneyRowActionPolicy.resolve(
                destination: destination,
                presentationState: .rewardReady
            ) == .claimReward)
            #expect(TaskCenterSystemJourneyRowActionPolicy.resolve(
                destination: destination,
                presentationState: .actionRequired
            ) == .openDestination)
        }

        #expect(TaskCenterSystemJourneyRowActionPolicy.resolve(
            destination: .claimStarterGift,
            presentationState: .rewardReady
        ) == .openDestination)
    }

    @Test func editorReturnsOnlyAfterItsRealCheckpointCompletes() {
        let documentState = makeState(
            task: .identityProtection,
            status: .actionRequired,
            completed: [.petIdentityDocuments]
        )
        #expect(TaskCenterSystemJourneyEditorCompletionPolicy.shouldDismissEditor(
            task: .identityProtection,
            checkpoint: .petIdentityDocuments,
            state: documentState
        ))
        #expect(!TaskCenterSystemJourneyEditorCompletionPolicy.shouldDismissEditor(
            task: .identityProtection,
            checkpoint: .petEmergencyContact,
            state: documentState
        ))

        let firstCareReady = makeState(task: .firstCare, status: .claimable)
        #expect(TaskCenterSystemJourneyEditorCompletionPolicy.shouldDismissEditor(
            task: .firstCare,
            checkpoint: nil,
            state: firstCareReady
        ))
        #expect(!TaskCenterSystemJourneyEditorCompletionPolicy.shouldDismissEditor(
            task: .firstCare,
            checkpoint: nil,
            state: makeState(task: .firstCare, status: .actionRequired)
        ))
        #expect(TaskCenterSystemJourneyEditorCompletionPolicy.shouldDismissEditor(
            task: .firstCare,
            checkpoint: nil,
            state: makeState(task: .firstCare, status: .claimed)
        ))
        #expect(!TaskCenterSystemJourneyEditorCompletionPolicy.shouldDismissEditor(
            task: .healthProtection,
            checkpoint: .petHealthProtection,
            state: documentState
        ))
    }

    private func makeState(
        task: HouseholdStarterJourneyTask,
        status: HouseholdStarterJourneyTaskState.Status,
        completed: Set<HouseholdStarterJourneyCheckpoint> = []
    ) -> HouseholdStarterJourneyTaskState {
        HouseholdStarterJourneyTaskState(
            task: task,
            status: status,
            rewardCoconuts: task.rewardCoconuts,
            completedCheckpointCount: completed.count,
            requiredCheckpointCount: HouseholdStarterJourneyPolicy.requiredCheckpointCount(for: task),
            targetID: nil,
            completedCheckpoints: completed,
            checkpointResolutions: [:]
        )
    }

    private func localDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar.current
        components.timeZone = Calendar.current.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return components.date ?? Date(timeIntervalSince1970: 0)
    }
}
