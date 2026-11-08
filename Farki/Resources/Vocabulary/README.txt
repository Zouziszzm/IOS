# Vocabulary JSON Sheets Directory

Drop your chapter JSON files into this folder:
`Farki/Resources/Vocabulary/`

Example file names:
- `chapter_01.json`
- `chapter_02.json`
- `chapter_06.json`
- `chapter_25.json`

### Workflow to add new chapters:
1. Save your chapter JSON file into this folder (`Farki/Resources/Vocabulary/chapter_XX.json`).
2. Run `xcodegen generate` (or drag the JSON file into Xcode's Project Navigator under Resources/Vocabulary).
3. Build and run the app in Xcode!
4. The app will automatically discover the JSON, parse the chapter vocabulary, and populate:
   - Active vocabulary cards
   - Segmented progress bar
   - Smart chapter grid (unlocking and lighting up that chapter block)
   - Dashboard metrics (Vocab word counts and Shokyū I / II chapter counts)
