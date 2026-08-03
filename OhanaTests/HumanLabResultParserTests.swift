import Foundation
import Testing
@testable import Ohana

@MainActor
struct HumanLabResultParserTests {
    @Test func parsesChineseEnglishAndGermanTableRows() throws {
        let page = makePage(rows: [
            ["促甲状腺激素 TSH", "6.20", "mIU/L", "0.40–4.00", "H"],
            ["HbA1c", "5.4", "%", "4.0-5.6", "Normal"],
            ["Kreatinin", "0,82", "mg/dL", "0,60-1,20", "N"]
        ])

        let outcome = HumanLabResultParser().parse(pages: [page])
        let results = outcome.candidates
        let tsh = try #require(results.first { $0.metricKey == "tsh" })
        let hba1c = try #require(results.first { $0.metricKey == "hba1c" })
        let creatinine = try #require(results.first { $0.metricKey == "creatinine" })

        #expect(tsh.value == 6.2)
        #expect(tsh.unitCode == "mIU_L")
        #expect(tsh.referenceLow == 0.4)
        #expect(tsh.referenceHigh == 4.0)
        #expect(tsh.reportedFlag == .high)
        #expect(!tsh.isSelected)
        #expect(!tsh.hasBeenReviewed)
        #expect(!tsh.requiresReview)

        #expect(hba1c.value == 5.4)
        #expect(hba1c.unitCode == "percent")
        #expect(hba1c.reportedFlag == .normal)

        #expect(creatinine.value == 0.82)
        #expect(creatinine.referenceLow == 0.6)
        #expect(creatinine.referenceHigh == 1.2)
        #expect(creatinine.reportedFlag == .normal)
        #expect(results.allSatisfy { !$0.isSelected && !$0.hasBeenReviewed })
        #expect(!outcome.wasTruncated)
    }

    @Test func transcriptFallbackDoesNotTreatDigitsInMetricNamesAsValues() throws {
        let page = HumanLabOCRPage(
            pageIndex: 0,
            transcript: """
            FT4 16.8 pmol/L 12-22 N
            25(OH)D 42 ng/mL 30-100
            """,
            confidence: 0.96
        )

        let results = HumanLabResultParser().parse(pages: [page]).candidates
        let freeT4 = try #require(results.first { $0.metricKey == "ft4" })
        let vitaminD = try #require(results.first { $0.metricKey == "vitamin_d" })

        #expect(freeT4.value == 16.8)
        #expect(freeT4.referenceLow == 12)
        #expect(freeT4.referenceHigh == 22)
        #expect(vitaminD.value == 42)
        #expect(vitaminD.referenceLow == 30)
        #expect(vitaminD.referenceHigh == 100)
    }

    @Test func hyphenated25OHLabelNumberIsNotUsedAsTheResult() throws {
        let page = HumanLabOCRPage(
            pageIndex: 0,
            transcript: "Vitamin D (25-OH) 42 ng/mL 30-100",
            confidence: 0.99
        )

        let result = try #require(
            HumanLabResultParser().parse(pages: [page]).candidates.first {
                $0.metricKey == "vitamin_d"
            }
        )

        #expect(result.value == 42)
        #expect(result.referenceLow == 30)
        #expect(result.referenceHigh == 100)
    }

    @Test func qualifiedValueIsKeptButNeverAutomaticallySelected() throws {
        let page = makePage(rows: [
            ["Anti-TPO", "< 5", "IU/mL", "< 34"]
        ])

        let result = try #require(HumanLabResultParser().parse(pages: [page]).candidates.first)

        #expect(result.metricKey == "tpo_ab")
        #expect(result.value == 5)
        #expect(result.valueQualifier == .lessThan)
        #expect(result.referenceLow == nil)
        #expect(result.referenceHigh == 34)
        #expect(!result.isSelected)
        #expect(result.requiresReview)
    }

    @Test func loneComparatorWithoutAResultUnitIsNotUsedAsTheResult() {
        let page = makePage(rows: [
            ["Anti-TPO", "< 34"]
        ])

        let results = HumanLabResultParser().parse(pages: [page]).candidates

        #expect(results.isEmpty)
    }

    @Test func loneQualifiedValueWithAnExplicitUnitIsKeptForReview() throws {
        let page = makePage(rows: [
            ["Anti-TPO", "< 5 IU/mL"]
        ])

        let result = try #require(HumanLabResultParser().parse(pages: [page]).candidates.first)

        #expect(result.metricKey == "tpo_ab")
        #expect(result.value == 5)
        #expect(result.valueQualifier == .lessThan)
        #expect(result.referenceLow == nil)
        #expect(result.referenceHigh == nil)
        #expect(result.requiresReview)
    }

    @Test func lowConfidenceAndAmbiguousAliasRequireReview() throws {
        let lowConfidence = makePage(
            rows: [["TSH", "2.1", "mIU/L", "0.4-4.0"]],
            confidence: 0.60
        )
        let ambiguousAlias = makePage(rows: [
            ["GLU", "5.2", "mmol/L", "3.9-6.1"]
        ])

        let lowResult = try #require(HumanLabResultParser().parse(pages: [lowConfidence]).candidates.first)
        let aliasResult = try #require(HumanLabResultParser().parse(pages: [ambiguousAlias]).candidates.first)

        #expect(lowResult.metricKey == "tsh")
        #expect(!lowResult.isSelected)
        #expect(lowResult.requiresReview)
        #expect(aliasResult.metricKey == "fbg")
        #expect(!aliasResult.isSelected)
        #expect(aliasResult.requiresReview)
    }

    @Test func ambiguousThousandsOrDecimalSeparatorRequiresReview() throws {
        let page = makePage(rows: [
            ["TSH", "1,234", "mIU/L", "0,4-4,0"]
        ])

        let result = try #require(HumanLabResultParser().parse(pages: [page]).candidates.first)

        #expect(result.value == 1.234)
        #expect(!result.isSelected)
        #expect(result.requiresReview)
    }

    @Test func unknownStructuredResultIsRetainedForManualMapping() throws {
        let page = makePage(rows: [
            ["Apolipoprotein B", "1.20", "g/L", "0.60-1.30", "H"]
        ])

        let result = try #require(HumanLabResultParser().parse(pages: [page]).candidates.first)

        #expect(result.sourceLabel == "Apolipoprotein B")
        #expect(result.metricKey == nil)
        #expect(result.value == 1.2)
        #expect(result.referenceLow == 0.6)
        #expect(result.referenceHigh == 1.3)
        #expect(result.reportedFlag == .high)
        #expect(!result.isSelected)
        #expect(result.requiresReview)
    }

    @Test func repeatedTableAndTranscriptRowsAreDeduplicated() {
        let page = HumanLabOCRPage(
            pageIndex: 0,
            transcript: "TSH 6.20 mIU/L 0.40-4.00 H",
            confidence: 0.97,
            tables: [makeTable(rows: [
                ["TSH", "6.20", "mIU/L", "0.40-4.00", "H"]
            ])]
        )

        let results = HumanLabResultParser().parse(pages: [page]).candidates

        #expect(results.count == 1)
        #expect(results.first?.metricKey == "tsh")
    }

    @Test func parserHonorsConfiguredCandidateLimit() {
        let transcript = (0 ..< 12)
            .map { "TSH \(Double($0) + 1.1) mIU/L 0.4-4.0" }
            .joined(separator: "\n")
        let page = HumanLabOCRPage(
            pageIndex: 0,
            transcript: transcript,
            confidence: 0.99
        )

        let outcome = HumanLabResultParser(maximumCandidateCount: 5).parse(pages: [page])

        #expect(outcome.candidates.count == 5)
        #expect(outcome.wasTruncated)
    }

    @Test func shortAliasesRequireWholeTokensAndBloodCountUnitNormalizes() throws {
        let page = makePage(rows: [
            ["Albumin result", "42", "g/L", "35-55"],
            ["WBC", "6.2", "×10⁹/L", "3.5-9.5"]
        ])

        let results = HumanLabResultParser().parse(pages: [page]).candidates
        let albumin = try #require(results.first { $0.sourceLabel == "Albumin result" })
        let wbc = try #require(results.first { $0.metricKey == "wbc" })

        #expect(albumin.metricKey == "alb")
        #expect(albumin.metricKey != "k")
        #expect(wbc.unitCode == "x10_9_L")
        #expect(!wbc.isSelected)
        #expect(!wbc.hasBeenReviewed)
        #expect(!wbc.requiresReview)
    }

    @Test func lineGeometrySeparatesMultipleDatesReferencesZeroAndPrintedFlags() throws {
        let page = makeLineGeometryPage(textLines: [
            geometryLine("Parameter", centerX: 0.18, centerY: 0.94),
            geometryLine("Normwert", centerX: 0.55, centerY: 0.94),
            geometryLine("08.03.2025", centerX: 0.76, centerY: 0.94),
            geometryLine("07.03.2025", centerX: 0.90, centerY: 0.94),

            geometryLine("Gesamtcholesterin", centerX: 0.18, centerY: 0.82, width: 0.30),
            geometryLine("< 200 mg/dL", centerX: 0.55, centerY: 0.82),
            geometryLine("171 mg/dL", centerX: 0.76, centerY: 0.82),
            geometryLine("158 mg/dL", centerX: 0.90, centerY: 0.82),

            geometryLine("Triglyceride", centerX: 0.18, centerY: 0.73, width: 0.26),
            geometryLine("< 150 mg/dL", centerX: 0.55, centerY: 0.73),
            geometryLine("[+] 166 mg/dL", centerX: 0.76, centerY: 0.73),
            geometryLine("[-] 82 mg/dL", centerX: 0.90, centerY: 0.73),

            geometryLine("HIV-RNA", centerX: 0.18, centerY: 0.64),
            geometryLine("< 20 cp/mL", centerX: 0.55, centerY: 0.64),
            geometryLine("0 cp/mL", centerX: 0.76, centerY: 0.64),
            geometryLine("0 cp/mL", centerX: 0.90, centerY: 0.64)
        ])

        let results = HumanLabResultParser().parse(pages: [page]).candidates
        let cholesterol = results.filter { $0.metricKey == "tc" }
        let triglycerides = results.filter { $0.metricKey == "tg" }
        let viralLoads = results.filter { $0.metricKey == "hiv_rna" }

        #expect(cholesterol.count == 2)
        #expect(cholesterol.compactMap(\.value) == [171, 158])
        #expect(cholesterol.allSatisfy { $0.referenceHigh == 200 })
        #expect(!cholesterol.contains { $0.value == 200 })
        #expect(triglycerides.count == 2)
        #expect(triglycerides.compactMap(\.value) == [166, 82])
        #expect(triglycerides.map(\.reportedFlag) == [.high, .low])
        #expect(triglycerides.allSatisfy { $0.referenceHigh == 150 })
        #expect(viralLoads.count == 2)
        #expect(viralLoads.allSatisfy { $0.value == 0 })
        #expect(viralLoads.allSatisfy { $0.referenceHigh == 20 })

        let newerDate = try #require(cholesterol.first?.observedAt)
        let olderDate = try #require(cholesterol.last?.observedAt)
        #expect(dateComponents(newerDate) == DateComponents(year: 2025, month: 3, day: 8))
        #expect(dateComponents(olderDate) == DateComponents(year: 2025, month: 3, day: 7))
    }

    @Test func lineGeometryUsesPrintedPositionsForWrappedAndShiftedRows() throws {
        let scrambledRows = [
            ["Erythrozyten", "< 15 %", "30.6 g/dL"],
            ["Mittleres Thrombozytenvolumen", "7.5-12.5 fL", "13.1 %"]
        ]
        let page = makeLineGeometryPage(
            tableRows: scrambledRows,
            textLines: [
                geometryLine("Parameter", centerX: 0.18, centerY: 0.94),
                geometryLine("Normwert", centerX: 0.55, centerY: 0.94),
                geometryLine("12.04.2025", centerX: 0.82, centerY: 0.94),

                geometryLine(
                    "Erythrozytenverteilungsbreite",
                    centerX: 0.18,
                    centerY: 0.84,
                    width: 0.34
                ),
                geometryLine("(%)", centerX: 0.18, centerY: 0.818),
                geometryLine("11.5-15.0 %", centerX: 0.55, centerY: 0.818),
                geometryLine("13.1 %", centerX: 0.82, centerY: 0.818),

                geometryLine(
                    "Mittlere korpuskuläre Hämoglobinkonzentration",
                    centerX: 0.18,
                    centerY: 0.72,
                    width: 0.40
                ),
                geometryLine("(MCHC)", centerX: 0.18, centerY: 0.698),
                geometryLine("31.0-36.0 g/dL", centerX: 0.55, centerY: 0.698),
                geometryLine("L-] 30.6 g/dL", centerX: 0.82, centerY: 0.698),

                geometryLine(
                    "Mittleres Thrombozytenvolumen",
                    centerX: 0.18,
                    centerY: 0.60,
                    width: 0.34
                ),
                geometryLine("(MPV)", centerX: 0.18, centerY: 0.578),
                geometryLine("7.5-12.5 fL", centerX: 0.55, centerY: 0.578),
                geometryLine("10.4 fL", centerX: 0.82, centerY: 0.578)
            ]
        )

        let results = HumanLabResultParser().parse(pages: [page]).candidates
        let rdw = try #require(results.first { $0.metricKey == "rdw_cv" })
        let mchc = try #require(results.first { $0.metricKey == "mchc" })
        let mpv = try #require(results.first { $0.metricKey == "mpv" })

        #expect(rdw.value == 13.1)
        #expect(rdw.referenceLow == 11.5)
        #expect(rdw.referenceHigh == 15)
        #expect(mchc.value == 30.6)
        #expect(mchc.reportedFlag == .low)
        #expect(mpv.value == 10.4)
        #expect(results.first { $0.metricKey == "rbc" } == nil)
    }

    @Test func lineGeometryRetainsUnknownStructuredMetrics() throws {
        let page = makeLineGeometryPage(textLines: [
            geometryLine("Parameter", centerX: 0.18, centerY: 0.94),
            geometryLine("Normwert", centerX: 0.55, centerY: 0.94),
            geometryLine("12.04.2025", centerX: 0.82, centerY: 0.94),

            geometryLine("Apolipoprotein B", centerX: 0.18, centerY: 0.82),
            geometryLine("0.60-1.30 g/L", centerX: 0.55, centerY: 0.82),
            geometryLine("1.20 g/L", centerX: 0.82, centerY: 0.82)
        ])

        let result = try #require(HumanLabResultParser().parse(pages: [page]).candidates.first)

        #expect(result.sourceLabel == "Apolipoprotein B")
        #expect(result.metricKey == nil)
        #expect(result.value == 1.2)
        #expect(result.referenceLow == 0.6)
        #expect(result.referenceHigh == 1.3)
        #expect(result.requiresReview)
    }

    @Test func partialLineGeometrySafelySupplementsUncoveredTableRows() throws {
        let page = makeLineGeometryPage(
            tableRows: [
                ["TSH", "999", "mIU/L", "0.4-4.0"],
                ["Kreatinin", "0.82", "mg/dL", "0.6-1.2"],
                ["Apolipoprotein B", "1.20", "g/L", "0.60-1.30"]
            ],
            textLines: [
                geometryLine("Parameter", centerX: 0.18, centerY: 0.94),
                geometryLine("Normwert", centerX: 0.55, centerY: 0.94),
                geometryLine("12.04.2025", centerX: 0.82, centerY: 0.94),

                geometryLine("TSH", centerX: 0.18, centerY: 0.82),
                geometryLine("0.4-4.0 mIU/L", centerX: 0.55, centerY: 0.82),
                geometryLine("2.1 mIU/L", centerX: 0.82, centerY: 0.82)
            ]
        )

        let results = HumanLabResultParser().parse(pages: [page]).candidates
        let tshResults = results.filter { $0.metricKey == "tsh" }
        let creatinine = try #require(results.first { $0.metricKey == "creatinine" })
        let unknown = try #require(results.first { $0.sourceLabel == "Apolipoprotein B" })

        #expect(tshResults.count == 1)
        #expect(tshResults.first?.value == 2.1)
        #expect(creatinine.value == 0.82)
        #expect(creatinine.requiresReview)
        #expect(unknown.metricKey == nil)
        #expect(unknown.value == 1.2)
        #expect(unknown.requiresReview)
        #expect(results.count == 3)
    }

    @Test func lineGeometryConvertsMicroliterBloodCountsToCatalogUnits() throws {
        let page = makeLineGeometryPage(textLines: [
            geometryLine("Parameter", centerX: 0.18, centerY: 0.94),
            geometryLine("Normwert", centerX: 0.55, centerY: 0.94),
            geometryLine("21.05.2025", centerX: 0.82, centerY: 0.94),

            geometryLine("Leukozyten", centerX: 0.18, centerY: 0.82),
            geometryLine("3800-9800 /µL", centerX: 0.55, centerY: 0.82),
            geometryLine("6430 /µL", centerX: 0.82, centerY: 0.82),

            geometryLine("Erythrozyten", centerX: 0.18, centerY: 0.73),
            geometryLine("4.1-5.9 ×10⁶/µL", centerX: 0.55, centerY: 0.73),
            geometryLine("4.82 ×10⁶/µL", centerX: 0.82, centerY: 0.73),

            geometryLine("Thrombozyten", centerX: 0.18, centerY: 0.64),
            geometryLine("140000-360000 /µL", centerX: 0.55, centerY: 0.64),
            geometryLine("268000 /µL", centerX: 0.82, centerY: 0.64)
        ])

        let results = HumanLabResultParser().parse(pages: [page]).candidates
        let wbc = try #require(results.first { $0.metricKey == "wbc" })
        let rbc = try #require(results.first { $0.metricKey == "rbc" })
        let platelets = try #require(results.first { $0.metricKey == "plt" })

        #expect(abs((wbc.value ?? 0) - 6.43) < 0.000_001)
        #expect(wbc.unitCode == "x10_9_L")
        #expect(abs((wbc.referenceLow ?? 0) - 3.8) < 0.000_001)
        #expect(abs((wbc.referenceHigh ?? 0) - 9.8) < 0.000_001)
        #expect(rbc.value == 4.82)
        #expect(rbc.unitCode == "x10_12_L")
        #expect(abs((platelets.value ?? 0) - 268) < 0.000_001)
        #expect(platelets.unitCode == "x10_9_L")
        #expect(abs((platelets.referenceLow ?? 0) - 140) < 0.000_001)
        #expect(abs((platelets.referenceHigh ?? 0) - 360) < 0.000_001)
    }

    @Test func lineGeometryUsesResultBandForSplitUnitsAndPrefersRecognizableReferenceUnit() throws {
        let page = makeLineGeometryPage(textLines: [
            geometryLine("Parameter", centerX: 0.18, centerY: 0.94),
            geometryLine("Normwert", centerX: 0.55, centerY: 0.94),
            geometryLine("21.05.2025", centerX: 0.82, centerY: 0.94),

            geometryLine("akt T-Zellen abs", centerX: 0.18, centerY: 0.84),
            geometryLine("/uL", centerX: 0.18, centerY: 0.825),
            geometryLine("100-250 /xL", centerX: 0.55, centerY: 0.84),
            geometryLine("100-250 /uL", centerX: 0.55, centerY: 0.836),
            geometryLine("210", centerX: 0.82, centerY: 0.84),

            geometryLine("akt T-Zellen rel", centerX: 0.18, centerY: 0.816),
            geometryLine("0-15 %", centerX: 0.55, centerY: 0.816),
            geometryLine("7 %", centerX: 0.82, centerY: 0.816)
        ])

        let results = HumanLabResultParser().parse(pages: [page]).candidates
        let absolute = try #require(results.first { $0.metricKey == "activated_t_cells_abs" })
        let relative = try #require(results.first { $0.metricKey == "activated_t_cells_pct" })

        #expect(absolute.value == 210)
        #expect(absolute.unitCode == "per_uL")
        #expect(absolute.referenceLow == 100)
        #expect(absolute.referenceHigh == 250)
        #expect(relative.value == 7)
        #expect(relative.unitCode == "percent")
    }

    @Test func lineGeometryPreservesSyntheticSecondPageChemistryOrder() {
        let rows: [(label: String, reference: String, value: String)] = [
            ("Aspartat-Aminotransferase", "< 35 U/L", "26 U/L"),
            ("Alanin-Aminotransferase", "< 45 U/L", "24 U/L"),
            ("Gamma-GT", "< 55 U/L", "15 U/L"),
            ("Bilirubin gesamt", "< 1.2 mg/dL", "0.6 mg/dL"),
            ("Laktatdehydrogenase", "120-250 U/L", "175 U/L"),
            ("Alkalische Phosphatase", "40-130 U/L", "64 U/L"),
            ("Amylase", "28-100 U/L", "[+] 112 U/L"),
            ("Natrium", "135-145 mmol/L", "140 mmol/L"),
            ("Kalium", "3.5-5.3 mmol/L", "4.2 mmol/L"),
            ("Kalzium", "2.1-2.6 mmol/L", "2.36 mmol/L"),
            ("Kreatinin", "0.6-1.2 mg/dL", "0.96 mg/dL"),
            ("eGFR", "> 90 mL/min/1.73m²", "[-] 86 mL/min/1.73m²"),
            ("Harnstoff", "17-43 mg/dL", "28 mg/dL"),
            ("Harnsäure", "2.6-7.0 mg/dL", "4.8 mg/dL"),
            ("Gesamtprotein", "6.4-8.3 g/dL", "7.2 g/dL"),
            ("Gesamtcholesterin", "< 200 mg/dL", "176 mg/dL"),
            ("Triglyceride", "< 150 mg/dL", "121 mg/dL"),
            ("Glukose", "70-110 mg/dL", "92 mg/dL"),
            ("TSH", "0.4-4.0 mIU/L", "2.1 mIU/L"),
            ("Freies T3", "2.0-4.4 pg/mL", "3.4 pg/mL"),
            ("Freies T4", "0.8-1.8 ng/dL", "1.2 ng/dL")
        ]
        var lines = [
            geometryLine("Parameter", centerX: 0.18, centerY: 0.965),
            geometryLine("Normwert", centerX: 0.55, centerY: 0.965),
            geometryLine("02.06.2025", centerX: 0.82, centerY: 0.965)
        ]
        for (index, row) in rows.enumerated() {
            let centerY = 0.91 - Double(index) * 0.037
            lines.append(geometryLine(row.label, centerX: 0.18, centerY: centerY, width: 0.36))
            lines.append(geometryLine(row.reference, centerX: 0.55, centerY: centerY, width: 0.18))
            lines.append(geometryLine(row.value, centerX: 0.82, centerY: centerY, width: 0.18))
        }
        let page = makeLineGeometryPage(pageIndex: 1, textLines: lines)

        let results = HumanLabResultParser().parse(pages: [page]).candidates

        #expect(results.count == rows.count)
        #expect(results.compactMap(\.metricKey) == [
            "ast", "alt", "ggt", "tbil", "ldh", "alp", "amylase",
            "na", "k", "ca", "creatinine", "egfr", "urea", "uric_acid",
            "total_protein", "tc", "tg", "glucose", "tsh", "ft3", "ft4"
        ])
        #expect(results.allSatisfy { $0.pageIndex == 1 })
        #expect(results.first { $0.metricKey == "amylase" }?.reportedFlag == .high)
        #expect(results.first { $0.metricKey == "egfr" }?.reportedFlag == .low)
    }

    private func makePage(
        rows: [[String]],
        confidence: Float = 0.98
    ) -> HumanLabOCRPage {
        HumanLabOCRPage(
            pageIndex: 0,
            transcript: "",
            confidence: confidence,
            tables: [makeTable(rows: rows, confidence: confidence)]
        )
    }

    private func makeTable(
        rows: [[String]],
        confidence: Float = 0.98
    ) -> HumanLabOCRTable {
        HumanLabOCRTable(rows: rows.map { row in
            row.enumerated().map { columnIndex, text in
                HumanLabOCRCell(
                    text: text,
                    confidence: confidence,
                    columnRange: columnIndex ... columnIndex
                )
            }
        })
    }

    private func makeLineGeometryPage(
        pageIndex: Int = 0,
        tableRows: [[String]] = [],
        textLines: [HumanLabOCRTextLine]
    ) -> HumanLabOCRPage {
        HumanLabOCRPage(
            pageIndex: pageIndex,
            transcript: "",
            confidence: 0.99,
            tables: [HumanLabOCRTable(
                rows: tableRows.map { row in
                    row.enumerated().map { columnIndex, text in
                        HumanLabOCRCell(
                            text: text,
                            confidence: 0.99,
                            columnRange: columnIndex ... columnIndex
                        )
                    }
                },
                bounds: HumanLabOCRBounds(
                    minX: 0.02,
                    minY: 0.08,
                    width: 0.96,
                    height: 0.90
                )
            )],
            textLines: textLines
        )
    }

    private func geometryLine(
        _ text: String,
        centerX: Double,
        centerY: Double,
        width: Double = 0.16,
        height: Double = 0.014,
        confidence: Float = 0.99
    ) -> HumanLabOCRTextLine {
        HumanLabOCRTextLine(
            text: text,
            confidence: confidence,
            bounds: HumanLabOCRBounds(
                minX: centerX - width / 2,
                minY: centerY - height / 2,
                width: width,
                height: height
            )
        )
    }

    private func dateComponents(_ date: Date) -> DateComponents {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.dateComponents([.year, .month, .day], from: date)
    }
}
