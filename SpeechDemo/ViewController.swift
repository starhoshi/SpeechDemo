import UIKit
import Speech
import AVFoundation

public class ViewController: UIViewController {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja_JP"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    @IBOutlet weak var recordButton : UIButton!
    @IBOutlet weak var textView: UITextView!

    public override func viewDidLoad() {
        super.viewDidLoad()

        recordButton.isEnabled = false
        speechRecognizer.delegate = self
    }

    override public func viewDidAppear(_ animated: Bool) {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    self.recordButton.isEnabled = true

                case .denied:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("User denied access to speech recognition", for: .disabled)

                case .restricted:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition restricted on this device", for: .disabled)

                case .notDetermined:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition not yet authorized", for: .disabled)
                }
            }
        }
    }

    private func startRecording() throws {
        // 開始時に音声認識中だったら止める
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }

        // マイクの認識に必要
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .default)
        try audioSession.setMode(.measurement)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        let inputNode = audioEngine.inputNode // 音声を input する

        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object") }

        // これ true にしないと途中の結果が返ってこない、最終結果だけ欲しい場合は false にする
        recognitionRequest.shouldReportPartialResults = true

        // A recognition task represents a speech recognition session.
        // We keep a reference to the task so that it can be cancelled.
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false

            if let result = result {
                isFinal = result.isFinal

                self.textView.text = result.bestTranscription.formattedString
                self.textView.isScrollEnabled = true
                let range = NSMakeRange(self.textView.text.count - 1, 0)
                self.textView.scrollRangeToVisible(range)
            }

            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)

                self.recognitionRequest = nil
                self.recognitionTask = nil

                self.textView.text = isFinal ? "isFinal = true" : error?.localizedDescription

                try! self.startRecording()
            }
        }

        // マイクからの入力を認識させる。ここを mp3 などの別ファイルにすることも可能
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }


    @IBAction func recordButtonTapped() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            recordButton.isEnabled = false
            recordButton.setTitle("Stopping", for: .disabled)
        } else {
            try! startRecording()
            recordButton.setTitle("Stop recording", for: [])
        }
    }

    let talker = AVSpeechSynthesizer()
    @IBAction func talkButtonTapped(_ sender: Any) {
        try! AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .duckOthers)
        let utterance = AVSpeechUtterance(string: "クックパッドは、クックパッド株式会社の運営による料理レシピのコミュニティウェブサイトである。 wikipedia")
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        talker.speak(utterance)
    }
}

extension ViewController: SFSpeechRecognizerDelegate {
    // 音声認識はオンラインじゃないと使えない
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        print("available", available)
        if available {
            recordButton.isEnabled = true
            recordButton.setTitle("Start Recording", for: [])
        } else {
            recordButton.isEnabled = false
            recordButton.setTitle("Recognition not available", for: .disabled)
        }
    }
}
