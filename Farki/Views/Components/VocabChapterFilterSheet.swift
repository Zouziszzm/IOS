import SwiftUI

struct VocabChapterFilterSheet: View {
    @ObservedObject var viewModel: VocabViewModel
    @ObservedObject var themeManager: ThemeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var jsonInputText: String = ""
    @State private var isShowingImportView: Bool = false

    private var inkColor: Color {
        themeManager.inkColor
    }

    private var mutedColor: Color {
        themeManager.mutedColor
    }

    private var canvasColor: Color {
        themeManager.canvasColor
    }

    var body: some View {
        NavigationStack {
            ZStack {
                canvasColor.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        // Section 1: Book Selection (Book 1 vs Book 2)
                        bookSelectionSection

                        // Section 2: Chapter Selection Grid
                        chapterGridSection

                        // Section 3: JLPT Level Filter
                        jlptFilterSection

                        // Section 4: Learning Status Filter
                        learningStatusFilterSection

                        // Section 5: Chapter Sheet Import Trigger
                        importChapterTriggerSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Chapters & Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(inkColor)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Clear All") {
                        viewModel.clearFilter()
                    }
                    .foregroundColor(Color(hex: "#BE123C"))
                }
            }
            .sheet(isPresented: $isShowingImportView) {
                importSheetView
            }
        }
    }

    // MARK: - Book Selection
    @ViewBuilder
    private var bookSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TEXTBOOK BOOK")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(mutedColor)

            HStack(spacing: 8) {
                bookButton(title: "All", isSelected: viewModel.filter.selectedBook == nil) {
                    viewModel.selectBook(nil)
                }

                ForEach(TextbookBook.allCases) { book in
                    bookButton(title: book.title, isSelected: viewModel.filter.selectedBook == book) {
                        viewModel.selectBook(book)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func bookButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? canvasColor : inkColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? inkColor : themeManager.segmentEmptyColor.opacity(0.35))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chapter Grid
    @ViewBuilder
    private var chapterGridSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("CHAPTER")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(mutedColor)

                Spacer()

                if viewModel.filter.selectedChapter != nil {
                    Button("All Chapters") {
                        viewModel.selectChapter(nil)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(inkColor)
                }
            }

            let startChapter = viewModel.filter.selectedBook == .book2 ? 26 : 1
            let endChapter = viewModel.filter.selectedBook == .book1 ? 25 : 50

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
                ForEach(startChapter...endChapter, id: \.self) { ch in
                    let isSelected = (viewModel.filter.selectedChapter == ch)
                    Button {
                        viewModel.selectChapter(isSelected ? nil : ch)
                    } label: {
                        Text("\(ch)")
                            .font(.system(size: 13, weight: isSelected ? .bold : .regular, design: .monospaced))
                            .foregroundColor(isSelected ? canvasColor : inkColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(isSelected ? inkColor : themeManager.segmentEmptyColor.opacity(0.35))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - JLPT Filter
    @ViewBuilder
    private var jlptFilterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("JLPT LEVEL")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(mutedColor)

            HStack(spacing: 8) {
                filterOptionButton(title: "All", isSelected: viewModel.filter.selectedJLPTLevel == nil) {
                    viewModel.selectJLPTLevel(nil)
                }
                filterOptionButton(title: "N5", isSelected: viewModel.filter.selectedJLPTLevel == .n5) {
                    viewModel.selectJLPTLevel(.n5)
                }
                filterOptionButton(title: "N4", isSelected: viewModel.filter.selectedJLPTLevel == .n4) {
                    viewModel.selectJLPTLevel(.n4)
                }
            }
        }
    }

    // MARK: - Learning Status Filter
    @ViewBuilder
    private var learningStatusFilterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LEARNING STATUS")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(mutedColor)

            HStack(spacing: 8) {
                filterOptionButton(title: "All", isSelected: viewModel.filter.selectedLearningStatus == nil) {
                    viewModel.selectLearningStatus(nil)
                }
                ForEach(VocabLearningState.allCases) { state in
                    filterOptionButton(title: state.label, isSelected: viewModel.filter.selectedLearningStatus == state) {
                        viewModel.selectLearningStatus(state)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func filterOptionButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? canvasColor : inkColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? inkColor : themeManager.segmentEmptyColor.opacity(0.35))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Import Chapter Trigger
    @ViewBuilder
    private var importChapterTriggerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CHAPTER VOCABULARY IMPORT")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(mutedColor)

            Button {
                isShowingImportView = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text("Import Chapter Vocabulary Sheet (JSON)")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .opacity(0.6)
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(inkColor)
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(themeManager.segmentEmptyColor.opacity(0.3))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 10)
    }

    // MARK: - Import Sheet
    @ViewBuilder
    private var importSheetView: some View {
        NavigationStack {
            ZStack {
                canvasColor.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Paste Chapter Vocabulary JSON")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(inkColor)

                        Text("Paste the chapter sheet JSON provided for Minna no Nihongo. Missing or invalid fields will be strictly validated and reported.")
                            .font(.system(size: 12))
                            .foregroundColor(mutedColor)

                        TextEditor(text: $jsonInputText)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(height: 220)
                            .padding(8)
                            .background(themeManager.segmentEmptyColor.opacity(0.2))
                            .cornerRadius(8)

                        if let error = viewModel.lastImportError {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(Color(hex: "#BE123C"))
                                Text(error)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(hex: "#BE123C"))
                            }
                            .padding(10)
                            .background(Color(hex: "#BE123C").opacity(0.1))
                            .cornerRadius(6)
                        }

                        if let res = viewModel.lastImportResult {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color(hex: "#16A34A"))
                                Text("Chapter \(res.chapterNumber) imported successfully! \(res.importedCount) new, \(res.updatedCount) updated.")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(hex: "#16A34A"))
                            }
                            .padding(10)
                            .background(Color(hex: "#16A34A").opacity(0.1))
                            .cornerRadius(6)
                        }

                        Button {
                            if viewModel.importChapter(jsonString: jsonInputText) {
                                jsonInputText = ""
                            }
                        } label: {
                            Text("Validate & Import Chapter")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(canvasColor)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(inkColor)
                                .cornerRadius(8)
                        }
                        .disabled(jsonInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .buttonStyle(.plain)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Import Sheet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        isShowingImportView = false
                    }
                    .foregroundColor(inkColor)
                }
            }
        }
    }
}
