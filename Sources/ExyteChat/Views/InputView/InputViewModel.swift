//
//  Created by Alex.M on 20.06.2022.
//

import Foundation
import Combine
import ExyteMediaPicker
import AVFAudio

@MainActor
final class InputViewModel: ObservableObject {
    
    @Published var text = ""
    @Published var attachments = InputViewAttachments()
    @Published var state: InputViewState = .empty
    
    @Published var showGiphyPicker = false
    @Published var showPicker = false
    @Published var showFiles = false

    @Published var mediaPickerMode = MediaPickerMode.photos
    
    @Published var showActivityIndicator = false
    
    var recordingPlayer: RecordingPlayer?
    var didSendMessage: ((DraftMessage) -> Void)?
    
//    private var recorder = Recorder()
    let recorder = AudioRecorder(numberOfSamples: 2, audioFormatID: kAudioFormatMPEG4AAC, audioQuality: .medium)
    
    private var saveEditingClosure: ((String) -> Void)?
    
    private var recordPlayerSubscription: AnyCancellable?
    private var subscriptions = Set<AnyCancellable>()
    
    func setRecorderSettings(recorderSettings: RecorderSettings = RecorderSettings()) {
        Task {
//            await self.recorder.setRecorderSettings(recorderSettings)
        }
    }
    
    func onStart() {
        subscribeValidation()
        subscribePicker()
        subscribeGiphyPicker()
        subscribeDocument()
    }
    
    func onStop() {
        subscriptions.removeAll()
    }
    
    func reset() {
        DispatchQueue.main.async { [weak self] in
            self?.showPicker = false
            self?.showFiles = false
            self?.showGiphyPicker = false
            self?.text = ""
            self?.saveEditingClosure = nil
            self?.attachments = InputViewAttachments()
            self?.subscribeValidation()
            self?.state = .empty
        }
    }
    
    func send() {
        Task {
            await recorder.stopRecording()
            await recordingPlayer?.reset()
            sendMessage()
        }
    }
    
    func edit(_ closure: @escaping (String) -> Void) {
        saveEditingClosure = closure
        state = .editing
    }
    
    func inputViewAction() -> (InputViewAction) -> Void {
        { [weak self] in
            self?.inputViewActionInternal($0)
        }
    }
    
    private func inputViewActionInternal(_ action: InputViewAction) {
        switch action {
        case .giphy:
            showGiphyPicker = true
        case .photo:
            mediaPickerMode = .photos
            showPicker = true
        case .add:
            mediaPickerMode = .camera
        case .camera:
            mediaPickerMode = .camera
            showPicker = true
        case .send:
            send()
        case .recordAudioTap:
            Task {
                state = await true ? .isRecordingTap : .waitingForRecordingPermission
                recordAudio()
            }
        case .recordAudioHold:
            Task {
                state = await true ? .isRecordingHold : .waitingForRecordingPermission
                recordAudio()
            }
        case .recordAudioLock:
            state = .isRecordingTap
        case .stopRecordAudio:
            Task {
                await recorder.stopRecording()
                if let _ = attachments.recording {
                    state = .hasRecording
                }
                await recordingPlayer?.reset()
            }
        case .deleteRecord:
            Task {
                unsubscribeRecordPlayer()
                await recorder.stopRecording()
                attachments.recording = nil
            }
        case .playRecord:
            state = .playingRecording
            if let recording = attachments.recording {
                Task {
                    subscribeRecordPlayer()
                    await recordingPlayer?.play(recording)
                }
            }
        case .pauseRecord:
            state = .pausedRecording
            Task {
                await recordingPlayer?.pause()
            }
        case .saveEdit:
            saveEditingClosure?(text)
            reset()
        case .cancelEdit:
            reset()
        case .document:
            showFiles = true
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private func recordAudio() {

        if recorder.recording { return }
        Task { @MainActor [recorder] in
            attachments.recording = Recording()
            let url = recorder.startRecording()
            recorder.$currentTime
                .receive(on: DispatchQueue.main)
                .sink { [weak self] time in
                self?.attachments.recording?.duration = time
            }
            .store(in: &cancellables)
            
            recorder.$soundSamples
                .receive(on: DispatchQueue.main)
                .sink { [weak self] samples in
                    self?.attachments.recording?.waveformSamples = samples
            }
            .store(in: &cancellables)

            if state == .waitingForRecordingPermission {
                state = .isRecordingTap
            }
            attachments.recording?.url = url
        }
    }
}

private extension InputViewModel {
    
    func validateDraft() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard state != .editing else { return } // special case
            if !self.text.isEmpty || !self.attachments.medias.isEmpty || self.attachments.documentUrl != nil {
                self.state = .hasTextOrMedia
            } else if self.text.isEmpty,
                      self.attachments.medias.isEmpty,
                      self.attachments.recording == nil {
                self.state = .empty
            }
        }
    }
    
    func subscribeValidation() {
        $attachments.sink { [weak self] _ in
            self?.validateDraft()
        }
        .store(in: &subscriptions)
        
        $text.sink { [weak self] _ in
            self?.validateDraft()
        }
        .store(in: &subscriptions)
    }
    
    func subscribeGiphyPicker() {
        $showGiphyPicker
            .sink { [weak self] value in
                if !value {
                    self?.attachments.giphyMedia = nil
                }
            }
            .store(in: &subscriptions)
    }
    
    func subscribePicker() {
        $showPicker
            .sink { [weak self] value in
                if !value {
                    self?.attachments.medias = []
                }
            }
            .store(in: &subscriptions)
    }
    
    func subscribeDocument() {
        $showFiles
            .sink { [weak self] value in
                if !value {
                    self?.attachments.documentUrl = nil
                }
            }
            .store(in: &subscriptions)
    }
    
    func subscribeRecordPlayer() {
        Task { @MainActor in
            if let recordingPlayer {
                recordPlayerSubscription = recordingPlayer.didPlayTillEnd
                    .sink { [weak self] in
                        self?.state = .hasRecording
                    }
            }
        }
    }
    
    func unsubscribeRecordPlayer() {
        recordPlayerSubscription = nil
    }
}

private extension InputViewModel {
    
    func sendMessage() {
        showActivityIndicator = true
        let draft = DraftMessage(
            text: self.text,
            medias: attachments.medias,
            giphyMedia: attachments.giphyMedia,
            recording: attachments.recording,
            replyMessage: attachments.replyMessage,
            createdAt: Date(),
            documentUrl: attachments.documentUrl
        )
        didSendMessage?(draft)
        DispatchQueue.main.async { [weak self] in
            self?.showActivityIndicator = false
            self?.reset()
        }
    }
}

public final class AudioRecorder: NSObject, ObservableObject {
    
    @Published public var recording = false
    @Published var currentTime: TimeInterval = 0
    @Published var soundSamples: [CGFloat] = []

    private let numberOfSamples: Int
    
    private var timer: Timer?
    
    public var audioRecorder = AVAudioRecorder()
    
    let audioFormatID: AudioFormatID
    let sampleRateKey: Float
    let noOfchannels: Int
    let audioQuality: AVAudioQuality
    
    public init(numberOfSamples: Int, audioFormatID: AudioFormatID, audioQuality: AVAudioQuality, noOfChannels: Int = 2, sampleRateKey: Float = 44100.0) {
        self.numberOfSamples = numberOfSamples
        self.audioFormatID = audioFormatID
        self.audioQuality = audioQuality
        self.noOfchannels = noOfChannels
        self.sampleRateKey = sampleRateKey
    }
    
    public func startRecording() -> URL? {
        
        do {
            
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord)
            try AVAudioSession.sharedInstance().setActive(true)
            
        } catch let error {
            return nil
            print("Failed to set up recording session \(error.localizedDescription)")
        }
        
        let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentPath.appendingPathComponent("\(UUID().uuidString).m4a")
        
        UserDefaults.standard.set(audioFilename.absoluteString, forKey: "tempUrl")
        
        let settings: [String:Any] = [
            AVFormatIDKey: audioFormatID,
            AVSampleRateKey: sampleRateKey,
            AVNumberOfChannelsKey: noOfchannels,
            AVEncoderAudioQualityKey: audioQuality.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder.record()
            recording = true
            startMonitoring()
            return audioFilename
        } catch {
            return nil
            print("Could not start recording")
        }
    }
    
    public func stopRecording() {
        audioRecorder.stop()
        recording = false
        stopMonitoring()
        saveRecording()
    }
    
    private func saveRecording() {
        if let tempUrl = UserDefaults.standard.string(forKey: "tempUrl") {
            if let url = URL(string: tempUrl) {
                if let data = try? Data(contentsOf: url) {
                    do {
                        try data.write(to: url, options: [.atomic, .completeFileProtection])
                    } catch {
                        print(error.localizedDescription)
                    }
                }
            }
        }
    }
    
    public func deleteRecording(url: URL, onSuccess: (() -> Void)?) {
        
        do {
            try FileManager.default.removeItem(at: url)
            onSuccess?()
        } catch {
            print("File could not be deleted!")
        }
    }
    
    private func startMonitoring() {
        
        audioRecorder.isMeteringEnabled = true
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            
            guard let this = self else { return }
            
            this.audioRecorder.updateMeters()
            this.currentTime = this.audioRecorder.currentTime
            let power = this.audioRecorder.averagePower(forChannel: 0)
            let adjustedPower = 1 - (max(power, -60) / 60 * -1)
            this.soundSamples.append(CGFloat(adjustedPower))
        }
    }
    
    func stopMonitoring() {
        audioRecorder.isMeteringEnabled = false
        timer?.invalidate()
    }
    
}
