import Foundation

extension Notification.Name {
    static let examDataUpdated = Notification.Name("examDataUpdated")
}

/// Manages Full-Length Exams, Chapter-Wise Tests, Section-Wise Practice, and Exam History,
/// reusing the existing Vocabulary / Grammar / Particle learning data and SRS review engine.
final class ExamService {
    static let shared = ExamService()

    private let attemptsStorageKey = "farki_exam_attempts_v1"
    private let answerKeyCacheStorageKey = "farki_exam_answer_keys_v1"

    private(set) var fullLengthExams: [ExamPaper] = []
    private(set) var sectionPapers: [ExamPaper] = []
    private(set) var chapterPapers: [ExamPaper] = []
    private(set) var originalQuestionBank: [ExamQuestion] = []
    private(set) var attempts: [ExamAttempt] = []
    private var dynamicQuestionRegistry: [String: ExamQuestion] = [:]
    private var recordedSRSAttemptQuestionPairs: Set<String> = []

    let externalResources: [ExamExternalResource] = [
        ExamExternalResource(
            id: "minna-no-nihongo-anki-mit",
            title: "Minna no Nihongo I & II Lessons 1–50 Dataset (Bundled)",
            levelLabel: "Ch. 1–50 (MIT)",
            urlString: "https://github.com/k1ng440/minna-no-nihongo-anki",
            licenseNote: "MIT License — All 2,156 vocabulary words & Tatoeba sentences across Lessons 1–50",
            attribution: "Copyright (c) 2026 Asaduzzaman Pavel & Tatoeba contributors",
            dateChecked: "2026-10-28"
        ),
        ExamExternalResource(
            id: "noken-minna-lessons",
            title: "Noken Minna no Nihongo Lesson Grammar (Bundled)",
            levelLabel: "Ch. 1–25 Grammar",
            urlString: "https://github.com/bonavida/noken",
            licenseNote: "Open-Source Lesson-by-Lesson Grammar & Examples (Lessons 1–25)",
            attribution: "bonavida/noken contributors",
            dateChecked: "2026-10-28"
        ),
        ExamExternalResource(
            id: "jlpt-success-open",
            title: "JLPTSuccess Open-Source Paper Bank (Bundled)",
            levelLabel: "N5 / N4 (MIT)",
            urlString: "https://github.com/gauravhq/JLPTSuccess",
            licenseNote: "MIT License — Bundled 7 N5 papers + N4 Moji, Reading & Listening",
            attribution: "Copyright (c) 2026 JLPTSuccess contributors",
            dateChecked: "2026-10-28"
        ),
        ExamExternalResource(
            id: "open-jlpt-dataset",
            title: "OpenJLPT Grammar & Vocabulary Dataset (Bundled)",
            levelLabel: "N5 / N4 (CC-BY-SA-4.0)",
            urlString: "https://github.com/evanclan/OpenJLPT",
            licenseNote: "Creative Commons Attribution-ShareAlike 4.0 International (with Tatoeba examples)",
            attribution: "OpenJLPT Contributors & Tatoeba Project",
            dateChecked: "2026-10-28"
        ),
        ExamExternalResource(
            id: "jkindrix-japanese-data",
            title: "Japanese Language Data Curated Grammar (Bundled)",
            levelLabel: "N5 / N4 (CC-BY-SA-4.0)",
            urlString: "https://github.com/jkindrix/japanese-language-data",
            licenseNote: "CC-BY-SA-4.0 — Curated N5 & N4 grammar explanations and formations",
            attribution: "Copyright (c) 2026 Justin Kindrix and contributors",
            dateChecked: "2026-10-28"
        ),
        ExamExternalResource(
            id: "hanabira-japanese-content",
            title: "Hanabira.org Japanese Grammar Content (Bundled)",
            levelLabel: "N5 / N4 (CC-BY-4.0)",
            urlString: "https://github.com/tristcoil/hanabira.org-japanese-content",
            licenseNote: "Creative Commons Attribution 4.0 International",
            attribution: "Copyright (c) hanabira.org",
            dateChecked: "2026-10-28"
        ),
        ExamExternalResource(
            id: "jlpt-official-samples",
            title: "Official JLPT Sample Questions",
            levelLabel: "N5 / N4",
            urlString: "https://www.jlpt.jp/e/samples/forlearners.html",
            licenseNote: "Official Japan Foundation & JEES reference site (Link Out Only)",
            attribution: "The Japan Foundation / Japan Educational Exchanges and Services",
            dateChecked: "2026-10-28"
        ),
        ExamExternalResource(
            id: "jlpt-official-workbook",
            title: "Official JLPT Practice Workbooks",
            levelLabel: "N5 / N4",
            urlString: "https://www.jlpt.jp/e/samples/sampleindex.html",
            licenseNote: "Official workbook portal (Link Out Only)",
            attribution: "The Japan Foundation / JEES",
            dateChecked: "2026-10-28"
        ),
        ExamExternalResource(
            id: "tadoku-free-books",
            title: "Tadoku Graded Japanese Reading",
            levelLabel: "N5 / N4 Reading",
            urlString: "https://tadoku.org/japanese/en/free-books-en/",
            licenseNote: "NPO Tadoku Supporters (Link Out for full illustrated readers)",
            attribution: "NPO Tadoku Supporters",
            dateChecked: "2026-10-28"
        )
    ]

    private init() {
        buildOriginalQuestionBankAndPapers()
        loadBundledExamBank()
        loadDynamicQuestionCache()
        loadAttempts()
    }

    // MARK: - Load Bundled 80-Paper / 1,163-Question Exam Bank (jlpt_exam_bank.json)
    private func loadBundledExamBank() {
        guard let data = findExamBankJSONData(),
              let bank = try? JSONDecoder().decode(ExamBankDatabase.self, from: data) else {
            return
        }

        var existingIds = Set(originalQuestionBank.map(\.id))
        for q in bank.questions {
            dynamicQuestionRegistry[q.id] = q
            if !existingIds.contains(q.id) {
                originalQuestionBank.append(q)
                existingIds.insert(q.id)
            }
        }

        // Separate bundled papers by kind: full-length (12), section-wise (58), and chapter-wise (10)
        let bundledFullLength = bank.papers.filter { $0.kind == .fullLength }
        let bundledSection = bank.papers.filter { $0.kind == .section }
        let bundledChapter = bank.papers.filter { $0.kind == .chapter }

        var mergedFull: [ExamPaper] = bundledFullLength
        let bundledIds = Set(bundledFullLength.map(\.id))
        for p in fullLengthExams where !bundledIds.contains(p.id) {
            mergedFull.append(p)
        }
        self.fullLengthExams = mergedFull
        self.sectionPapers = bundledSection
        self.chapterPapers = bundledChapter
    }

    private func findExamBankJSONData() -> Data? {
        if let url = Bundle.main.url(forResource: "jlpt_exam_bank", withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        if let url = Bundle.main.url(forResource: "jlpt_exam_bank", withExtension: "json", subdirectory: "Exams"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        if let url = Bundle.main.url(forResource: "jlpt_exam_bank", withExtension: "json", subdirectory: "Resources/Exams"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        let thisFileUrl = URL(fileURLWithPath: #filePath)
        let candidatePath = thisFileUrl
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/Exams/jlpt_exam_bank.json")
        if let data = try? Data(contentsOf: candidatePath) {
            return data
        }
        let absolutePath = "/Users/static/Documents/projects/farki/Farki/Resources/Exams/jlpt_exam_bank.json"
        if let data = try? Data(contentsOf: URL(fileURLWithPath: absolutePath)) {
            return data
        }
        return nil
    }

    // MARK: - Persistence
    private func loadAttempts() {
        if let data = UserDefaults.standard.data(forKey: attemptsStorageKey),
           let decoded = try? JSONDecoder().decode([ExamAttempt].self, from: data) {
            self.attempts = decoded
        }
    }

    func saveAttempts() {
        if let encoded = try? JSONEncoder().encode(attempts) {
            UserDefaults.standard.set(encoded, forKey: attemptsStorageKey)
            NotificationCenter.default.post(name: .examDataUpdated, object: nil)
        }
    }

    private func loadDynamicQuestionCache() {
        if let data = UserDefaults.standard.data(forKey: answerKeyCacheStorageKey),
           let decoded = try? JSONDecoder().decode([String: ExamQuestion].self, from: data) {
            for (k, v) in decoded {
                dynamicQuestionRegistry[k] = v
            }
        }
    }

    private func saveDynamicQuestionCache() {
        if let encoded = try? JSONEncoder().encode(dynamicQuestionRegistry) {
            UserDefaults.standard.set(encoded, forKey: answerKeyCacheStorageKey)
        }
    }

    // MARK: - Question Lookup
    func verifiedQuestion(forId id: String) -> ExamQuestion? {
        if let q = dynamicQuestionRegistry[id] {
            return q
        }
        return originalQuestionBank.first { $0.id == id }
    }

    // MARK: - Available Chapters in In-App Learning Data & Bundled Chapter Papers
    var availableChapters: [Int] {
        let vocabCh = Set(VocabDataService.shared.items.map(\.chapterNumber))
        let grammarCh = Set(GrammarDataService.shared.grammarPoints.map(\.chapterNumber))
        let bankCh = Set(originalQuestionBank.flatMap(\.chapterIds))
        let combined = vocabCh.union(grammarCh).union(bankCh).filter { $0 > 0 }.sorted()
        return combined.isEmpty ? [1] : combined
    }

    /// Computes how many chapter-tagged questions can be generated strictly from the selected chapters, level, and categories.
    func availableChapterQuestions(
        level: JLPTLevel,
        chapters: Set<Int>,
        categories: Set<ExamQuestionCategory>
    ) -> [ExamQuestion] {
        guard !chapters.isEmpty, !categories.isEmpty else { return [] }
        var generated: [ExamQuestion] = []

        // 1. Vocabulary & Kanji questions strictly from VocabDataService items tagged to `chapters`
        let chapterVocab = VocabDataService.shared.items.filter { item in
            chapters.contains(item.chapterNumber) && (level == .all || item.jlptLevel == level)
        }

        let allMeaningsPool = VocabDataService.shared.items.map(\.meaning)
        let allKanaPool = VocabDataService.shared.items.map(\.kana)

        if categories.contains(.vocabulary) {
            for item in chapterVocab {
                let qId = "ch-vocab-\(item.id)"
                let choices = buildChoices(correct: item.meaning, pool: allMeaningsPool, seed: qId)
                let q = ExamQuestion(
                    id: qId,
                    reference: LearningItemReference(domain: .vocabulary, contentId: item.id),
                    level: item.jlptLevel,
                    category: .vocabulary,
                    sectionId: "sec-vocab",
                    passageGroupId: nil,
                    passageText: nil,
                    prompt: "What is the meaning of 「\(item.japanese)」?",
                    context: "Chapter \(item.chapterNumber) • \(item.wordType.description)",
                    audioScript: nil,
                    imageAsset: nil,
                    choices: choices,
                    correctAnswer: item.meaning,
                    explanation: "「\(item.japanese)」 (\(item.romaji)) means \"\(item.meaning)\" (Minna no Nihongo Ch. \(item.chapterNumber)).",
                    chapterIds: [item.chapterNumber],
                    sourceTitle: "In-App Vocabulary (Minna no Nihongo Ch. \(item.chapterNumber))",
                    sourceUrl: nil,
                    license: "In-App Study Data",
                    attribution: "nihon App Vocabulary Repository",
                    dateChecked: "2026-10-28"
                )
                generated.append(q)
                dynamicQuestionRegistry[q.id] = q
            }
        }

        if categories.contains(.kanji) {
            for item in chapterVocab {
                guard let kanji = item.kanji,
                      !kanji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      kanji != item.kana else {
                    continue
                }
                let qId = "ch-kanji-\(item.id)"
                let choices = buildChoices(correct: item.kana, pool: allKanaPool, seed: qId)
                let q = ExamQuestion(
                    id: qId,
                    reference: LearningItemReference(domain: .vocabulary, contentId: item.id),
                    level: item.jlptLevel,
                    category: .kanji,
                    sectionId: "sec-vocab",
                    passageGroupId: nil,
                    passageText: nil,
                    prompt: "Choose the correct hiragana reading for 「\(kanji)」.",
                    context: "Meaning: \(item.meaning) • Chapter \(item.chapterNumber)",
                    audioScript: nil,
                    imageAsset: nil,
                    choices: choices,
                    correctAnswer: item.kana,
                    explanation: "「\(kanji)」 is read as 「\(item.kana)」 (\(item.romaji)) and means \"\(item.meaning)\".",
                    chapterIds: [item.chapterNumber],
                    sourceTitle: "In-App Kanji / Vocabulary (Minna no Nihongo Ch. \(item.chapterNumber))",
                    sourceUrl: nil,
                    license: "In-App Study Data",
                    attribution: "nihon App Vocabulary Repository",
                    dateChecked: "2026-10-28"
                )
                generated.append(q)
                dynamicQuestionRegistry[q.id] = q
            }
        }

        // 2. Grammar questions strictly from GrammarDataService points tagged to `chapters`
        if categories.contains(.grammar) {
            let chapterGrammar = GrammarDataService.shared.grammarPoints.filter { pt in
                chapters.contains(pt.chapterNumber) && (level == .all || pt.jlptLevel == level || pt.jlptLevel == nil)
            }
            let grammarMeaningPool = GrammarDataService.shared.grammarPoints.map(\.meaning)
            let grammarFormPool = GrammarDataService.shared.grammarPoints.map(\.japanese)

            for pt in chapterGrammar {
                let qId = "ch-grammar-\(pt.id)"
                let choices = buildChoices(correct: pt.meaning, pool: grammarMeaningPool, seed: qId)
                let firstEx = pt.examples.first
                let q = ExamQuestion(
                    id: qId,
                    reference: LearningItemReference(domain: .grammar, contentId: pt.id),
                    level: pt.jlptLevel ?? level,
                    category: .grammar,
                    sectionId: "sec-grammar-reading",
                    passageGroupId: firstEx != nil ? "group-grammar-\(pt.id)" : nil,
                    passageText: firstEx?.japanese,
                    prompt: "What does the grammar pattern 「\(pt.pattern)」 (\(pt.japanese)) express?",
                    context: firstEx != nil ? "Example: \(firstEx!.japanese) (\(firstEx!.meaning))" : "Chapter \(pt.chapterNumber)",
                    audioScript: nil,
                    imageAsset: nil,
                    choices: choices,
                    correctAnswer: pt.meaning,
                    explanation: "\(pt.title): \(pt.explanation)",
                    chapterIds: [pt.chapterNumber],
                    sourceTitle: "In-App Grammar (Ch. \(pt.chapterNumber))",
                    sourceUrl: nil,
                    license: "In-App Study Data",
                    attribution: "nihon App Grammar Repository",
                    dateChecked: "2026-10-28"
                )
                generated.append(q)
                dynamicQuestionRegistry[q.id] = q

                for variant in pt.variants {
                    let vId = "ch-grammar-var-\(pt.id)-\(variant.id)"
                    let varChoices = buildChoices(
                        correct: variant.pattern,
                        pool: pt.variants.map(\.pattern) + grammarFormPool,
                        seed: vId
                    )
                    let varQ = ExamQuestion(
                        id: vId,
                        reference: LearningItemReference(domain: .grammar, contentId: pt.id, subContentId: variant.id),
                        level: pt.jlptLevel ?? level,
                        category: .grammar,
                        sectionId: "sec-grammar-reading",
                        passageGroupId: firstEx != nil ? "group-grammar-\(pt.id)" : nil,
                        passageText: variant.examples.first?.japanese ?? firstEx?.japanese,
                        prompt: "Select the \(variant.label) form for 「\(pt.title)」 (\(variant.meaning)).",
                        context: "Chapter \(pt.chapterNumber) • \(pt.categoryTag)",
                        audioScript: nil,
                        imageAsset: nil,
                        choices: varChoices,
                        correctAnswer: variant.pattern,
                        explanation: "\(variant.label): \(variant.pattern) (\(variant.romaji)) — \(variant.meaning).",
                        chapterIds: [pt.chapterNumber],
                        sourceTitle: "In-App Grammar Variants (Ch. \(pt.chapterNumber))",
                        sourceUrl: nil,
                        license: "In-App Study Data",
                        attribution: "nihon App Grammar Repository",
                        dateChecked: "2026-10-28"
                    )
                    generated.append(varQ)
                    dynamicQuestionRegistry[varQ.id] = varQ
                }
            }
        }

        // Also include original bank questions that are explicitly tagged to the selected chapters and match level/category
        for bankQ in originalQuestionBank {
            let matchesLevel = (level == .all || bankQ.level == level)
            let matchesCategory = categories.contains(bankQ.category)
            let matchesChapter = !bankQ.chapterIds.isEmpty && bankQ.chapterIds.allSatisfy { chapters.contains($0) }
            if matchesLevel && matchesCategory && matchesChapter && !generated.contains(where: { $0.id == bankQ.id }) {
                generated.append(bankQ)
            }
        }

        return orderKeepingPassageGroupsTogether(generated)
    }

    // MARK: - Section-Wise Question Pool (Section 4)
    func availableSectionQuestions(
        level: JLPTLevel,
        category: ExamQuestionCategory
    ) -> [ExamQuestion] {
        var pool = originalQuestionBank.filter {
            (level == .all || $0.level == level) && $0.category == category
        }

        // Augment Vocabulary, Kanji, and Grammar with in-app study data for the selected level
        if category == .vocabulary || category == .kanji || category == .grammar {
            let allCh = Set(availableChapters)
            let chapterPool = availableChapterQuestions(
                level: level,
                chapters: allCh,
                categories: [category]
            )
            for q in chapterPool where !pool.contains(where: { $0.id == q.id }) {
                pool.append(q)
            }
        }

        // Augment Grammar with verified Particle usage questions at the matching JLPT level
        if category == .grammar {
            let usageMeaningPool = ParticleDataService.shared.usages.map(\.meaning)
            for p in ParticleDataService.shared.particles {
                for usage in ParticleDataService.shared.usages(forParticleId: p.id) {
                    guard let uLevel = usage.jlptLevel, (level == .all || uLevel == level) else { continue }
                    let qId = "sec-particle-\(p.id)-\(usage.id)"
                    guard !pool.contains(where: { $0.id == qId }) else { continue }

                    if let ex = usage.examples.first, ex.japanese.contains(p.japanese) {
                        let blanked = ex.japanese.replacingOccurrences(of: p.japanese, with: " [ ___ ] ")
                        let choices = buildChoices(
                            correct: p.japanese,
                            pool: ["は", "が", "を", "に", "で", "の", "と", "も", "へ", "から", "まで", "より"],
                            seed: qId
                        )
                        let q = ExamQuestion(
                            id: qId,
                            reference: LearningItemReference(domain: .particles, contentId: p.id, subContentId: usage.id),
                            level: uLevel,
                            category: .grammar,
                            sectionId: "sec-grammar-reading",
                            passageGroupId: nil,
                            passageText: nil,
                            prompt: "Fill in the particle: \(blanked)",
                            context: "\(ex.meaning) • Pattern: \(usage.pattern)",
                            audioScript: nil,
                            imageAsset: nil,
                            choices: choices,
                            correctAnswer: p.japanese,
                            explanation: "「\(p.japanese)」 (\(p.romaji)) — \(usage.meaning). \(usage.explanation)",
                            chapterIds: [],
                            sourceTitle: "In-App Verified Particles (#188 Catalogue)",
                            sourceUrl: nil,
                            license: "In-App Study Data",
                            attribution: "nihon App Particle Repository",
                            dateChecked: "2026-10-28"
                        )
                        pool.append(q)
                        dynamicQuestionRegistry[q.id] = q
                    } else {
                        let choices = buildChoices(correct: usage.meaning, pool: usageMeaningPool, seed: qId)
                        let q = ExamQuestion(
                            id: qId,
                            reference: LearningItemReference(domain: .particles, contentId: p.id, subContentId: usage.id),
                            level: uLevel,
                            category: .grammar,
                            sectionId: "sec-grammar-reading",
                            passageGroupId: nil,
                            passageText: nil,
                            prompt: "Which usage matches 「\(p.japanese)」 in the pattern 「\(usage.pattern)」?",
                            context: usage.explanation,
                            audioScript: nil,
                            imageAsset: nil,
                            choices: choices,
                            correctAnswer: usage.meaning,
                            explanation: "「\(p.japanese)」 (\(p.romaji)): \(usage.meaning) — \(usage.explanation)",
                            chapterIds: [],
                            sourceTitle: "In-App Verified Particles (#188 Catalogue)",
                            sourceUrl: nil,
                            license: "In-App Study Data",
                            attribution: "nihon App Particle Repository",
                            dateChecked: "2026-10-28"
                        )
                        pool.append(q)
                        dynamicQuestionRegistry[q.id] = q
                    }
                }
            }
        }

        return orderKeepingPassageGroupsTogether(pool)
    }

    // MARK: - Keep Passage-Based & Dependent Questions Together (Section 3 Requirement)
    func orderKeepingPassageGroupsTogether(_ questions: [ExamQuestion], maxCount: Int = 0) -> [ExamQuestion] {
        guard !questions.isEmpty else { return [] }

        var result: [ExamQuestion] = []
        var consumedIds = Set<String>()

        for q in questions {
            guard !consumedIds.contains(q.id) else { continue }
            if let groupId = q.passageGroupId, !groupId.isEmpty {
                let groupMembers = questions.filter { $0.passageGroupId == groupId && !consumedIds.contains($0.id) }
                if maxCount > 0 && !result.isEmpty && (result.count + groupMembers.count > maxCount) {
                    continue
                }
                for member in groupMembers {
                    result.append(member)
                    consumedIds.insert(member.id)
                }
            } else {
                result.append(q)
                consumedIds.insert(q.id)
            }

            if maxCount > 0 && result.count >= maxCount {
                break
            }
        }

        if maxCount > 0 && result.count > maxCount {
            return Array(result.prefix(maxCount))
        }
        return result
    }

    // MARK: - Start / Resume Attempts (Section 2, 3, 4 & 7)

    /// Returns any existing in-progress attempt for the given exam paper so refreshing does not reset the timer or reshuffle questions.
    func activeAttempt(forExamId examId: String) -> ExamAttempt? {
        attempts.first { $0.examId == examId && $0.status == .inProgress }
    }

    func startFullLengthExam(
        paper: ExamPaper,
        isTimed: Bool,
        deliveryMode: ExamDeliveryMode = .exam
    ) -> ExamAttempt {
        // If there is already an in-progress attempt for this exact paper, return it (resume-safe)
        if let existing = activeAttempt(forExamId: paper.id) {
            return existing
        }

        var paperQuestions: [ExamQuestion] = paper.questionIds.compactMap { verifiedQuestion(forId: $0) }
        if paper.kind == .fullLength && paperQuestions.count < 25 {
            // Only supplement shorter custom fallback full-length papers; bundled full-length, section, and chapter papers use their exact paper questions
            let extraVocab = availableChapterQuestions(level: paper.level, chapters: Set(availableChapters), categories: [.vocabulary, .kanji]).prefix(6)
            for q in extraVocab where !paperQuestions.contains(where: { $0.id == q.id }) {
                paperQuestions.append(q)
            }
        }

        let ordered = orderKeepingPassageGroupsTogether(paperQuestions)
        for q in ordered {
            dynamicQuestionRegistry[q.id] = q
        }
        saveDynamicQuestionCache()

        let paperChapters = Array(Set(ordered.flatMap(\.chapterIds))).sorted()
        let sectionCats = Array(Set(paper.sections.flatMap(\.categories)))
        let effectiveCategories = sectionCats.isEmpty ? ExamQuestionCategory.allCases : sectionCats

        let attempt = ExamAttempt(
            id: "attempt-\(UUID().uuidString)",
            examId: paper.id,
            examTitle: paper.title,
            kind: paper.kind,
            level: paper.level,
            deliveryMode: deliveryMode,
            isTimed: isTimed,
            durationLimitSeconds: isTimed ? paper.durationSeconds : nil,
            selectedChapters: paperChapters,
            selectedCategories: effectiveCategories,
            sections: paper.sections,
            questions: ordered.map { $0.toPublicQuestion() },
            startedAt: Date(),
            submittedAt: nil,
            currentQuestionIndex: 0,
            selectedAnswers: [:],
            flaggedQuestionIds: [],
            practiceFeedbackByQuestionId: [:],
            status: .inProgress,
            elapsedSeconds: 0,
            score: 0,
            totalQuestions: ordered.count,
            correctCount: 0,
            incorrectCount: 0,
            unansweredCount: ordered.count,
            sectionResults: [],
            reviewItems: []
        )

        attempts.insert(attempt, at: 0)
        saveAttempts()
        return attempt
    }

    /// Creates a Chapter-Wise Test strictly from the selected chapters.
    /// Returns both the created attempt (if >= 1 question is available) and the available count vs requested count explanation.
    func startChapterWiseTest(
        level: JLPTLevel,
        chapters: Set<Int>,
        categories: Set<ExamQuestionCategory>,
        requestedQuestionCount: Int,
        durationSeconds: Int?,
        deliveryMode: ExamDeliveryMode
    ) -> (attempt: ExamAttempt?, availableCount: Int, noticeMessage: String?) {
        let pool = availableChapterQuestions(level: level, chapters: chapters, categories: categories)
        let availableCount = pool.count

        guard availableCount > 0 else {
            let chText = chapters.sorted().map(String.init).joined(separator: ", ")
            return (
                nil,
                0,
                "No questions are available for Chapter(s) \(chText) with the selected level (\(level.rawValue)) and categories. Try selecting Chapter 1 or enabling Vocabulary/Grammar."
            )
        }

        let notice: String?
        if requestedQuestionCount > availableCount {
            let chText = chapters.sorted().map(String.init).joined(separator: ", ")
            notice = "Only \(availableCount) verified questions are available in Chapter(s) \(chText) (requested \(requestedQuestionCount)). Starting with all \(availableCount) chapter questions without pulling from other chapters."
        } else {
            notice = nil
        }

        let selectedQuestions = orderKeepingPassageGroupsTogether(
            pool,
            maxCount: requestedQuestionCount > 0 ? min(requestedQuestionCount, availableCount) : availableCount
        )
        for q in selectedQuestions {
            dynamicQuestionRegistry[q.id] = q
        }
        saveDynamicQuestionCache()

        let sortedChapters = chapters.sorted()
        let chTitle: String
        if sortedChapters.count == 1 {
            chTitle = "Chapter \(sortedChapters[0]) Test"
        } else if let first = sortedChapters.first, let last = sortedChapters.last, sortedChapters.count == (last - first + 1) {
            chTitle = "Chapters \(first)–\(last) Test"
        } else {
            chTitle = "Chapters \(sortedChapters.map(String.init).joined(separator: ", ")) Test"
        }

        let sections = buildSectionsForCategories(Array(categories), durationSeconds: durationSeconds ?? 900)
        let isTimed = (durationSeconds != nil && (durationSeconds ?? 0) > 0)

        let attempt = ExamAttempt(
            id: "attempt-\(UUID().uuidString)",
            examId: "chapter-\(sortedChapters.map(String.init).joined(separator: "_"))-\(level.rawValue)",
            examTitle: "\(level.rawValue) • \(chTitle)",
            kind: .chapter,
            level: level,
            deliveryMode: deliveryMode,
            isTimed: isTimed,
            durationLimitSeconds: isTimed ? durationSeconds : nil,
            selectedChapters: sortedChapters,
            selectedCategories: categories.sorted { $0.rawValue < $1.rawValue },
            sections: sections,
            questions: selectedQuestions.map { $0.toPublicQuestion() },
            startedAt: Date(),
            submittedAt: nil,
            currentQuestionIndex: 0,
            selectedAnswers: [:],
            flaggedQuestionIds: [],
            practiceFeedbackByQuestionId: [:],
            status: .inProgress,
            elapsedSeconds: 0,
            score: 0,
            totalQuestions: selectedQuestions.count,
            correctCount: 0,
            incorrectCount: 0,
            unansweredCount: selectedQuestions.count,
            sectionResults: [],
            reviewItems: []
        )

        attempts.insert(attempt, at: 0)
        saveAttempts()
        return (attempt, availableCount, notice)
    }

    func startSectionWisePractice(
        level: JLPTLevel,
        category: ExamQuestionCategory,
        requestedQuestionCount: Int,
        durationSeconds: Int?,
        deliveryMode: ExamDeliveryMode
    ) -> (attempt: ExamAttempt?, availableCount: Int, noticeMessage: String?) {
        let pool = availableSectionQuestions(level: level, category: category)
        let availableCount = pool.count
        guard availableCount > 0 else {
            return (nil, 0, "No questions available for \(level.rawValue) \(category.displayName).")
        }

        let notice: String? = (requestedQuestionCount > availableCount)
            ? "Only \(availableCount) verified \(category.displayName) questions are available for \(level.rawValue) (requested \(requestedQuestionCount))."
            : nil

        let selectedQuestions = orderKeepingPassageGroupsTogether(
            pool,
            maxCount: requestedQuestionCount > 0 ? min(requestedQuestionCount, availableCount) : availableCount
        )
        for q in selectedQuestions {
            dynamicQuestionRegistry[q.id] = q
        }
        saveDynamicQuestionCache()

        let isTimed = (durationSeconds != nil && (durationSeconds ?? 0) > 0)
        let sections = buildSectionsForCategories([category], durationSeconds: durationSeconds ?? 600)

        let attempt = ExamAttempt(
            id: "attempt-\(UUID().uuidString)",
            examId: "section-\(level.rawValue)-\(category.rawValue)",
            examTitle: "\(level.rawValue) • \(category.displayName)",
            kind: .section,
            level: level,
            deliveryMode: deliveryMode,
            isTimed: isTimed,
            durationLimitSeconds: isTimed ? durationSeconds : nil,
            selectedChapters: [],
            selectedCategories: [category],
            sections: sections,
            questions: selectedQuestions.map { $0.toPublicQuestion() },
            startedAt: Date(),
            submittedAt: nil,
            currentQuestionIndex: 0,
            selectedAnswers: [:],
            flaggedQuestionIds: [],
            practiceFeedbackByQuestionId: [:],
            status: .inProgress,
            elapsedSeconds: 0,
            score: 0,
            totalQuestions: selectedQuestions.count,
            correctCount: 0,
            incorrectCount: 0,
            unansweredCount: selectedQuestions.count,
            sectionResults: [],
            reviewItems: []
        )

        attempts.insert(attempt, at: 0)
        saveAttempts()
        return (attempt, availableCount, notice)
    }

    // MARK: - Answer Selection, Flagging, and Progress Saving (Section 2 & 7)
    @discardableResult
    func selectAnswer(
        attemptId: String,
        questionId: String,
        choice: String
    ) -> ExamAttempt? {
        guard let idx = attempts.firstIndex(where: { $0.id == attemptId }),
              attempts[idx].status == .inProgress else {
            return attempts.first { $0.id == attemptId }
        }

        var attempt = attempts[idx]
        attempt.selectedAnswers[questionId] = choice

        // In Practice Mode, immediately generate feedback and update SRS once per question
        if attempt.deliveryMode == .practice,
           let verified = verifiedQuestion(forId: questionId) {
            let isCorrect = normalize(choice) == normalize(verified.correctAnswer)
            let reviewItem = ExamQuestionReviewItem(
                questionId: verified.id,
                reference: verified.reference,
                category: verified.category,
                sectionId: verified.sectionId,
                prompt: verified.prompt,
                context: verified.context,
                passageText: verified.passageText,
                audioScript: verified.audioScript,
                choices: verified.choices,
                selectedAnswer: choice,
                correctAnswer: verified.correctAnswer,
                isCorrect: isCorrect,
                isUnanswered: false,
                isFlagged: attempt.flaggedQuestionIds.contains(questionId),
                explanation: verified.explanation,
                chapterIds: verified.chapterIds,
                sourceTitle: verified.sourceTitle,
                sourceUrl: verified.sourceUrl,
                license: verified.license,
                attribution: verified.attribution
            )
            attempt.practiceFeedbackByQuestionId[questionId] = reviewItem
            recordSRSOutcomeOnce(attemptId: attemptId, question: verified, isCorrect: isCorrect)
        }

        attempts[idx] = attempt
        saveAttempts()
        return attempt
    }

    @discardableResult
    func toggleFlag(attemptId: String, questionId: String) -> ExamAttempt? {
        guard let idx = attempts.firstIndex(where: { $0.id == attemptId }),
              attempts[idx].status == .inProgress else {
            return attempts.first { $0.id == attemptId }
        }

        var attempt = attempts[idx]
        if attempt.flaggedQuestionIds.contains(questionId) {
            attempt.flaggedQuestionIds.remove(questionId)
        } else {
            attempt.flaggedQuestionIds.insert(questionId)
        }
        attempts[idx] = attempt
        saveAttempts()
        return attempt
    }

    func updateProgressState(
        attemptId: String,
        currentQuestionIndex: Int,
        elapsedSeconds: Int
    ) {
        guard let idx = attempts.firstIndex(where: { $0.id == attemptId }),
              attempts[idx].status == .inProgress else { return }

        attempts[idx].currentQuestionIndex = currentQuestionIndex
        attempts[idx].elapsedSeconds = max(attempts[idx].elapsedSeconds, elapsedSeconds)
        saveAttempts()
    }

    // MARK: - Submit Exam (Manual or Timeout Auto-Submit, Idempotent)
    @discardableResult
    func submitAttempt(
        attemptId: String,
        didTimeout: Bool = false,
        now: Date = Date()
    ) -> ExamAttempt? {
        guard let idx = attempts.firstIndex(where: { $0.id == attemptId }) else {
            return nil
        }

        // Idempotency safeguard: if already submitted/timedOut, return existing result without re-scoring or duplicating SRS events!
        if attempts[idx].status != .inProgress {
            return attempts[idx]
        }

        var attempt = attempts[idx]
        attempt.status = didTimeout ? .timedOut : .submitted
        attempt.submittedAt = now
        if didTimeout, let limit = attempt.durationLimitSeconds {
            attempt.elapsedSeconds = limit
        }

        var correct = 0
        var incorrect = 0
        var unanswered = 0
        var reviewItems: [ExamQuestionReviewItem] = []

        for pubQ in attempt.questions {
            guard let verified = verifiedQuestion(forId: pubQ.id) else { continue }
            let rawSelected = attempt.selectedAnswers[pubQ.id]?.trimmingCharacters(in: .whitespacesAndNewlines)
            let isUnanswered = (rawSelected == nil || rawSelected!.isEmpty)
            let isCorrect = !isUnanswered && (normalize(rawSelected!) == normalize(verified.correctAnswer))

            if isUnanswered {
                unanswered += 1
                // Unanswered questions on linked items count as a miss for SRS scheduling
                recordSRSOutcomeOnce(attemptId: attemptId, question: verified, isCorrect: false)
            } else if isCorrect {
                correct += 1
                recordSRSOutcomeOnce(attemptId: attemptId, question: verified, isCorrect: true)
            } else {
                incorrect += 1
                recordSRSOutcomeOnce(attemptId: attemptId, question: verified, isCorrect: false)
            }

            let reviewItem = ExamQuestionReviewItem(
                questionId: verified.id,
                reference: verified.reference,
                category: verified.category,
                sectionId: verified.sectionId,
                prompt: verified.prompt,
                context: verified.context,
                passageText: verified.passageText,
                audioScript: verified.audioScript,
                choices: verified.choices,
                selectedAnswer: rawSelected,
                correctAnswer: verified.correctAnswer,
                isCorrect: isCorrect,
                isUnanswered: isUnanswered,
                isFlagged: attempt.flaggedQuestionIds.contains(verified.id),
                explanation: verified.explanation,
                chapterIds: verified.chapterIds,
                sourceTitle: verified.sourceTitle,
                sourceUrl: verified.sourceUrl,
                license: verified.license,
                attribution: verified.attribution
            )
            reviewItems.append(reviewItem)
        }

        // Compute section/category breakdown
        var sectionResults: [ExamSectionResult] = []
        for cat in ExamQuestionCategory.allCases {
            let catItems = reviewItems.filter { $0.category == cat }
            guard !catItems.isEmpty else { continue }
            let cCount = catItems.filter(\.isCorrect).count
            let uCount = catItems.filter(\.isUnanswered).count
            let iCount = catItems.count - cCount - uCount
            sectionResults.append(ExamSectionResult(
                id: "cat-\(cat.rawValue)",
                title: cat.displayName,
                category: cat,
                totalQuestions: catItems.count,
                correctCount: cCount,
                incorrectCount: iCount,
                unansweredCount: uCount
            ))
        }

        attempt.correctCount = correct
        attempt.incorrectCount = incorrect
        attempt.unansweredCount = unanswered
        attempt.score = correct
        attempt.totalQuestions = reviewItems.count
        attempt.sectionResults = sectionResults
        attempt.reviewItems = reviewItems

        attempts[idx] = attempt
        saveAttempts()
        return attempt
    }

    // MARK: - Retry Incorrect Questions & Retake Test (Section 8)
    func retryIncorrectQuestions(from attemptId: String) -> ExamAttempt? {
        guard let previous = attempts.first(where: { $0.id == attemptId }) else { return nil }
        let missedIds: [String] = previous.reviewItems
            .filter { !$0.isCorrect }
            .map(\.questionId)
        guard !missedIds.isEmpty else { return nil }

        let missedQuestions = missedIds.compactMap { verifiedQuestion(forId: $0) }
        let ordered = orderKeepingPassageGroupsTogether(missedQuestions)
        guard !ordered.isEmpty else { return nil }

        let retryAttempt = ExamAttempt(
            id: "attempt-\(UUID().uuidString)",
            examId: "\(previous.examId)-retry",
            examTitle: "Retry Missed • \(previous.examTitle)",
            kind: previous.kind,
            level: previous.level,
            deliveryMode: .practice,
            isTimed: false,
            durationLimitSeconds: nil,
            selectedChapters: previous.selectedChapters,
            selectedCategories: previous.selectedCategories,
            sections: previous.sections,
            questions: ordered.map { $0.toPublicQuestion() },
            startedAt: Date(),
            submittedAt: nil,
            currentQuestionIndex: 0,
            selectedAnswers: [:],
            flaggedQuestionIds: [],
            practiceFeedbackByQuestionId: [:],
            status: .inProgress,
            elapsedSeconds: 0,
            score: 0,
            totalQuestions: ordered.count,
            correctCount: 0,
            incorrectCount: 0,
            unansweredCount: ordered.count,
            sectionResults: [],
            reviewItems: []
        )

        attempts.insert(retryAttempt, at: 0)
        saveAttempts()
        return retryAttempt
    }

    func retakeExam(from attemptId: String) -> ExamAttempt? {
        guard let previous = attempts.first(where: { $0.id == attemptId }) else { return nil }
        let originalQuestions = previous.questions.compactMap { verifiedQuestion(forId: $0.id) }
        guard !originalQuestions.isEmpty else { return nil }

        let retakeAttempt = ExamAttempt(
            id: "attempt-\(UUID().uuidString)",
            examId: previous.examId,
            examTitle: previous.examTitle,
            kind: previous.kind,
            level: previous.level,
            deliveryMode: previous.deliveryMode,
            isTimed: previous.isTimed,
            durationLimitSeconds: previous.durationLimitSeconds,
            selectedChapters: previous.selectedChapters,
            selectedCategories: previous.selectedCategories,
            sections: previous.sections,
            questions: originalQuestions.map { $0.toPublicQuestion() },
            startedAt: Date(),
            submittedAt: nil,
            currentQuestionIndex: 0,
            selectedAnswers: [:],
            flaggedQuestionIds: [],
            practiceFeedbackByQuestionId: [:],
            status: .inProgress,
            elapsedSeconds: 0,
            score: 0,
            totalQuestions: originalQuestions.count,
            correctCount: 0,
            incorrectCount: 0,
            unansweredCount: originalQuestions.count,
            sectionResults: [],
            reviewItems: []
        )

        attempts.insert(retakeAttempt, at: 0)
        saveAttempts()
        return retakeAttempt
    }

    // MARK: - Weak Areas Summary (Section 1 & 8)
    func weakCategoriesSummary() -> [(category: ExamQuestionCategory, accuracy: Int, totalAnswered: Int)] {
        let completed = attempts.filter { $0.status != .inProgress }
        var stats: [ExamQuestionCategory: (correct: Int, total: Int)] = [:]

        for attempt in completed {
            for item in attempt.reviewItems {
                var current = stats[item.category] ?? (0, 0)
                current.total += 1
                if item.isCorrect {
                    current.correct += 1
                }
                stats[item.category] = current
            }
        }

        return stats.map { (cat, pair) in
            let pct = pair.total > 0 ? Int(round((Double(pair.correct) / Double(pair.total)) * 100.0)) : 0
            return (cat, pct, pair.total)
        }
        .sorted { $0.accuracy < $1.accuracy }
    }

    func resetExamAttempts() {
        attempts = []
        recordedSRSAttemptQuestionPairs = []
        UserDefaults.standard.removeObject(forKey: attemptsStorageKey)
        NotificationCenter.default.post(name: .examDataUpdated, object: nil)
    }

    // MARK: - Helpers
    private func recordSRSOutcomeOnce(attemptId: String, question: ExamQuestion, isCorrect: Bool) {
        let dedupKey = "\(attemptId)::\(question.id)"
        guard !recordedSRSAttemptQuestionPairs.contains(dedupKey) else { return }
        recordedSRSAttemptQuestionPairs.insert(dedupKey)

        guard let ref = question.reference else { return }
        let rating: SRSRating = isCorrect ? .good : .again
        LearningItemResolver.recordReviewOutcome(
            reference: ref,
            rating: rating,
            wasRevealedBeforeRating: !isCorrect,
            durationSeconds: 1.5,
            scopeIdentifier: "exam_\(question.category.rawValue)"
        )
    }

    private func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func buildChoices(correct: String, pool: [String], seed: String, count: Int = 4) -> [String] {
        var distractors: [String] = []
        for candidate in pool where candidate != correct && !distractors.contains(candidate) && !candidate.isEmpty {
            distractors.append(candidate)
            if distractors.count >= count - 1 {
                break
            }
        }
        var choices = [correct] + distractors
        let shift = abs(seed.hashValue) % max(1, choices.count)
        if shift > 0 && shift < choices.count {
            choices = Array(choices[shift...]) + Array(choices[..<shift])
        }
        return choices
    }

    private func buildSectionsForCategories(_ categories: [ExamQuestionCategory], durationSeconds: Int) -> [ExamSectionSpec] {
        let sorted = categories.sorted { $0.rawValue < $1.rawValue }
        return [
            ExamSectionSpec(
                id: "sec-custom",
                title: sorted.map(\.displayName).joined(separator: " • "),
                japaneseTitle: sorted.map(\.japaneseTitle).joined(separator: "・"),
                categories: sorted,
                durationSeconds: durationSeconds,
                description: "Questions generated from selected scope."
            )
        ]
    }

    // MARK: - Original Verified N5 & N4 Question Bank & Mock Exam Papers (Section 6: No PDF Imports)
    private func buildOriginalQuestionBankAndPapers() {
        let n5Questions: [ExamQuestion] = [
            // Vocabulary (N5)
            ExamQuestion(
                id: "orig-n5-vocab-1",
                reference: nil,
                level: .n5,
                category: .vocabulary,
                sectionId: "n5-sec-1",
                passageGroupId: nil,
                passageText: nil,
                prompt: "まいあさ 7じに （　　）を のみます。",
                context: "Choose the best word for the blank.",
                audioScript: nil,
                imageAsset: nil,
                choices: ["みず", "つくえ", "でんしゃ", "えんぴつ"],
                correctAnswer: "みず",
                explanation: "「みず」(water) is the only drinkable noun compatible with the verb のみます (to drink).",
                chapterIds: [],
                sourceTitle: "Original nihon JLPT N5 Practice Bank",
                sourceUrl: nil,
                license: "CC0 / Original App Content",
                attribution: "nihon Language Team",
                dateChecked: "2026-10-28"
            ),
            ExamQuestion(
                id: "orig-n5-vocab-2",
                reference: nil,
                level: .n5,
                category: .vocabulary,
                sectionId: "n5-sec-1",
                passageGroupId: nil,
                passageText: nil,
                prompt: "きのうの よる、ともだちに でんわを （　　）。",
                context: "Choose the verb that completes the expression with でんわ.",
                audioScript: nil,
                imageAsset: nil,
                choices: ["かけました", "きりました", "あけました", "すわりました"],
                correctAnswer: "かけました",
                explanation: "「でんわを かける」 is the standard collocation meaning \"to make a phone call\".",
                chapterIds: [],
                sourceTitle: "Original nihon JLPT N5 Practice Bank",
                sourceUrl: nil,
                license: "CC0 / Original App Content",
                attribution: "nihon Language Team",
                dateChecked: "2026-10-28"
            ),
            // Kanji (N5)
            ExamQuestion(
                id: "orig-n5-kanji-1",
                reference: nil,
                level: .n5,
                category: .kanji,
                sectionId: "n5-sec-1",
                passageGroupId: nil,
                passageText: nil,
                prompt: "あの 人は 「先生」です。 「先生」の よみかたは どれですか。",
                context: "Select the correct hiragana reading.",
                audioScript: nil,
                imageAsset: nil,
                choices: ["せんせい", "がくせい", "せんせ", "せいせん"],
                correctAnswer: "せんせい",
                explanation: "「先生」 is read 「せんせい」 (teacher / instructor).",
                chapterIds: [1],
                sourceTitle: "Original nihon JLPT N5 Practice Bank",
                sourceUrl: nil,
                license: "CC0 / Original App Content",
                attribution: "nihon Language Team",
                dateChecked: "2026-10-28"
            ),
            ExamQuestion(
                id: "orig-n5-kanji-2",
                reference: nil,
                level: .n5,
                category: .kanji,
                sectionId: "n5-sec-1",
                passageGroupId: nil,
                passageText: nil,
                prompt: "まいにち 「しんぶん」を よみます。 「しんぶん」の 漢字は どれですか。",
                context: "Select the correct kanji orthography.",
                audioScript: nil,
                imageAsset: nil,
                choices: ["新聞", "新文", "親聞", "心聞"],
                correctAnswer: "新聞",
                explanation: "「しんぶん」 (newspaper) is written with 新 (new) + 聞 (hear/ask): 新聞.",
                chapterIds: [],
                sourceTitle: "Original nihon JLPT N5 Practice Bank",
                sourceUrl: nil,
                license: "CC0 / Original App Content",
                attribution: "nihon Language Team",
                dateChecked: "2026-10-28"
            ),
            // Grammar (N5)
            ExamQuestion(
                id: "orig-n5-grammar-1",
                reference: LearningItemReference(domain: .particles, contentId: "particle-ni", subContentId: "ni-location"),
                level: .n5,
                category: .grammar,
                sectionId: "n5-sec-2",
                passageGroupId: nil,
                passageText: nil,
                prompt: "つくえの うえ（　　） ほんが あります。",
                context: "Select the correct particle indicating location of existence.",
                audioScript: nil,
                imageAsset: nil,
                choices: ["に", "を", "で", "へ"],
                correctAnswer: "に",
                explanation: "With existence verbs (あります / います), 「に」 marks the static location where something exists.",
                chapterIds: [],
                sourceTitle: "Original nihon JLPT N5 Practice Bank",
                sourceUrl: nil,
                license: "CC0 / Original App Content",
                attribution: "nihon Language Team",
                dateChecked: "2026-10-28"
            ),
            ExamQuestion(
                id: "orig-n5-grammar-2",
                reference: LearningItemReference(domain: .grammar, contentId: "grammar-desu", subContentId: "desu-present-neg"),
                level: .n5,
                category: .grammar,
                sectionId: "n5-sec-2",
                passageGroupId: nil,
                passageText: nil,
                prompt: "わたしは かいしゃいん（　　）。 がくせいです。",
                context: "Choose the polite negative copula form.",
                audioScript: nil,
                imageAsset: nil,
                choices: ["じゃありません", "ます", "でした", "になりません"],
                correctAnswer: "じゃありません",
                explanation: "「N1 は N2 じゃありません」 is the polite negative copula pattern taught in Chapter 1.",
                chapterIds: [1],
                sourceTitle: "Original nihon JLPT N5 Practice Bank",
                sourceUrl: nil,
                license: "CC0 / Original App Content",
                attribution: "nihon Language Team",
                dateChecked: "2026-10-28"
            ),
            // Reading Comprehension Passage (N5 — 2 dependent questions grouped via passageGroupId)
            ExamQuestion(
                id: "orig-n5-reading-1a",
                reference: nil,
                level: .n5,
                category: .reading,
                sectionId: "n5-sec-2",
                passageGroupId: "passage-n5-tanaka-weekend",
                passageText: "わたしは きのうの にちようびに、ともだちの ミラーさんと 京都へ いきました。あさ 8じに えきで あいました。京都で ふるい おてらを みて、ひるごはんに うどんを たべました。とても たのしかったです。",
                prompt: "質問 1： わたしと ミラーさんは どこで あいましたか。",
                context: "Read the passage above and answer Question 1.",
                audioScript: nil,
                imageAsset: nil,
                choices: ["えき", "おてら", "うどんや", "ミラーさんの いえ"],
                correctAnswer: "えき",
                explanation: "The passage states 「あさ 8じに えきで あいました」 (We met at the station at 8:00 AM).",
                chapterIds: [],
                sourceTitle: "Original nihon JLPT N5 Reading Passage",
                sourceUrl: nil,
                license: "CC0 / Original App Content",
                attribution: "nihon Language Team",
                dateChecked: "2026-10-28"
            ),
            ExamQuestion(
                id: "orig-n5-reading-1b",
                reference: nil,
                level: .n5,
                category: .reading,
                sectionId: "n5-sec-2",
                passageGroupId: "passage-n5-tanaka-weekend",
                passageText: "わたしは きのうの にちようびに、ともだちの ミラーさんと 京都へ いきました。あさ 8じに えきで あいました。京都で ふるい おてらを みて、ひるごはんに うどんを たべました。とても たのしかったです。",
                prompt: "質問 2： ふたりは ひるごはんに なにを たべましたか。",
                context: "Read the passage above and answer Question 2.",
                audioScript: nil,
                imageAsset: nil,
                choices: ["うどん", "すし", "パン", "カレー"],
                correctAnswer: "うどん",
                explanation: "The passage states 「ひるごはんに うどんを たべました」 (We ate udon for lunch).",
                chapterIds: [],
                sourceTitle: "Original nihon JLPT N5 Reading Passage",
                sourceUrl: nil,
                license: "CC0 / Original App Content",
                attribution: "nihon Language Team",
                dateChecked: "2026-10-28"
            ),
            // Listening Comprehension (N5)
            ExamQuestion(
                id: "orig-n5-listening-1",
                reference: nil,
                level: .n5,
                category: .listening,
                sectionId: "n5-sec-3",
                passageGroupId: nil,
                passageText: nil,
                prompt: "おとこのひとと おんなのひとが はなしています。 つぎの でんしゃは なんじに でますか。",
                context: "Tap 'Play Audio' to listen to the dialogue.",
                audioScript: "すみません、東京いきの でんしゃは 10じですか。いいえ、10じの でんしゃは もう でました。つぎは 10じ15ふんです。わかりました、ありがとうございます。",
                imageAsset: nil,
                choices: ["10じ 15ふん", "10じ 00ふん", "10じ 30ぷん", "9じ 45ふん"],
                correctAnswer: "10じ 15ふん",
                explanation: "The staff member replies: 「つぎは 10じ15ふんです」 (The next one is at 10:15).",
                chapterIds: [],
                sourceTitle: "Original nihon JLPT N5 Listening Bank",
                sourceUrl: nil,
                license: "CC0 / Original App Content",
                attribution: "nihon Language Team",
                dateChecked: "2026-10-28"
            ),
            ExamQuestion(
                id: "orig-n5-listening-2",
                reference: nil,
                level: .n5,
                category: .listening,
                sectionId: "n5-sec-3",
                passageGroupId: nil,
                passageText: nil,
                prompt: "せんせいが クラスで はなしています。 がくせいは あした なにを もってきますか。",
                context: "Tap 'Play Audio' to listen to the announcement.",
                audioScript: "みなさん、あしたは かんじの テストが あります。えんぴつと けしごむを もってきてください。じしょは つかいませんから、もってこないでください。",
                imageAsset: nil,
                choices: ["えんぴつと けしごむ", "じしょと えんぴつ", "じしょだけ", "ノートと じしょ"],
                correctAnswer: "えんぴつと けしごむ",
                explanation: "The teacher instructs: 「えんぴつと けしごむを もってきてください。じしょは…もってこないでください。」",
                chapterIds: [],
                sourceTitle: "Original nihon JLPT N5 Listening Bank",
                sourceUrl: nil,
                license: "CC0 / Original App Content",
                attribution: "nihon Language Team",
                dateChecked: "2026-10-28"
            )
        ]

        let n4Questions: [ExamQuestion] = [
            // Vocabulary (N4)
            ExamQuestion(
                id: "orig-n4-vocab-1",
                reference: nil,
                level: .n4,
                category: .vocabulary,
                sectionId: "n4-sec-1",
                passageGroupId: nil,
                passageText: nil,
                prompt: "かいぎの まえに、しりょうを （　　）しておいてください。",
                context: "Choose the most appropriate word.",
                audioScript: nil,
                imageAsset: nil,
                choices: ["じゅんび", "けんぶつ", "しょうかい", "しんぱい"],
                correctAnswer: "じゅんび",
                explanation: "「しりょうを じゅんびする」 means \"to prepare the materials\" before a meeting.",
                chapterIds: [],
                sourceTitle: "Original nihon JLPT N4 Practice Bank",
                sourceUrl: nil,
                license: "CC0 / Original App Content",
                attribution: "nihon Language Team",
                dateChecked: "2026-10-28"
            ),
            ExamQuestion(
                id: "orig-n4-vocab-2",
                reference: nil,
                level: .n4,
                category: .vocabulary,
                sectionId: "n4-sec-1",
                passageGroupId: nil,
                passageText: nil,
                prompt: "パスポートを なくさないように、（　　） しまってあります。",
                context: "Choose the best adverb.",
                audioScript: nil,
                imageAsset: nil,
                choices: ["だいじに", "きゅうに", "さっき", "ぜんぜん"],
                correctAnswer: "だいじに",
                explanation: "「だいじに しまう」 means \"to put away safely / carefully\".",
                chapterIds: [],
                sourceTitle: "Original nihon JLPT N4 Practice Bank",
                sourceUrl: nil,
                license: "CC0 / Original App Content",
                attribution: "nihon Language Team",
                dateChecked: "2026-10-28"
            ),
            // Kanji (N4)
            ExamQuestion(
                id: "orig-n4-kanji-1",
                reference: nil,
                level: .n4,
                category: .kanji,
                sectionId: "n4-sec-1",
                passageGroupId: nil,
                passageText: nil,
                prompt: "この 図書館は 「特別」に 日曜日も あいています。 「特別」の よみかたは どれですか。",
                context: "Select the correct reading.",
                audioScript: nil,
                imageAsset: nil,
                choices: ["とくべつ", "とくべっつ", "じべつ", "とくわかれ"],
                correctAnswer: "とくべつ",
                explanation: "「特別」 is read 「とくべつ」 (special / specially).",
                chapterIds: [],
                sourceTitle: "Original nihon JLPT N4 Practice Bank",
                sourceUrl: nil,
                license: "CC0 / Original App Content",
                attribution: "nihon Language Team",
                dateChecked: "2026-10-28"
            ),
            ExamQuestion(
                id: "orig-n4-kanji-2",
                reference: nil,
                level: .n4,
                category: .kanji,
                sectionId: "n4-sec-1",
                passageGroupId: nil,
                passageText: nil,
                prompt: "あしたの 「てんき」を しらべました。 「てんき」の 漢字は どれですか。",
                context: "Select the correct kanji.",
                audioScript: nil,
                imageAsset: nil,
                choices: ["天気", "転気", "天記", "店気"],
                correctAnswer: "天気",
                explanation: "「てんき」 (weather) is written 天気.",
                chapterIds: [],
                sourceTitle: "Original nihon JLPT N4 Practice Bank",
                sourceUrl: nil,
                license: "CC0 / Original App Content",
                attribution: "nihon Language Team",
                dateChecked: "2026-10-28"
            ),
            // Grammar (N4)
            ExamQuestion(
                id: "orig-n4-grammar-1",
                reference: LearningItemReference(domain: .grammar, contentId: "grammar-noni"),
                level: .n4,
                category: .grammar,
                sectionId: "n4-sec-2",
                passageGroupId: nil,
                passageText: nil,
                prompt: "くすりを のんだ（　　）、まだ あたまが いたいです。",
                context: "Select the conjunction expressing unexpected contrast.",
                audioScript: nil,
                imageAsset: nil,
                choices: ["のに", "ために", "ように", "から"],
                correctAnswer: "のに",
                explanation: "「〜のに」 means \"even though / despite\" when the result runs contrary to expectation.",
                chapterIds: [],
                sourceTitle: "Original nihon JLPT N4 Practice Bank",
                sourceUrl: nil,
                license: "CC0 / Original App Content",
                attribution: "nihon Language Team",
                dateChecked: "2026-10-28"
            ),
            ExamQuestion(
                id: "orig-n4-grammar-2",
                reference: LearningItemReference(domain: .grammar, contentId: "grammar-tara"),
                level: .n4,
                category: .grammar,
                sectionId: "n4-sec-2",
                passageGroupId: nil,
                passageText: nil,
                prompt: "えきに （　　）、すぐ でんわを してください。",
                context: "Choose the conditional form meaning 'when/once you arrive'.",
                audioScript: nil,
                imageAsset: nil,
                choices: ["ついたら", "つくなら", "ついても", "つきながら"],
                correctAnswer: "ついたら",
                explanation: "「〜たら」 expresses a sequential condition (\"once/when you arrive at the station, please call me\").",
                chapterIds: [],
                sourceTitle: "Original nihon JLPT N4 Practice Bank",
                sourceUrl: nil,
                license: "CC0 / Original App Content",
                attribution: "nihon Language Team",
                dateChecked: "2026-10-28"
            ),
            // Reading Comprehension Passage (N4 — 2 grouped questions)
            ExamQuestion(
                id: "orig-n4-reading-1a",
                reference: nil,
                level: .n4,
                category: .reading,
                sectionId: "n4-sec-2",
                passageGroupId: "passage-n4-community-notice",
                passageText: "【さくらマンションの みなさんへ】\nらいしゅうの すいようび（11月4日）の ごぜん10じから ごご1じまで、マンションの 水道（すいどう）の 工事（こうじ）を します。その あいだは みずが つかえません。必要な みずは、10じまでに よういして おいてください。",
                prompt: "質問 1： 11月4日の ごぜん11じに できないことは どれですか。",
                context: "Read the notice above and answer Question 1.",
                audioScript: nil,
                imageAsset: nil,
                choices: ["シャワーを あびること", "かいだんを つかうこと", "外へ でかけること", "テレビを みること"],
                correctAnswer: "シャワーを あびること",
                explanation: "Water service is shut off between 10:00 AM and 1:00 PM (「その あいだは みずが つかえません」), so taking a shower is impossible at 11:00 AM.",
                chapterIds: [],
                sourceTitle: "Original nihon JLPT N4 Reading Passage",
                sourceUrl: nil,
                license: "CC0 / Original App Content",
                attribution: "nihon Language Team",
                dateChecked: "2026-10-28"
            ),
            ExamQuestion(
                id: "orig-n4-reading-1b",
                reference: nil,
                level: .n4,
                category: .reading,
                sectionId: "n4-sec-2",
                passageGroupId: "passage-n4-community-notice",
                passageText: "【さくらマンションの みなさんへ】\nらいしゅうの すいようび（11月4日）の ごぜん10じから ごご1じまで、マンションの 水道（すいどう）の 工事（こうじ）を します。その あいだは みずが つかえません。必要な みずは、10じまでに よういして おいてください。",
                prompt: "質問 2： マンションの 人は 10じまでに なにを しなければ なりませんか。",
                context: "Read the notice above and answer Question 2.",
                audioScript: nil,
                imageAsset: nil,
                choices: ["必要な みずを よういしておく", "工事の おかねを はらう", "へやの そとに でる", "かんり人に でんわする"],
                correctAnswer: "必要な みずを よういしておく",
                explanation: "The notice instructs: 「必要な みずは、10じまでに よういして おいてください」 (Please prepare any needed water before 10:00).",
                chapterIds: [],
                sourceTitle: "Original nihon JLPT N4 Reading Passage",
                sourceUrl: nil,
                license: "CC0 / Original App Content",
                attribution: "nihon Language Team",
                dateChecked: "2026-10-28"
            ),
            // Listening Comprehension (N4)
            ExamQuestion(
                id: "orig-n4-listening-1",
                reference: nil,
                level: .n4,
                category: .listening,
                sectionId: "n4-sec-3",
                passageGroupId: nil,
                passageText: nil,
                prompt: "かいしゃで おとこのひとと おんなのひとが はなしています。 おんなのひとは このあと まず なにを しますか。",
                context: "Tap 'Play Audio' to listen to the conversation.",
                audioScript: "佐藤さん、かいぎしつの いすを ならべて くれませんか。はい、すぐ します。あ、すみません、その まえに この しりょうを 10まい コピーして ください。はい、わかりました。",
                imageAsset: nil,
                choices: ["しりょうを コピーする", "いすを ならべる", "かいぎしつを そうじする", "コーヒーを いれる"],
                correctAnswer: "しりょうを コピーする",
                explanation: "The man adds 「その まえに この しりょうを 10まい コピーして ください」 (Before that, please copy 10 sets of this document).",
                chapterIds: [],
                sourceTitle: "Original nihon JLPT N4 Listening Bank",
                sourceUrl: nil,
                license: "CC0 / Original App Content",
                attribution: "nihon Language Team",
                dateChecked: "2026-10-28"
            ),
            ExamQuestion(
                id: "orig-n4-listening-2",
                reference: nil,
                level: .n4,
                category: .listening,
                sectionId: "n4-sec-3",
                passageGroupId: nil,
                passageText: nil,
                prompt: "てんいんと おきゃくさんが はなしています。 おきゃくさんは どの かさを かいますか。",
                context: "Tap 'Play Audio' to listen to the dialogue.",
                audioScript: "すみません、かるくて 小さい かさは ありますか。はい、こちらの あおい かさと、くろい かさが かるいですよ。あおい ほうが かばんに はいりそうですね。じゃあ、これに します。",
                imageAsset: nil,
                choices: ["小さくて あおい かさ", "小さくて くろい かさ", "大きくて あおい かさ", "大きくて くろい かさ"],
                correctAnswer: "小さくて あおい かさ",
                explanation: "The customer chooses the small, light blue umbrella that fits inside the bag (「あおい ほうが かばんに はいりそうですね。じゃあ、これに します」).",
                chapterIds: [],
                sourceTitle: "Original nihon JLPT N4 Listening Bank",
                sourceUrl: nil,
                license: "CC0 / Original App Content",
                attribution: "nihon Language Team",
                dateChecked: "2026-10-28"
            )
        ]

        self.originalQuestionBank = n5Questions + n4Questions
        for q in self.originalQuestionBank {
            dynamicQuestionRegistry[q.id] = q
        }

        let n5Paper = ExamPaper(
            id: "mock-jlpt-n5-paper-1",
            title: "JLPT N5 Full-Length Practice Exam #1",
            level: .n5,
            kind: .fullLength,
            sourceTitle: "nihon Original N5 Mock + In-App Study Bank",
            sourceUrl: nil,
            license: "CC0 / Original App Content",
            attribution: "nihon Language Team",
            dateChecked: "2026-10-28",
            sections: [
                ExamSectionSpec(
                    id: "n5-sec-1",
                    title: "Section 1: Language Knowledge (Vocabulary & Kanji)",
                    japaneseTitle: "言語知識（文字・語彙）",
                    categories: [.vocabulary, .kanji],
                    durationSeconds: 20 * 60,
                    description: "Kanji reading, orthography, and contextual vocabulary usage (20 min)."
                ),
                ExamSectionSpec(
                    id: "n5-sec-2",
                    title: "Section 2: Language Knowledge (Grammar) & Reading",
                    japaneseTitle: "言語知識（文法）・読解",
                    categories: [.grammar, .reading],
                    durationSeconds: 40 * 60,
                    description: "Particles, sentence grammar patterns, and short passage reading comprehension (40 min)."
                ),
                ExamSectionSpec(
                    id: "n5-sec-3",
                    title: "Section 3: Listening Comprehension",
                    japaneseTitle: "聴解",
                    categories: [.listening],
                    durationSeconds: 30 * 60,
                    description: "Task-based and point-comprehension listening dialogues (30 min)."
                )
            ],
            questionIds: n5Questions.map(\.id),
            durationSeconds: 90 * 60
        )

        let n4Paper = ExamPaper(
            id: "mock-jlpt-n4-paper-1",
            title: "JLPT N4 Full-Length Practice Exam #1",
            level: .n4,
            kind: .fullLength,
            sourceTitle: "nihon Original N4 Mock + In-App Study Bank",
            sourceUrl: nil,
            license: "CC0 / Original App Content",
            attribution: "nihon Language Team",
            dateChecked: "2026-10-28",
            sections: [
                ExamSectionSpec(
                    id: "n4-sec-1",
                    title: "Section 1: Language Knowledge (Vocabulary & Kanji)",
                    japaneseTitle: "言語知識（文字・語彙）",
                    categories: [.vocabulary, .kanji],
                    durationSeconds: 25 * 60,
                    description: "Kanji readings, compound usage, and N4 contextual expressions (25 min)."
                ),
                ExamSectionSpec(
                    id: "n4-sec-2",
                    title: "Section 2: Language Knowledge (Grammar) & Reading",
                    japaneseTitle: "言語知識（文法）・読解",
                    categories: [.grammar, .reading],
                    durationSeconds: 55 * 60,
                    description: "N4 grammar structures, particles, and notice/passage reading comprehension (55 min)."
                ),
                ExamSectionSpec(
                    id: "n4-sec-3",
                    title: "Section 3: Listening Comprehension",
                    japaneseTitle: "聴解",
                    categories: [.listening],
                    durationSeconds: 35 * 60,
                    description: "Workplace and daily life listening comprehension dialogues (35 min)."
                )
            ],
            questionIds: n4Questions.map(\.id),
            durationSeconds: 115 * 60
        )

        self.fullLengthExams = [n5Paper, n4Paper]
    }
}

