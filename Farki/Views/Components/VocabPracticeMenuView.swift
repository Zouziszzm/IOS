import SwiftUI

struct VocabPracticeMenuView: View {
    @ObservedObject var viewModel: VocabViewModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var settingsManager = AppSettingsManager.shared

    @State private var selectedTab: PracticeTab = .all
    @State private var selectedSingleChapter: Int = 1
    @State private var selectedMultiChapters: Set<Int> = [1]
    @State private var troubleWordsOnly: Bool = false

    private enum PracticeTab: String, CaseIterable {
        case all = "全課"
        case single = "単一課"
        case multi = "複数課"
        case presets = "プリセット"

        var romaji: String {
            switch self {
            case .all: return "Zenka"
            case .single: return "Tan'itsu Ka"
            case .multi: return "Fukusuu Ka"
            case .presets: return "Purisetto"
            }
        }

        var english: String {
            switch self {
            case .all: return "All Chapters"
            case .single: return "Single Chapter"
            case .multi: return "Multi-Chapter"
            case .presets: return "Presets"
            }
        }
    }

    private var inkColor: Color { themeManager.inkColor }
    private var mutedColor: Color { themeManager.mutedColor }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.canvasColor.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Mode Segmented Picker
                        VStack(spacing: 6) {
                            Picker("Scope", selection: $selectedTab) {
                                ForEach(PracticeTab.allCases, id: \.self) { tab in
                                    Text(tab.rawValue).tag(tab)
                                }
                            }
                            .pickerStyle(.segmented)

                            if settingsManager.showAppRomaji || settingsManager.showAppEnglishMeaning {
                                HStack(spacing: 6) {
                                    if settingsManager.showAppRomaji {
                                        Text(selectedTab.romaji)
                                            .font(.english(size: 13, weight: .regular))
                                            .foregroundColor(mutedColor)
                                    }
                                    if settingsManager.showAppEnglishMeaning {
                                        Text("• \(selectedTab.english)")
                                            .font(.english(size: 13, weight: .regular))
                                            .foregroundColor(mutedColor.opacity(0.85))
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                        // Mode Content
                        switch selectedTab {
                        case .all:
                            allChaptersSection
                        case .single:
                            singleChapterSection
                        case .multi:
                            multiChapterSection
                        case .presets:
                            presetsSection
                        }

                        // Trouble Words Toggle
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle(isOn: $troubleWordsOnly) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Rectangle()
                                            .fill(Color(hex: "#EF4444"))
                                            .frame(width: 8, height: 8)
                                        Text("苦手な単語のみテスト")
                                            .font(.japanese(size: 14, weight: .bold))
                                            .foregroundColor(inkColor)
                                    }

                                    Text("Test only words marked as Hard / got wrong")
                                        .font(.english(size: 13, weight: .regular))
                                        .foregroundColor(mutedColor)
                                }
                            }
                            .tint(Color(hex: "#EF4444"))
                        }
                        .padding(14)
                        .background(themeManager.segmentEmptyColor.opacity(0.35))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)

                        // Primary Action Button: Start Test
                        Button {
                            executeStartTest()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 14))

                                Text("テストを開始 (\(previewWordCount) 単語)")
                                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(hex: "#3B82F6"))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("カスタム練習メニュー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                    .foregroundColor(inkColor)
                }
            }
        }
    }

    // MARK: - All Chapters Section
    private var allChaptersSection: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("全課総合テスト")
                        .font(.japanese(size: 16, weight: .bold))
                        .foregroundColor(inkColor)
                    Spacer()
                    Text("ALL")
                        .font(.english(size: 13, weight: .bold))
                        .foregroundColor(Color(hex: "#3B82F6"))
                }

                Text("収録されているすべての課の単語を網羅してテストします。苦手な単語が優先的に出題されます。")
                    .font(.japanese(size: 12))
                    .foregroundColor(mutedColor)
                    .lineSpacing(2)
            }
            .padding(16)
            .background(themeManager.segmentEmptyColor.opacity(0.35))
            .cornerRadius(12)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Single Chapter Section
    private var singleChapterSection: some View {
        VStack(spacing: 14) {
            let available = viewModel.availableChapters
            if available.isEmpty {
                Text("利用可能な課がありません")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(mutedColor)
                    .padding(20)
            } else {
                let n5Chapters = available.filter { $0 <= 25 }
                let n4Chapters = available.filter { $0 >= 26 }

                if !n5Chapters.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("JLPT N5 • 初級 I (第1〜25課)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#10B981"))
                            .padding(.horizontal, 16)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                            ForEach(n5Chapters, id: \.self) { ch in
                                let isSelected = (selectedSingleChapter == ch)
                                Button {
                                    selectedSingleChapter = ch
                                } label: {
                                    VStack(spacing: 2) {
                                        Text("第\(ch)課")
                                            .font(.japanese(size: 13, weight: isSelected ? .bold : .regular))
                                            .foregroundColor(isSelected ? .white : inkColor)

                                        Text("\(viewModel.wordCount(forChapter: ch))語")
                                            .font(.japanese(size: 9))
                                            .foregroundColor(isSelected ? .white.opacity(0.85) : mutedColor)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(isSelected ? Color(hex: "#10B981") : themeManager.segmentEmptyColor.opacity(0.4))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                if !n4Chapters.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("JLPT N4 • 初級 II (第26〜50課)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#3B82F6"))
                            .padding(.horizontal, 16)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                            ForEach(n4Chapters, id: \.self) { ch in
                                let isSelected = (selectedSingleChapter == ch)
                                Button {
                                    selectedSingleChapter = ch
                                } label: {
                                    VStack(spacing: 2) {
                                        Text("第\(ch)課")
                                            .font(.japanese(size: 13, weight: isSelected ? .bold : .regular))
                                            .foregroundColor(isSelected ? .white : inkColor)

                                        Text("\(viewModel.wordCount(forChapter: ch))語")
                                            .font(.japanese(size: 9))
                                            .foregroundColor(isSelected ? .white.opacity(0.85) : mutedColor)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(isSelected ? Color(hex: "#3B82F6") : themeManager.segmentEmptyColor.opacity(0.4))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
    }

    // MARK: - Multi-Chapter Section
    private var multiChapterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("複数の課を選択 (\(selectedMultiChapters.count)課 選択中)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(mutedColor)

                Spacer()

                HStack(spacing: 10) {
                    Button("N5 (1–25)") {
                        selectedMultiChapters = Set(viewModel.availableChapters.filter { $0 <= 25 })
                    }
                    .font(.english(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "#10B981"))

                    Button("N4 (26–50)") {
                        selectedMultiChapters = Set(viewModel.availableChapters.filter { $0 >= 26 })
                    }
                    .font(.english(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "#3B82F6"))

                    Button("All (1–50)") {
                        selectedMultiChapters = Set(viewModel.availableChapters)
                    }
                    .font(.english(size: 11, weight: .bold))
                    .foregroundColor(inkColor)
                }
            }
            .padding(.horizontal, 16)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 8)], spacing: 8) {
                ForEach(viewModel.availableChapters, id: \.self) { ch in
                    let isSelected = selectedMultiChapters.contains(ch)
                    Button {
                        if selectedMultiChapters.contains(ch) {
                            if selectedMultiChapters.count > 1 {
                                selectedMultiChapters.remove(ch)
                            }
                        } else {
                            selectedMultiChapters.insert(ch)
                        }
                    } label: {
                        Text("第\(ch)課")
                            .font(.japanese(size: 13, weight: isSelected ? .bold : .regular))
                            .foregroundColor(isSelected ? .white : inkColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(isSelected ? Color(hex: ch <= 25 ? "#10B981" : "#3B82F6") : themeManager.segmentEmptyColor.opacity(0.4))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Presets Section
    private var presetsSection: some View {
        VStack(spacing: 10) {
            presetCard(
                title: "苦手単語集中テスト",
                romaji: "Nigate Tango Shuuchuu",
                subtitle: "赤・黄色の要復習単語のみ出題",
                chapters: [],
                trouble: true
            )

            presetCard(
                title: "初級 I (第1〜25課) • JLPT N5",
                romaji: "Shokyuu I • Book 1 (Chapters 1–25)",
                subtitle: "N5合格レベルの全単語",
                chapters: Array(1...25),
                trouble: false
            )

            presetCard(
                title: "初級 II (第26〜50課) • JLPT N4",
                romaji: "Shokyuu II • Book 2 (Chapters 26–50)",
                subtitle: "N4合格レベルの全単語",
                chapters: Array(26...50),
                trouble: false
            )

            presetCard(
                title: "第1〜10課 基礎 (N5 前半)",
                romaji: "Chapters 1–10 Foundations (N5)",
                subtitle: "自己紹介・日常物・基本動詞・形容詞",
                chapters: Array(1...10),
                trouble: false
            )

            presetCard(
                title: "第26〜35課 応用 (N4 前半)",
                romaji: "Chapters 26–35 Intermediate (N4 Part 1)",
                subtitle: "可能形・意向形・条件形・自動詞他動詞",
                chapters: Array(26...35),
                trouble: false
            )

            presetCard(
                title: "第36〜50課 総合 (N4 後半)",
                romaji: "Chapters 36–50 Advanced (N4 Part 2)",
                subtitle: "受身形・使役形・敬語・複文表現",
                chapters: Array(36...50),
                trouble: false
            )
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func presetCard(title: String, romaji: String, subtitle: String, chapters: [Int], trouble: Bool) -> some View {
        Button {
            let scopeName = title
            viewModel.startTest(scopeTitle: scopeName, chapters: chapters, troubleOnly: trouble)
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.japanese(size: 14, weight: .bold))
                        .foregroundColor(inkColor)

                    Text(romaji)
                        .font(.english(size: 11, weight: .regular))
                        .foregroundColor(mutedColor)

                    Text(subtitle)
                        .font(.japanese(size: 11))
                        .foregroundColor(mutedColor.opacity(0.85))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(mutedColor)
            }
            .padding(14)
            .background(themeManager.segmentEmptyColor.opacity(0.35))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers
    private var previewWordCount: Int {
        var base = VocabDataService.shared.items
        switch selectedTab {
        case .all:
            break
        case .single:
            base = base.filter { $0.chapterNumber == selectedSingleChapter }
        case .multi:
            base = base.filter { selectedMultiChapters.contains($0.chapterNumber) }
        case .presets:
            break
        }
        if troubleWordsOnly {
            base = base.filter { $0.difficulty == .hard || $0.difficulty == .medium }
        }
        return base.count
    }

    private func executeStartTest() {
        let title: String
        let chapters: [Int]

        switch selectedTab {
        case .all:
            title = "全課総合テスト"
            chapters = []
        case .single:
            title = "第\(selectedSingleChapter)課 テスト"
            chapters = [selectedSingleChapter]
        case .multi:
            let sorted = selectedMultiChapters.sorted()
            title = "選択した\(sorted.count)課 テスト"
            chapters = sorted
        case .presets:
            title = "プリセット テスト"
            chapters = []
        }

        viewModel.startTest(scopeTitle: title, chapters: chapters, troubleOnly: troubleWordsOnly)
        dismiss()
    }
}
