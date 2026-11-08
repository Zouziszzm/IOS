import SwiftUI
import UniformTypeIdentifiers

struct SRSSettingsView: View {
    @ObservedObject var viewModel: SRSViewModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var settingsManager = AppSettingsManager.shared

    @State private var config: SRSConfig
    @State private var learningStepsText: String
    @State private var relearningStepsText: String
    @State private var isDocumentPickerPresented: Bool = false
    @State private var isSharePresented: Bool = false
    @State private var exportUrl: URL? = nil
    @State private var isResetProgressAlertPresented: Bool = false

    init(viewModel: SRSViewModel) {
        self.viewModel = viewModel
        let cfg = viewModel.config
        _config = State(initialValue: cfg)
        _learningStepsText = State(initialValue: cfg.learningSteps.map { String(format: "%g", $0) }.joined(separator: ", "))
        _relearningStepsText = State(initialValue: cfg.relearningSteps.map { String(format: "%g", $0) }.joined(separator: ", "))
    }

    private var inkColor: Color { themeManager.inkColor }

    @ViewBuilder
    private func sectionHeader(title: String, romaji: String, english: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(english)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(inkColor)
        }
        .textCase(nil)
        .padding(.vertical, 2)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.canvasColor.ignoresSafeArea()

                Form {
                    // MARK: - Algorithm Selection (SM-2 vs FSRS)
                    Section(header: sectionHeader(title: "スケジューラアルゴリズム", romaji: "Sukejuura Arugorizumu", english: "Scheduler Algorithm")) {
                        Picker("アルゴリズム", selection: $config.algorithm) {
                            ForEach(SRSAlgorithm.allCases, id: \.self) { algo in
                                Text(algo.title).tag(algo)
                            }
                        }
                        .pickerStyle(.segmented)

                        if config.algorithm == .fsrs {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("目標記憶定着率")
                                        if settingsManager.showAppEnglishMeaning {
                                            Text("Target Retention")
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Text(String(format: "%.0f%%", config.fsrsRequestRetention * 100))
                                        .foregroundColor(Color(hex: "#3B82F6"))
                                        .bold()
                                }
                                Slider(value: $config.fsrsRequestRetention, in: 0.70...0.97, step: 0.01)
                            }
                            Text("FSRSは記憶の安定性と難易度に基づき、目標定着率を達成する最適な復習間隔を自動計算します。")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        } else {
                            Text("AnkiスタイルのSM-2間隔反復アルゴリズムです。")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }

                    // MARK: - Daily Limits
                    Section(header: sectionHeader(title: "1日の上限設定", romaji: "Ichinichi no Jougen Settei", english: "Daily Limits")) {
                        Stepper(value: $config.newCardsPerDay, in: 0...500, step: 5) {
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("新規カード上限 / 日")
                                    if settingsManager.showAppEnglishMeaning {
                                        Text("New Cards Limit / Day")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Text("\(config.newCardsPerDay) 枚")
                                    .foregroundColor(.secondary)
                            }
                        }

                        Stepper(value: $config.maxReviewsPerDay, in: 0...1000, step: 25) {
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("最大復習カード上限 / 日")
                                    if settingsManager.showAppEnglishMeaning {
                                        Text("Max Reviews / Day")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Text("\(config.maxReviewsPerDay) 枚")
                                    .foregroundColor(.secondary)
                            }
                        }

                        Stepper(value: $config.dayRolloverHour, in: 0...23) {
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("日付更新時刻")
                                    if settingsManager.showAppEnglishMeaning {
                                        Text("Day Rollover Hour")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Text("\(config.dayRolloverHour):00")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // MARK: - Practice Display & Active Recall
                    Section(header: sectionHeader(title: "練習表示・アクティブ・リコール", romaji: "Renshuu Hyouji • Akutibu Rikooru", english: "Practice Display & Active Recall")) {
                        Toggle("英語の意味を初期状態で隠す", isOn: $settingsManager.practiceHideMeaningByDefault)
                        Text("アクティブ・リコールを促すため、英語の意味を隠します。「意味を確認」をタップすると意味が表示され、自動的に「難しい」として評価されます。")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("ローマ字表示 (メイン設定)")
                                if settingsManager.showAppEnglishMeaning {
                                    Text("Romaji Display")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Text(settingsManager.showAppRomaji ? "有効" : "無効")
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("英語表示 (メイン設定)")
                                if settingsManager.showAppEnglishMeaning {
                                    Text("English Meaning Display")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Text(settingsManager.showAppEnglishMeaning ? "有効" : "無効")
                                .foregroundColor(.secondary)
                        }
                    }

                    // MARK: - Card Direction
                    Section(header: sectionHeader(title: "出題方向", romaji: "Shutsudai Houkou", english: "Card Direction")) {
                        Picker("カード方向", selection: $config.direction) {
                            ForEach(CardDirection.allCases, id: \.self) { dir in
                                Text(dir.displayName).tag(dir)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    // MARK: - Learning Steps
                    Section(header: sectionHeader(title: "学習ステップ", romaji: "Gakushuu Suteppu", english: "Learning Steps")) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("新規カードのステップ (分, カンマ区切り)")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            TextField("1, 10", text: $learningStepsText)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("忘却・再学習ステップ (分, カンマ区切り)")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            TextField("10", text: $relearningStepsText)
                                .textFieldStyle(.roundedBorder)
                        }

                        Stepper(value: $config.graduatingIntervalDays, in: 1...30, step: 1) {
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("卒業間隔")
                                    if settingsManager.showAppEnglishMeaning {
                                        Text("Graduating Interval")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Text("\(Int(config.graduatingIntervalDays)) 日")
                                    .foregroundColor(.secondary)
                            }
                        }

                        Stepper(value: $config.easyIntervalDays, in: 1...60, step: 1) {
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("簡単間隔")
                                    if settingsManager.showAppEnglishMeaning {
                                        Text("Easy Interval")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Text("\(Int(config.easyIntervalDays)) 日")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // MARK: - Ease & Multipliers
                    Section(header: sectionHeader(title: "間隔係数・ボーナス", romaji: "Kankaku Keisuu • Boonasu", english: "SM-2 Multipliers")) {
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("初期難易度")
                                if settingsManager.showAppEnglishMeaning {
                                    Text("Starting Ease")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Text(String(format: "%.2f", config.startingEase))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $config.startingEase, in: 1.3...3.5, step: 0.05)

                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("最低難易度")
                                if settingsManager.showAppEnglishMeaning {
                                    Text("Min Ease")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Text(String(format: "%.2f", config.minEase))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $config.minEase, in: 1.1...2.0, step: 0.05)

                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("簡単ボーナス")
                                if settingsManager.showAppEnglishMeaning {
                                    Text("Easy Bonus")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Text(String(format: "%.2f", config.easyBonus))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $config.easyBonus, in: 1.0...2.0, step: 0.05)

                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("難問係数")
                                if settingsManager.showAppEnglishMeaning {
                                    Text("Hard Multiplier")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Text(String(format: "%.2f", config.hardMultiplier))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $config.hardMultiplier, in: 1.0...1.5, step: 0.05)

                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("全体間隔補正")
                                if settingsManager.showAppEnglishMeaning {
                                    Text("Interval Modifier")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Text(String(format: "%.0f%%", config.intervalModifier * 100))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $config.intervalModifier, in: 0.5...2.0, step: 0.05)

                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("忘却後の間隔割合")
                                if settingsManager.showAppEnglishMeaning {
                                    Text("Lapse New Interval (0% = Anki Default)")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Text(String(format: "%.0f%%", config.lapseNewInterval * 100))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $config.lapseNewInterval, in: 0.0...1.0, step: 0.05)

                        Stepper(value: $config.minimumLapseIntervalDays, in: 1...30, step: 1) {
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("忘却後の最小間隔")
                                    if settingsManager.showAppEnglishMeaning {
                                        Text("Minimum Lapse Interval")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Text("\(Int(config.minimumLapseIntervalDays)) 日")
                                    .foregroundColor(.secondary)
                            }
                        }

                        Toggle("ランダム分散 (Interval Fuzz)", isOn: $config.enableFuzz)
                    }

                    // MARK: - Backup & Restore
                    Section(header: sectionHeader(title: "バックアップと復元", romaji: "Bakkuappu to Fukugen", english: "Backup & Restore")) {
                        Button(action: {
                            if let url = viewModel.exportBackup() {
                                self.exportUrl = url
                                self.isSharePresented = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(Color(hex: "#3B82F6"))
                                Text("SRSデータをJSONでエクスポート")
                                    .foregroundColor(inkColor)
                            }
                        }

                        Button(action: {
                            isDocumentPickerPresented = true
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                    .foregroundColor(Color(hex: "#10B981"))
                                Text("バックアップファイル (JSON) を復元")
                                    .foregroundColor(inkColor)
                            }
                        }
                    }

                    // MARK: - Reset Progress & Stats (Keeps Vocab Words)
                    Section(header: sectionHeader(title: "進捗と統計のリセット", romaji: "Shincho to Toukei no Risetto", english: "Reset Progress & Stats"), footer: Text("登録された単語は保持され、すべてのSRS復習履歴、カード状態、ストリークのみがリセットされます。")) {
                        Button(role: .destructive, action: {
                            isResetProgressAlertPresented = true
                        }) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise.circle")
                                Text("単語を残して進捗・統計をリセット")
                            }
                        }
                    }

                    // MARK: - Reset Defaults
                    Section {
                        Button(role: .destructive, action: {
                            resetToDefaults()
                        }) {
                            Text("設定を初期値に戻す")
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("SRS 設定")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(inkColor)

                        if settingsManager.showAppRomaji {
                            Text("SRS Settei")
                                .font(.system(size: 9, weight: .regular, design: .monospaced))
                                .foregroundColor(themeManager.mutedColor)
                        }

                        if settingsManager.showAppEnglishMeaning {
                            Text("SRS Settings")
                                .font(.system(size: 9, weight: .regular, design: .monospaced))
                                .foregroundColor(themeManager.mutedColor.opacity(0.85))
                        }
                    }
                }
            }
            .alert("学習進捗と統計をリセットしますか？", isPresented: $isResetProgressAlertPresented) {
                Button("キャンセル", role: .cancel) { }
                Button("リセットを実行", role: .destructive) {
                    VocabDataService.shared.resetProgressAndStatsKeepVocab()
                    viewModel.loadQueue()
                    viewModel.updateStats()
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } message: {
                Text("単語データ（語彙・例文・文法）は保持されますが、すべてのカード状態、復習ログ、ストリークが初期状態に戻ります。この操作は取り消せません。")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveSettings()
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .bold))
                }
            }
            .sheet(isPresented: $isSharePresented) {
                if let url = exportUrl {
                    ActivityViewController(activityItems: [url])
                }
            }
            .fileImporter(
                isPresented: $isDocumentPickerPresented,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    if url.startAccessingSecurityScopedResource() {
                        defer { url.stopAccessingSecurityScopedResource() }
                        viewModel.importBackup(from: url)
                    } else {
                        viewModel.importBackup(from: url)
                    }
                case .failure(let error):
                    print("Import error: \(error.localizedDescription)")
                }
            }
        }
    }

    private func parseSteps(_ text: String) -> [Double] {
        let parts = text.split(separator: ",")
            .compactMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { $0 > 0 }
        return parts.isEmpty ? [10.0] : parts
    }

    private func saveSettings() {
        var updated = config
        updated.learningSteps = parseSteps(learningStepsText)
        updated.relearningSteps = parseSteps(relearningStepsText)
        viewModel.updateConfig(updated)
    }

    private func resetToDefaults() {
        let def = SRSConfig()
        config = def
        learningStepsText = def.learningSteps.map { String(format: "%g", $0) }.joined(separator: ", ")
        relearningStepsText = def.relearningSteps.map { String(format: "%g", $0) }.joined(separator: ", ")
    }
}

// MARK: - UIActivityViewController Wrapper for Export
private struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
