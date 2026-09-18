import Foundation
import Speech
import AVFoundation

class VoiceRecognitionService: NSObject, SFSpeechRecognizerDelegate {
    static let shared = VoiceRecognitionService()
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private var isRecording = false
    
    var onPartialTranscription: ((String) -> Void)?
    var onFinalTranscription: ((String) -> Void)?
    var onError: ((Error) -> Void)?
    
    private override init() {
        super.init()
        speechRecognizer?.delegate = self
    }
    
    func requestPermissions(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        DispatchQueue.main.async {
                            completion(granted)
                        }
                    }
                default:
                    completion(false)
                }
            }
        }
    }
    
    func startRecording() throws {
        if isRecording { return }
        
        // Cancel any previous task
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }
        
        let inputNode = audioEngine.inputNode
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            
            if let result = result {
                self.onPartialTranscription?(result.bestTranscription.formattedString)
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.isRecording = false
                
                if let error = error {
                    self.onError?(error)
                } else if let result = result {
                    self.onFinalTranscription?(result.bestTranscription.formattedString)
                }
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
    }
    
    func stopRecording() {
        if !isRecording { return }
        audioEngine.stop()
        recognitionRequest?.endAudio()
        isRecording = false
    }
    
    func getIsRecording() -> Bool {
        return isRecording
    }
}
