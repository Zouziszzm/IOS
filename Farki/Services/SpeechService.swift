import Foundation
import AVFoundation

final class SpeechService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    static let shared = SpeechService()
    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?

    @Published var isSpeaking: Bool = false

    private let cacheDirectory: URL? = {
        let urls = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        guard let base = urls.first else { return nil }
        let dir = base.appendingPathComponent("FarkiAudioCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    override private init() {
        super.init()
        synthesizer.delegate = self
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            // Silently fallback if simulator or restricted
        }
    }

    /// Automatically discovers and selects the highest quality Japanese voice installed on the device
    /// Prioritizes: 1. Premium (Neural Siri), 2. Enhanced (Otoya/Kyoko Enhanced), 3. Default Compact
    private func bestJapaneseVoice() -> AVSpeechSynthesisVoice? {
        let japaneseVoices = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.hasPrefix("ja")
        }

        // 1. Check for Premium quality voice
        if let premium = japaneseVoices.first(where: { $0.quality == .premium }) {
            return premium
        }

        // 2. Check for Enhanced quality voice (e.g. Kyoko or Otoya Enhanced)
        if let enhanced = japaneseVoices.first(where: { $0.quality == .enhanced }) {
            return enhanced
        }

        // 3. Fallback to system default ja-JP
        return AVSpeechSynthesisVoice(language: "ja-JP")
    }

    /// Speaks the given Japanese text with studio-quality native human audio, falling back to AVSpeechSynthesizer if offline.
    func speak(text: String, phoneticReading: String? = nil, language: String = "ja-JP") {
        configureAudioSession()
        stop()

        let speechString: String
        if let kana = phoneticReading, !kana.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            speechString = kana
        } else {
            speechString = text
        }

        // Check if we have a locally cached natural native human audio file
        let cacheKey = speechString.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? UUID().uuidString
        if let cacheFile = cacheDirectory?.appendingPathComponent("\(cacheKey).mp3"),
           FileManager.default.fileExists(atPath: cacheFile.path) {
            playAudioFile(at: cacheFile) { [weak self] success in
                if !success {
                    self?.speakWithSynthesizer(speechString, language: language)
                }
            }
            return
        }

        // Try downloading natural human voice (Google Translate TTS endpoint)
        guard let encodedQuery = speechString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=ja&q=\(encodedQuery)") else {
            speakWithSynthesizer(speechString, language: language)
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 3.5

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  data.count > 100,
                  error == nil else {
                DispatchQueue.main.async {
                    self?.speakWithSynthesizer(speechString, language: language)
                }
                return
            }

            // Save to disk cache for instantaneous offline playback next time
            if let targetFile = self.cacheDirectory?.appendingPathComponent("\(cacheKey).mp3") {
                try? data.write(to: targetFile)
            }

            DispatchQueue.main.async {
                self.playAudioData(data) { success in
                    if !success {
                        self.speakWithSynthesizer(speechString, language: language)
                    }
                }
            }
        }.resume()
    }

    private func playAudioFile(at url: URL, completion: @escaping (Bool) -> Void) {
        do {
            self.audioPlayer = try AVAudioPlayer(contentsOf: url)
            self.audioPlayer?.delegate = self
            self.audioPlayer?.prepareToPlay()
            self.isSpeaking = true
            self.audioPlayer?.play()
            completion(true)
        } catch {
            completion(false)
        }
    }

    private func playAudioData(_ data: Data, completion: @escaping (Bool) -> Void) {
        do {
            self.audioPlayer = try AVAudioPlayer(data: data)
            self.audioPlayer?.delegate = self
            self.audioPlayer?.prepareToPlay()
            self.isSpeaking = true
            self.audioPlayer?.play()
            completion(true)
        } catch {
            completion(false)
        }
    }

    private func speakWithSynthesizer(_ text: String, language: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = bestJapaneseVoice() ?? AVSpeechSynthesisVoice(language: language)
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        if audioPlayer?.isPlaying == true {
            audioPlayer?.stop()
        }
        isSpeaking = false
    }

    // MARK: - AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = true
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
}
