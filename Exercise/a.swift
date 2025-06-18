import UIKit
import Vision
import AVFoundation
import AudioToolbox
import ReplayKit
import Photos

// MARK: - ExerciseViewController 클래스 정의 및 프로토콜 구현
class ExerciseViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    // MARK: - 운동 상태 및 피드백 상태
    // 운동 상태 관련 프로퍼티
    var isStanceFeedbackPlaying = false
    var hasShownKneeInwardFeedback = false
    var lastGoodStanceTime: Date?
    var hasStartedExercise = false
    var isPositionCorrect = false
    var repetitions = 0
    var targetRepetitions: Int = 10 // 초기값, 필요에 따라 설정
    var targetSets: Int = 3         // 초기값, 필요에 따라 설정
    var restTime: Int = 30          // 초기값, 필요에 따라 설정
    var squatDepthThreshold: CGFloat = 80
    var holdStartTime: Date?
    var currentSet = 1
    var sessionStartTime: Date?
    var setSummaries: [String] = []
    var setStartTime: Date?
    var restTimer: Timer?
    var remainingRestTime: Int = 0
    var exerciseCompleted = false
    var caloriesBurned: Double = 0.0
    var exerciseStartTime: Date?  // 운동 시작 시간
    var calorieTimer: DispatchSourceTimer?
    // MARK: - Push-Up 미달 피드백 타이밍
    var lastFeedbackTime: TimeInterval = 0
    // MARK: - Timer 관련 프로퍼티
    var mainTimer: Timer?
    var countdownTimer: Timer?
    // 추가된 활동 시간 추적 변수
    var activeExerciseTime: TimeInterval = 0.0
    var lastActiveTime: Date?
    // 평균 속도 추적 변수
    var totalRepetitionTime: TimeInterval = 0.0
    var repetitionCountForAverage: Int = 0
    // MARK: - 피드백/음성 관련 프로퍼티
    let speechSynthesizer = AVSpeechSynthesizer()
    var isSpeechEnabled: Bool = true
    var vibrationEnabled: Bool {
        return UserDefaults.standard.bool(forKey: "isVibrationEnabled")
    }
    // For restoring feedback text after knee-hand separation
    var previousFeedbackText: String?
    // MARK: - 운동 준비 상태
    var squatReady = false
    var pullUpReady = false
    var squatDetectionStartTime: Date?
    // 턱걸이 관련 상태 변수
    var isBarGrabbed: Bool = false
    var barGrabStartTime: Date?
    var barReleaseStartTime: Date?
    var lastWristY: CGFloat?
    var lastWristUpdateTime: Date?
    // 녹화 미리보기 저장용 프로퍼티
    var recordedPreviewController: RPPreviewViewController?

    // MARK: - 열거형 정의
    enum ExerciseMode {
        case squat
        case pushUp
        case pullUp
    }
    
    // MARK: - 기본 프로퍼티 정의
    var selectedMode: ExerciseMode = .squat  // default; will be overwritten by caller
    var captureSession = AVCaptureSession()
    var currentCameraPosition: AVCaptureDevice.Position = .back
    var bodyPoseRequest = VNDetectHumanBodyPoseRequest()
    var previewLayer: AVCaptureVideoPreviewLayer!
    var overlayLayer = CAShapeLayer()
    var lastRepetitionTime: Date?
    
    // MARK: - UI Elements
    // Helper method to create standardized UILabels
    func createLabel(fontSize: CGFloat, weight: UIFont.Weight = .regular, textColor: UIColor = .white, alignment: NSTextAlignment = .center) -> UILabel {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: fontSize, weight: weight)
        label.textColor = textColor
        label.textAlignment = alignment
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    let switchCameraButton: UIButton = {
        let button = UIButton(type: .system)
        let image = UIImage(systemName: "camera.rotate")
        button.setImage(image, for: .normal)
        button.tintColor = .white
        button.layer.cornerRadius = 20
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    let soundToggleButton: UIButton = {
        let button = UIButton(type: .system)
        let image = UIImage(systemName: "speaker.wave.2.fill")
        button.setImage(image, for: .normal)
        button.tintColor = .white
        button.layer.cornerRadius = 20
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    let recordToggleButton: UIButton = {
        let button = UIButton(type: .system)
        let image = UIImage(systemName: "record.circle")  // 녹화 전 상태 아이콘
        button.setImage(image, for: .normal)
        button.tintColor = .white
        button.layer.cornerRadius = 20
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    let timerLabel: UILabel = {
        let label = UILabel()
        label.text = "00:00"
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 20, weight: .medium)
        label.textColor = .white
        label.backgroundColor = UIColor.red
        label.textAlignment = .center
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    lazy var feedbackMessageLabel: UILabel = {
        let label = createLabel(fontSize: 16, weight: .medium)
        label.text = "운동을 시작하세요!"
        label.backgroundColor = .clear
        label.numberOfLines = 0
        return label
    }()
    
    // 카운트다운 프로그레스 바
    let countdownProgressLayer = CAShapeLayer()
    
    // 카운트다운 레이블 (카메라 뷰 중앙)
    lazy var countdownLabel: UILabel = {
        let label = createLabel(fontSize: 80, weight: .bold)
        label.text = ""
        label.backgroundColor = .clear
        label.layer.cornerRadius = 100
        label.layer.masksToBounds = true
        label.isHidden = true
        return label
    }()
    
    // 카메라 뷰 (중앙 영역)
    let cameraView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.layer.cornerRadius = 10
        view.layer.masksToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // 정보 스택뷰 (반복 횟수, 세트 수, 평균 속도, 칼로리)
    let infoStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 5
        stackView.alignment = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    // 정보 제목 스택뷰
    let infoTitlesStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 20
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    // 정보 값 스택뷰
    let infoValuesStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 20
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    // 반복 횟수 제목 레이블
    lazy var repetitionsTitleLabel: UILabel = {
        let label = createLabel(fontSize: 16, weight: .regular, textColor: .gray)
        label.text = "반복 횟수"
        return label
    }()
    
    // 세트 수 제목 레이블
    lazy var setsTitleLabel: UILabel = {
        let label = createLabel(fontSize: 16, weight: .regular, textColor: .gray)
        label.text = "세트 수"
        return label
    }()
    
    // 평균 속도 제목 레이블
    lazy var averageSpeedTitleLabel: UILabel = {
        let label = createLabel(fontSize: 16, weight: .regular, textColor: .gray)
        label.text = "평균 속도"
        return label
    }()
    
    // 칼로리 제목 레이블
    lazy var caloriesTitleLabel: UILabel = {
        let label = createLabel(fontSize: 16, weight: .regular, textColor: .gray)
        label.text = "칼로리"
        return label
    }()
    
    // 반복 횟수 값 레이블
    lazy var repetitionsValueLabel: UILabel = {
        let label = createLabel(fontSize: 16, weight: .bold)
        label.text = "0 / 10"
        return label
    }()
    
    // 세트 수 값 레이블
    lazy var setsValueLabel: UILabel = {
        let label = createLabel(fontSize: 16, weight: .bold)
        label.text = "1 / 3"
        return label
    }()
    
    // 평균 속도 값 레이블
    lazy var averageSpeedValueLabel: UILabel = {
        let label = createLabel(fontSize: 16, weight: .bold)
        label.text = "0.0초"
        return label
    }()
    
    // 칼로리 값 레이블
    lazy var caloriesValueLabel: UILabel = {
        let label = createLabel(fontSize: 16, weight: .bold)
        label.text = "0.00 kcal"
        return label
    }()
    
    // 일시정지 및 재시작 버튼
    let pauseResumeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("일시정지", for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.systemBlue
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // 종료 버튼
    let stopButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("종료", for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.systemRed
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - CustomSummaryViewController 서브클래스 (운동 기록 모달)
    class CustomExerciseRecordSummaryViewController: ExerciseRecordSummaryViewController {
        var onDismiss: (() -> Void)?
        
        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            if self.isBeingDismissed {
                onDismiss?()
            }
        }
    }
    
    // MARK: - 뷰 라이프사이클
    override func viewDidLoad() {
        super.viewDidLoad()
        self.overrideUserInterfaceStyle = .dark
        
        // UserDefaults에서 음성 사용 여부 불러오기 (기본 true)
        if let savedSpeechEnabled = UserDefaults.standard.value(forKey: "isSpeechEnabled") as? Bool {
            isSpeechEnabled = savedSpeechEnabled
        } else {
            isSpeechEnabled = true
        }
        speechSynthesizer.delegate = self
        setupUI()
        setupCamera()
        setupCountdownProgress()
        setupSoundToggle()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        
        // 필요한 사용자 설정 불러오기 (반복/세트/휴식 시간 등)
        if let savedTargetRepetitions = UserDefaults.standard.value(forKey: "targetRepetitions") as? Int, savedTargetRepetitions > 0 {
            targetRepetitions = savedTargetRepetitions
        }
        if let savedTargetSets = UserDefaults.standard.value(forKey: "targetSets") as? Int, savedTargetSets > 0 {
            targetSets = savedTargetSets
        }
        if let savedRestTime = UserDefaults.standard.value(forKey: "restTime") as? Int, savedRestTime > 0 {
            restTime = savedRestTime
        }
        
        startExercise()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = cameraView.bounds
        overlayLayer.frame = cameraView.bounds
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
        NotificationCenter.default.removeObserver(self)
    }
    
    deinit {
        calorieTimer?.cancel()
        mainTimer?.invalidate()
        restTimer?.invalidate()
        countdownTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - UI Setup
    func setupUI() {
        view.backgroundColor = .black
        
        view.addSubview(switchCameraButton)
        NSLayoutConstraint.activate([
            switchCameraButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            switchCameraButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            switchCameraButton.widthAnchor.constraint(equalToConstant: 40),
            switchCameraButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        switchCameraButton.addTarget(self, action: #selector(switchCamera), for: .touchUpInside)
        
        view.addSubview(soundToggleButton)
        NSLayoutConstraint.activate([
            soundToggleButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            soundToggleButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            soundToggleButton.widthAnchor.constraint(equalToConstant: 40),
            soundToggleButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        soundToggleButton.addTarget(self, action: #selector(toggleSound), for: .touchUpInside)
        
        view.addSubview(recordToggleButton)
        NSLayoutConstraint.activate([
            recordToggleButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            recordToggleButton.trailingAnchor.constraint(equalTo: soundToggleButton.leadingAnchor, constant: -20),
            recordToggleButton.widthAnchor.constraint(equalToConstant: 40),
            recordToggleButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        recordToggleButton.addTarget(self, action: #selector(toggleRecording), for: .touchUpInside)
        
        view.addSubview(timerLabel)
        NSLayoutConstraint.activate([
            timerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            timerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            timerLabel.widthAnchor.constraint(equalToConstant: 100),
            timerLabel.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        view.addSubview(feedbackMessageLabel)
        NSLayoutConstraint.activate([
            feedbackMessageLabel.topAnchor.constraint(equalTo: timerLabel.bottomAnchor, constant: 10),
            feedbackMessageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            feedbackMessageLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            feedbackMessageLabel.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        view.addSubview(cameraView)
        NSLayoutConstraint.activate([
            cameraView.topAnchor.constraint(equalTo: feedbackMessageLabel.bottomAnchor, constant: 10),
            cameraView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cameraView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cameraView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.6)
        ])
        
        infoTitlesStackView.addArrangedSubview(repetitionsTitleLabel)
        infoTitlesStackView.addArrangedSubview(setsTitleLabel)
        infoTitlesStackView.addArrangedSubview(averageSpeedTitleLabel)
        infoTitlesStackView.addArrangedSubview(caloriesTitleLabel)
        
        infoValuesStackView.addArrangedSubview(repetitionsValueLabel)
        infoValuesStackView.addArrangedSubview(setsValueLabel)
        infoValuesStackView.addArrangedSubview(averageSpeedValueLabel)
        infoValuesStackView.addArrangedSubview(caloriesValueLabel)
        
        infoStackView.addArrangedSubview(infoTitlesStackView)
        infoStackView.addArrangedSubview(infoValuesStackView)
        
        view.addSubview(infoStackView)
        NSLayoutConstraint.activate([
            infoStackView.topAnchor.constraint(equalTo: cameraView.bottomAnchor, constant: 10),
            infoStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            infoStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            infoStackView.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        let buttonsStackView = UIStackView(arrangedSubviews: [pauseResumeButton, stopButton])
        buttonsStackView.axis = .horizontal
        buttonsStackView.spacing = 20
        buttonsStackView.alignment = .fill
        buttonsStackView.distribution = .fillEqually
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonsStackView)
        NSLayoutConstraint.activate([
            buttonsStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            buttonsStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            buttonsStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            buttonsStackView.heightAnchor.constraint(equalToConstant: 60)
        ])
        pauseResumeButton.addTarget(self, action: #selector(togglePauseResume), for: .touchUpInside)
        stopButton.addTarget(self, action: #selector(stopExercise), for: .touchUpInside)
        
        view.addSubview(countdownLabel)
        NSLayoutConstraint.activate([
            countdownLabel.centerXAnchor.constraint(equalTo: cameraView.centerXAnchor),
            countdownLabel.centerYAnchor.constraint(equalTo: cameraView.centerYAnchor),
            countdownLabel.widthAnchor.constraint(equalToConstant: 200),
            countdownLabel.heightAnchor.constraint(equalToConstant: 200)
        ])
    }
    
    // MARK: - 소리 토글 버튼 설정
    func setupSoundToggle() {
        updateSoundToggleButton()
    }
    
    @objc func toggleSound() {
        isSpeechEnabled.toggle()
        UserDefaults.standard.set(isSpeechEnabled, forKey: "isSpeechEnabled")
        updateSoundToggleButton()
    }
    
    func updateSoundToggleButton() {
        let imageName = isSpeechEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill"
        let image = UIImage(systemName: imageName)
        soundToggleButton.setImage(image, for: .normal)
    }
    
    // MARK: - 녹화 미리보기 컨트롤러 설정 헬퍼
    func configureRecordedPreviewController(_ controller: RPPreviewViewController) {
        controller.previewControllerDelegate = self
        self.recordedPreviewController = controller
    }

    // MARK: - 녹화 토글 메서드 (ReplayKit)
    @objc func toggleRecording() {
        let recorder = RPScreenRecorder.shared()
        if !recorder.isRecording {
            recorder.isMicrophoneEnabled = true
            recorder.startRecording { error in
                if let _ = error {
                    // 오류 처리
                } else {
                    DispatchQueue.main.async {
                        let image = UIImage(systemName: "stop.circle")
                        self.recordToggleButton.setImage(image, for: .normal)
                    }
                }
            }
        } else {
            recorder.stopRecording { previewController, error in
                if let _ = error {
                    // 오류 처리
                }
                DispatchQueue.main.async {
                    let image = UIImage(systemName: "record.circle")
                    self.recordToggleButton.setImage(image, for: .normal)
                }
                if let previewController = previewController {
                    self.configureRecordedPreviewController(previewController)
                }
            }
        }
    }
    
    // MARK: - 카운트다운 프로그레스 바 설정
    func setupCountdownProgress() {
        let circularPath = UIBezierPath(arcCenter: CGPoint(x: 100, y: 100),
                                        radius: 90,
                                        startAngle: -CGFloat.pi / 2,
                                        endAngle: 1.5 * CGFloat.pi,
                                        clockwise: true)
        countdownProgressLayer.path = circularPath.cgPath
        countdownProgressLayer.strokeColor = UIColor.systemGreen.cgColor
        countdownProgressLayer.lineWidth = 10
        countdownProgressLayer.fillColor = UIColor.clear.cgColor
        countdownProgressLayer.strokeEnd = 0
        countdownProgressLayer.lineCap = .round
        countdownLabel.layer.addSublayer(countdownProgressLayer)
    }
    
    // MARK: - 카메라 초기화 메서드
    func setupCamera() {
        checkCameraAuthorization { [weak self] granted in
            guard let self = self else { return }
            if granted {
                self.captureSession.sessionPreset = .high
                self.currentCameraPosition = .front
                self.configureCamera(position: self.currentCameraPosition)
                
                let output = AVCaptureVideoDataOutput()
                output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
                if self.captureSession.canAddOutput(output) {
                    self.captureSession.addOutput(output)
                } else {
                    self.displayError(message: "출력을 캡처 세션에 추가할 수 없습니다.")
                    return
                }
                
                self.previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
                self.previewLayer.videoGravity = .resizeAspectFill
                self.previewLayer.frame = self.cameraView.bounds
                self.cameraView.layer.insertSublayer(self.previewLayer, at: 0)
                
                self.overlayLayer.strokeColor = UIColor.orange.cgColor
                self.overlayLayer.lineWidth = 2.0
                self.overlayLayer.fillColor = UIColor.clear.cgColor
                self.cameraView.layer.addSublayer(self.overlayLayer)
            } else {
                self.displayError(message: "카메라 권한이 필요합니다.")
            }
        }
    }
    
    // MARK: - 카메라 권한 확인 메서드
    func checkCameraAuthorization(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        default:
            completion(false)
        }
    }
    
    // MARK: - 카메라 설정 메서드
    func configureCamera(position: AVCaptureDevice.Position) {
        captureSession.beginConfiguration()
        captureSession.inputs.forEach { captureSession.removeInput($0) }
        
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            self.displayError(message: "해당 위치에 카메라를 찾을 수 없습니다: \(position)")
            captureSession.commitConfiguration()
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                currentCameraPosition = position
            } else {
                self.displayError(message: "카메라 입력을 캡처 세션에 추가할 수 없습니다.")
            }
        } catch {
            self.displayError(message: "카메라 입력 설정 오류: \(error)")
        }
        captureSession.commitConfiguration()
    }
    
    
    // MARK: - 앱 라이프사이클 핸들러
    @objc func appWillResignActive() {
        stopCalorieTimer()
        mainTimer?.invalidate()
    }
    
    @objc func appDidBecomeActive() {
        if captureSession.isRunning && !exerciseCompleted {
            startCalorieTimer()
            startMainTimer()
        }
    }
    
    // MARK: - 운동 시작 메서드
    func startExercise() {
        currentSet = 1
        repetitions = 0
        sessionStartTime = nil
        setStartTime = Date()
        setSummaries.removeAll()
        hasStartedExercise = false
        caloriesBurned = 0.0
        activeExerciseTime = 0.0
        lastActiveTime = nil
        totalRepetitionTime = 0.0
        repetitionCountForAverage = 0
        exerciseStartTime = nil

        if selectedMode == .pullUp {
            isBarGrabbed = false
            barGrabStartTime = nil
            barReleaseStartTime = nil
        }

        repetitionsValueLabel.text = "0 / \(targetRepetitions)"
        setsValueLabel.text = "\(currentSet) / \(targetSets)"
        averageSpeedValueLabel.text = "0.0초"
        caloriesValueLabel.text = "0.00 kcal"
        timerLabel.text = "00:00"
        feedbackMessageLabel.text = "운동을 시작합니다..."
        overlayLayer.strokeColor = UIColor.orange.cgColor

        switch selectedMode {
        case .squat:
            feedbackMessageLabel.text = "화면에전신이 보이게 서주세요!"
            squatReady = false
            cameraView.isHidden = false
            captureSession.startRunning()
        case .pullUp:
            feedbackMessageLabel.text = "봉을 잡으세요!"
            pullUpReady = false
            cameraView.isHidden = false
            captureSession.startRunning()
        case .pushUp:
            feedbackMessageLabel.text = "카메라를 주시한 상태로 엎드리세요"
            hasStartedExercise = false
            // Reset shallow-zone flag and feedback timer at the start of push-up session
            self.wasInShallowZone = false
            self.lastFeedbackTime = Date().timeIntervalSince1970
            cameraView.isHidden = false
            captureSession.startRunning()
            break
        }
    }
    
    // MARK: - 카운트다운 구현
    func startCountdown() {
        cameraView.isHidden = true
        var countdown = 3
        countdownLabel.text = "\(countdown)"
        countdownLabel.isHidden = false
        countdownProgressLayer.strokeEnd = 0

        let progressAnimation = CABasicAnimation(keyPath: "strokeEnd")
        progressAnimation.fromValue = 0
        progressAnimation.toValue = 1
        progressAnimation.duration = 3.0
        countdownProgressLayer.add(progressAnimation, forKey: "progressAnimation")
        countdownProgressLayer.strokeEnd = 1

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            countdown -= 1
            if countdown > 0 {
                self.countdownLabel.text = "\(countdown)"
            } else {
                timer.invalidate()
                self.countdownTimer = nil
                self.countdownLabel.isHidden = true
                self.cameraView.isHidden = false
                DispatchQueue.global(qos: .userInitiated).async {
                    self.captureSession.startRunning()
                }
                self.feedbackMessageLabel.text = (self.selectedMode == .pullUp) ? "봉을 잡으세요!" : "운동을 시작하세요!"
                self.startCalorieTimer()
                self.startMainTimer()
            }
        }
    }
    
    // MARK: - 운동 데이터 저장 (요약)
    func saveExerciseSummary() {
        let endTime = Date()
        let exerciseName: String
        switch selectedMode {
        case .squat: exerciseName = "스쿼트"
        case .pushUp: exerciseName = "푸쉬업"
        case .pullUp: exerciseName = "턱걸이"
        
        }
        let summary: [String: Any] = [
            "date": endTime,
            "exerciseType": exerciseName,
            "sets": currentSet,
            "reps": repetitions,
            "calories": caloriesBurned,
            "duration": endTime.timeIntervalSince(exerciseStartTime ?? endTime),
            "averageSpeed": (repetitionCountForAverage > 0) ? totalRepetitionTime / Double(repetitionCountForAverage) : 0.0,
            "restTime": restTime
        ]
        
        var exerciseData = UserDefaults.standard.array(forKey: "exerciseSummaries") as? [[String: Any]] ?? []
        exerciseData.append(summary)
        UserDefaults.standard.setValue(exerciseData, forKey: "exerciseSummaries")
    }
    
    // MARK: - 운동 정지 액션
    @objc func stopExercise() {
        stopCameraAndTimers()
        feedbackMessageLabel.text = "운동 종료"
        UIApplication.shared.isIdleTimerDisabled = false
        
        let recorder = RPScreenRecorder.shared()
        if recorder.isRecording {
            recorder.stopRecording { previewController, error in
                if let _ = error {
                    // 오류 처리
                }
                DispatchQueue.main.async {
                    let image = UIImage(systemName: "record.circle")
                    self.recordToggleButton.setImage(image, for: .normal)
                }
                if let previewController = previewController {
                    self.configureRecordedPreviewController(previewController)
                }
                self.displaySessionSummary()
                self.saveExerciseSummary()
            }
        } else {
            self.displaySessionSummary()
            self.saveExerciseSummary()
        }
    }
    // MARK: - 카메라 및 타이머 정지 헬퍼
    func stopCameraAndTimers() {
        captureSession.stopRunning()
        stopCalorieTimer()
        mainTimer?.invalidate()
        mainTimer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        cameraView.isHidden = true
    }
    
    // MARK: - 일시정지 및 재시작 액션
    @objc func togglePauseResume() {
        if captureSession.isRunning {
            captureSession.stopRunning()
            stopCalorieTimer()
            mainTimer?.invalidate()
            pauseResumeButton.setTitle("재시작", for: .normal)
            feedbackMessageLabel.text = "운동이 일시정지되었습니다."
        } else {
            captureSession.startRunning()
            startCalorieTimer()
            startMainTimer()
            pauseResumeButton.setTitle("일시정지", for: .normal)
            feedbackMessageLabel.text = "운동을 재개했습니다."
        }
    }
    
    // MARK: - 카메라 전환 액션
    @objc func switchCamera() {
        let newPosition: AVCaptureDevice.Position = (currentCameraPosition == .back) ? .front : .back
        configureCamera(position: newPosition)
    }
    
    // MARK: - 운동 기록 표시 (요약 모달)
    func displaySessionSummary() {
        let exerciseEndTime = Date()
        let totalDuration = (exerciseStartTime != nil) ? exerciseEndTime.timeIntervalSince(exerciseStartTime!) : 0.0
        let averageSpeed: Double = (repetitionCountForAverage > 0) ? totalRepetitionTime / Double(repetitionCountForAverage) : 0.0
        
        let record: [String: Any] = [
            "date": exerciseEndTime,
            "exerciseType": {
                switch selectedMode {
                case .squat: return "스쿼트"
                case .pushUp: return "푸쉬업"
                case .pullUp: return "턱걸이"
                
                }
            }(),
            "sets": currentSet,
            "reps": repetitions,
            "duration": totalDuration,
            "averageSpeed": averageSpeed,
            "calories": caloriesBurned
        ]
        
        let summaryVC = CustomExerciseRecordSummaryViewController()
        summaryVC.record = record
        summaryVC.modalPresentationStyle = .pageSheet
        if let sheet = summaryVC.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        summaryVC.onDismiss = { [weak self] in
            self?.dismissSummary()
        }
        
        cameraView.isHidden = true
        feedbackMessageLabel.text = "운동 종료"
        present(summaryVC, animated: true, completion: nil)
    }
    
    // MARK: - 모달 닫기 및 홈화면 전환
    @objc func dismissSummary() {
        if let navigationController = self.navigationController {
            navigationController.popToRootViewController(animated: true)
        } else {
            self.dismiss(animated: true, completion: nil)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let previewVC = self.recordedPreviewController {
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = scene.windows.first(where: { $0.isKeyWindow }),
                   let rootVC = window.rootViewController {
                    rootVC.present(previewVC, animated: true, completion: nil)
                } else {
                    self.present(previewVC, animated: true, completion: nil)
                }
                self.recordedPreviewController = nil
            }
        }
        cameraView.isHidden = true
        feedbackMessageLabel.text = "운동 종료"
    }
    
    // MARK: - 피드백 메시지 업데이트
    func updateFeedbackMessage(text: String) {
        feedbackMessageLabel.text = text
    }
    
    // MARK: - BMR 및 칼로리 계산
    func calculateBMR(gender: Int, age: Int, height: Double, weight: Double) -> Double {
        return (gender == 0) ?
            88.362 + (13.397 * weight) + (4.799 * height) - (5.677 * Double(age)) :
            447.593 + (9.247 * weight) + (3.098 * height) - (4.330 * Double(age))
    }
    
    func calculateCaloriesBurned(exerciseMode: ExerciseMode, activeExerciseTime: TimeInterval) -> Double {
        let weight = UserDefaults.standard.double(forKey: "weight")
        let height = UserDefaults.standard.double(forKey: "height")
        let age = UserDefaults.standard.integer(forKey: "age")
        let genderIndex = UserDefaults.standard.integer(forKey: "gender")
        
        guard weight > 0, height > 0, age > 0, (genderIndex == 0 || genderIndex == 1) else {
            return 0.0
        }
        
        let bmr = calculateBMR(gender: genderIndex, age: age, height: height, weight: weight)
        let mets: Double = {
            switch exerciseMode {
            case .squat: return 5.0
            case .pushUp: return 3.8
            case .pullUp: return 8.0
            
            }
        }()
        
        let activeMinutes = activeExerciseTime / 60.0
        return mets * (bmr / 1440.0) * activeMinutes
    }
    
    // MARK: - 반복 카운트
    func countRepetition() {
        let currentTime = Date()
        var timePerRep: TimeInterval = 2.0
        if let lastTime = lastRepetitionTime {
            timePerRep = currentTime.timeIntervalSince(lastTime)
            totalRepetitionTime += timePerRep
            repetitionCountForAverage += 1
        }
        lastRepetitionTime = currentTime
        repetitions += 1
        
        AudioServicesPlaySystemSound(1104)
        caloriesBurned = calculateCaloriesBurned(exerciseMode: selectedMode, activeExerciseTime: activeExerciseTime)
        caloriesValueLabel.text = String(format: "%.2f kcal", caloriesBurned)
        repetitionsValueLabel.text = "\(repetitions) / \(targetRepetitions)"
        
        if repetitionCountForAverage > 0 {
            let averageSpeed = totalRepetitionTime / Double(repetitionCountForAverage)
            averageSpeedValueLabel.text = String(format: "%.1f초", averageSpeed)
        }
        
        if repetitions >= targetRepetitions {
            completeSet()
        }
        
        animateTimerLabel()
        timerLabel.backgroundColor = .systemGreen
        overlayLayer.strokeColor = UIColor.systemGreen.cgColor
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.timerLabel.backgroundColor = .red
            self.overlayLayer.strokeColor = UIColor.orange.cgColor
        }
        
        speakNumber(count: repetitions)
    }
    
    // MARK: - 타이머 애니메이션 및 음성 피드백
    func animateTimerLabel() {
        UIView.animate(withDuration: 0.2, animations: {
            self.timerLabel.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                self.timerLabel.transform = CGAffineTransform.identity
            }
        }
    }
    
    func speakNumber(count: Int) {
        guard isSpeechEnabled else { return }
        let numberString = koreanNumber(for: count)
        speak(numberString)
    }
    // MARK: - 음성 출력 헬퍼 메서드
    func speak(_ text: String) {
        guard isSpeechEnabled else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ko-KR")
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0
        speechSynthesizer.speak(utterance)
    }
    
    func koreanNumber(for count: Int) -> String {
        if count < 0 { return "" }
        if count == 0 { return "영" }
        let tensWords = ["", "열", "스물", "서른", "마흔", "쉰"]
        let onesWords = ["", "하나", "둘", "셋", "넷", "다섯", "여섯", "일곱", "여덟", "아홉"]
        let tens = count / 10
        let ones = count % 10
        if ones == 0 {
            return (tens < tensWords.count) ? tensWords[tens] : "\(count)"
        } else {
            return (tens < tensWords.count && ones < onesWords.count) ? tensWords[tens] + onesWords[ones] : "\(count)"
        }
    }
    
    // MARK: - 휴식 타이머 & 다음 세트 시작
    func startRestTimer() {
        remainingRestTime = restTime
        updateRestCountdown()
        cameraView.isHidden = true
        feedbackMessageLabel.text = "휴식 시간 시작"
        countdownLabel.text = "\(remainingRestTime)"
        countdownLabel.isHidden = false
        countdownProgressLayer.strokeEnd = 0
        
        let progressAnimation = CABasicAnimation(keyPath: "strokeEnd")
        progressAnimation.fromValue = 0
        progressAnimation.toValue = 1
        progressAnimation.duration = TimeInterval(restTime)
        countdownProgressLayer.add(progressAnimation, forKey: "restProgressAnimation")
        countdownProgressLayer.strokeEnd = 1
        
        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            self.remainingRestTime -= 1
            self.updateRestCountdown()
            if self.remainingRestTime <= 0 {
                timer.invalidate()
                self.feedbackMessageLabel.text = "휴식 시간 종료"
                self.startNextSet()
            }
        }
    }
    
    func updateRestCountdown() {
        countdownLabel.text = "\(remainingRestTime)"
    }
    
    func startNextSet() {
        currentSet += 1
        repetitions = 0
        repetitionsValueLabel.text = "0 / \(targetRepetitions)"
        averageSpeedValueLabel.text = (repetitionCountForAverage > 0) ? String(format: "%.1f초", totalRepetitionTime / Double(repetitionCountForAverage)) : "0.0초"
        setsValueLabel.text = "\(currentSet) / \(targetSets)"
        infoStackView.layoutIfNeeded()
        updateFeedbackMessage(text: "다음 세트 시작!")
        setStartTime = Date()

        if currentSet > targetSets {
            stopExercise()
        } else {
            cameraView.isHidden = false
            if selectedMode == .pullUp {
                isBarGrabbed = false
                barGrabStartTime = nil
                barReleaseStartTime = nil
                feedbackMessageLabel.text = "봉을 잡으세요!"
            } else {
                feedbackMessageLabel.text = "운동을 시작하세요!"
            }
            captureSession.startRunning()
            DispatchQueue.main.async {
                self.cameraView.backgroundColor = .clear
                self.countdownLabel.isHidden = true
                self.countdownProgressLayer.strokeEnd = 0
                self.overlayLayer.strokeColor = UIColor.orange.cgColor
            }
            self.startCalorieTimer()
            self.startMainTimer()
        }
    }
    
    // MARK: - Complete Set
    func completeSet() {
        let elapsedTime = Date().timeIntervalSince(setStartTime ?? Date())
        setSummaries.append("세트 \(currentSet): \(repetitions)회, 시간: \(Int(elapsedTime))초, 휴식: \(restTime)초")
        
        if currentSet >= targetSets {
            stopExercise()
        } else {
            feedbackMessageLabel.text = "휴식 시간 시작"
            captureSession.stopRunning()
            stopCalorieTimer()
            startRestTimer()
        }
    }
    
    // MARK: - 운동 측정 메소드 (스쿼트, 푸쉬업, 턱걸이 등)
    func analyzeSquat(results: VNHumanBodyPoseObservation) {
        guard let recognizedPoints = try? results.recognizedPoints(.all) else { return }
        // 1. Check ankle-to-ankle width vs shoulder width (stance check) BEFORE count logic
        if let leftAnkle = recognizedPoints[.leftAnkle],
           let rightAnkle = recognizedPoints[.rightAnkle],
           let leftShoulder = recognizedPoints[.leftShoulder],
           let rightShoulder = recognizedPoints[.rightShoulder] {

            let laPos = previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: leftAnkle.location.x, y: 1 - leftAnkle.location.y))
            let raPos = previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: rightAnkle.location.x, y: 1 - rightAnkle.location.y))
            let lsPos = previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: leftShoulder.location.x, y: 1 - leftShoulder.location.y))
            let rsPos = previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: rightShoulder.location.x, y: 1 - rightShoulder.location.y))

            let ankleWidth = abs(laPos.x - raPos.x)
            let shoulderWidth = abs(lsPos.x - rsPos.x)

            let narrowStanceThreshold = shoulderWidth * 0.8
            if ankleWidth < narrowStanceThreshold {
                self.lastGoodStanceTime = nil
                DispatchQueue.main.async {
                    if self.previousFeedbackText == nil {
                        self.previousFeedbackText = self.feedbackMessageLabel.text
                    }
                    // Only update label if the text is changing to the stance feedback
                    if self.feedbackMessageLabel.text != "다리를 어깨 넓이로 벌려주세요" {
                        self.feedbackMessageLabel.text = "다리를 어깨 넓이로 벌려주세요"
                    }
                }
                // Play sound every time the label changes to the feedback text and not already playing
                if self.isSpeechEnabled && !self.isStanceFeedbackPlaying {
                    self.isStanceFeedbackPlaying = true
                    self.speak("다리를 어깨 넓이로 벌려주세요")
                }
                return
            } else {
                if self.lastGoodStanceTime == nil {
                    self.lastGoodStanceTime = Date()
                }

                if let prev = self.previousFeedbackText,
                   prev == "다리를 어깨 넓이로 벌려주세요",
                   let lastTime = self.lastGoodStanceTime,
                   Date().timeIntervalSince(lastTime) > 1.0,
                   !self.speechSynthesizer.isSpeaking {
                    DispatchQueue.main.async {
                        self.feedbackMessageLabel.text = "운동을 시작하세요!"
                    }
                    self.previousFeedbackText = nil
                }
            }
        }
        // 손을 무릎에 붙이고 스쿼트 시 카운트 무효화 및 피드백
        if let leftWrist = recognizedPoints[.leftWrist],
           let rightWrist = recognizedPoints[.rightWrist],
           let leftKnee = recognizedPoints[.leftKnee],
           let rightKnee = recognizedPoints[.rightKnee] {
            // 화면 좌표로 변환
            let lwPos = previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: leftWrist.location.x, y: 1 - leftWrist.location.y))
            let rwPos = previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: rightWrist.location.x, y: 1 - rightWrist.location.y))
            let lkPos = previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: leftKnee.location.x, y: 1 - leftKnee.location.y))
            let rkPos = previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: rightKnee.location.x, y: 1 - rightKnee.location.y))
            // 거리 계산
            let leftDist = hypot(lwPos.x - lkPos.x, lwPos.y - lkPos.y)
            let rightDist = hypot(rwPos.x - rkPos.x, rwPos.y - rkPos.y)
            let threshold: CGFloat = 40.0
            if leftDist < threshold && rightDist < threshold {
                DispatchQueue.main.async {
                    if self.previousFeedbackText == nil {
                        self.previousFeedbackText = self.feedbackMessageLabel.text
                    }
                    self.feedbackMessageLabel.text = "팔을 가슴쪽에 모아주세요."
                }
                if self.isSpeechEnabled {
                    self.speak("팔을 가슴쪽에 모아주세요")
                }
                return
            }
            // Restore feedback when hands leave knees
            if let prev = previousFeedbackText {
                self.speechSynthesizer.stopSpeaking(at: .immediate)
                DispatchQueue.main.async {
                    self.feedbackMessageLabel.text = prev
                }
                previousFeedbackText = nil
            }
        }
        // Knee-inward feedback: trigger if knees are within 30 points on x-axis
        if let leftKnee = recognizedPoints[.leftKnee],
           let rightKnee = recognizedPoints[.rightKnee] {

            let lkPos = previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: leftKnee.location.x, y: 1 - leftKnee.location.y))
            let rkPos = previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: rightKnee.location.x, y: 1 - rightKnee.location.y))
            let kneeDistanceX = abs(lkPos.x - rkPos.x)

            if kneeDistanceX < 40 {
                if !self.hasShownKneeInwardFeedback {
                    self.hasShownKneeInwardFeedback = true
                    DispatchQueue.main.async {
                        self.feedbackMessageLabel.text = "무릎을 바깥쪽으로 열어주세요"
                    }
                    if self.isSpeechEnabled && !self.speechSynthesizer.isSpeaking {
                        self.speak("무릎을 바깥쪽으로 벌리세요")
                    }
                }
            } else {
                if self.hasShownKneeInwardFeedback {
                    self.hasShownKneeInwardFeedback = false
                    DispatchQueue.main.async {
                        if let prev = self.previousFeedbackText {
                            self.feedbackMessageLabel.text = prev
                        } else {
                            self.feedbackMessageLabel.text = "운동을 시작하세요!"
                        }
                    }
                }
            }
        }
        // Continue with squat repetition logic
        if let leftKnee = recognizedPoints[.leftKnee],
           let rightKnee = recognizedPoints[.rightKnee],
           let leftHip = recognizedPoints[.leftHip],
           let rightHip = recognizedPoints[.rightHip] {

            let leftKneeAngle = calculateAngle(point1: leftHip, point2: leftKnee)
            let rightKneeAngle = calculateAngle(point1: rightHip, point2: rightKnee)

            if leftKneeAngle < 120 || rightKneeAngle < 120 {
                hasStartedExercise = true
            }

            if hasStartedExercise {
                if leftKneeAngle < 90 && rightKneeAngle < 90 {
                    if !isPositionCorrect {
                        isPositionCorrect = true
                        holdStartTime = Date()
                    }
                } else {
                    if isPositionCorrect {
                        let holdDuration = Date().timeIntervalSince(holdStartTime ?? Date())
                        if holdDuration >= 1.0 {
                            if vibrationEnabled {
                                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                            }
                            countRepetition()
                        }
                        isPositionCorrect = false
                    }
                }
            }
        }
    }
    
    // MARK: - Push-Up 분석 및 카운트 로직 (개선된 피드백 포함)
    func analyzePushUp(results: VNHumanBodyPoseObservation) {
        guard let recognizedPoints = try? results.recognizedPoints(.all) else { return }

        guard let leftElbow = recognizedPoints[.leftElbow],
              let rightElbow = recognizedPoints[.rightElbow],
              let leftShoulder = recognizedPoints[.leftShoulder],
              let rightShoulder = recognizedPoints[.rightShoulder],
              let leftWrist = recognizedPoints[.leftWrist],
              let rightWrist = recognizedPoints[.rightWrist],
              let nose = recognizedPoints[.nose] else {
            return
        }

        // 좌표 변환
        let leftElbowY = previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: leftElbow.location.x, y: 1 - leftElbow.location.y)).y
        let rightElbowY = previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: rightElbow.location.x, y: 1 - rightElbow.location.y)).y
        let noseY = previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: nose.location.x, y: 1 - nose.location.y)).y

        let leftElbowAngle = computeElbowAngle(shoulder: leftShoulder, elbow: leftElbow, wrist: leftWrist)
        let rightElbowAngle = computeElbowAngle(shoulder: rightShoulder, elbow: rightElbow, wrist: rightWrist)
        let isFullyExtended = leftElbowAngle > 160 && rightElbowAngle > 160

        // 개선된 피드백 로직
        // --- BEGIN REFACTORED FEEDBACK LOGIC ---
        let elbowYThreshold = max(leftElbowY, rightElbowY)
        // 피드백 발생 시 약간의 떨림을 허용하기 위한 오차 값 (픽셀 단위)
        let feedbackTolerance: CGFloat = 15.0
        let isCountingPosition = noseY > (elbowYThreshold + feedbackTolerance)

        // 현재 시간 저장 (피드백 쿨다운용)
        let currentTime = Date().timeIntervalSince1970

        // 조건 미달 하강 체크: 코가 팔꿈치보다 충분히 아래로 가지 않고 내려갔다가 다시 올라온 경우
        if !isCountingPosition && isFullyExtended && wasInShallowZone {
            if currentTime - lastFeedbackTime > 2.0 {
                feedbackMessageLabel.text = "조금 더 내려가셔야 합니다"
                feedbackMessageLabel.isHidden = false
                speakFeedback("조금 더 내려가셔야 합니다")
                lastFeedbackTime = currentTime
            }
            wasInShallowZone = false
        }

        // 하강 중 조건 미달 지점에 도달한 적 있는지 플래그 설정
        if !isCountingPosition && !isFullyExtended {
            wasInShallowZone = true
        }

        // 카운팅 조건이 충족되었을 때는 피드백 방지 및 플래그 초기화
        if isCountingPosition {
            wasInShallowZone = false
            if !isPositionCorrect {
                isPositionCorrect = true
                if vibrationEnabled {
                    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                }
                countRepetition()
                // Clear feedback when repetition is counted
                feedbackMessageLabel.text = ""
                feedbackMessageLabel.isHidden = true
                // 카운트 직후 피드백 쿨다운 타임스탬프 갱신
                self.lastFeedbackTime = currentTime
            }
        } else if isFullyExtended {
            isPositionCorrect = false
        }
        // --- END REFACTORED FEEDBACK LOGIC ---
    }
    // MARK: - Push-Up 미달 피드백 음성 출력
    func speakFeedback(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ko-KR")
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
    }
    
    func analyzePullUp(results: VNHumanBodyPoseObservation) {
        guard let recognizedPoints = try? results.recognizedPoints(.all) else { return }
        guard let leftShoulder = recognizedPoints[.leftShoulder],
              let rightShoulder = recognizedPoints[.rightShoulder],
              let leftWrist = recognizedPoints[.leftWrist],
              let rightWrist = recognizedPoints[.rightWrist] else {
            DispatchQueue.main.async {
                self.feedbackMessageLabel.text = "위치를 재조정 해주세요!"
            }
            return
        }
                
        if leftShoulder.confidence < 0.3 || rightShoulder.confidence < 0.3 ||
           leftWrist.confidence < 0.3 || rightWrist.confidence < 0.3 {
            DispatchQueue.main.async {
                self.feedbackMessageLabel.text = "위치를 재조정 해주세요!"
            }
            return
        }
        
        let leftShoulderPos = previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: leftShoulder.location.x, y: 1 - leftShoulder.location.y))
        let rightShoulderPos = previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: rightShoulder.location.x, y: 1 - rightShoulder.location.y))
        let leftWristPos = previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: leftWrist.location.x, y: 1 - leftWrist.location.y))
        let rightWristPos = previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: rightWrist.location.x, y: 1 - rightWrist.location.y))
        
        let shoulderY = (leftShoulderPos.y + rightShoulderPos.y) / 2
        let wristY = (leftWristPos.y + rightWristPos.y) / 2
        let isInPullUpPosition = wristY < shoulderY - 40
        
        if !isBarGrabbed {
            if isInPullUpPosition {
                if barGrabStartTime == nil {
                    barGrabStartTime = Date()
                }
                let duration = Date().timeIntervalSince(barGrabStartTime!)
                if duration >= 0.7 {
                    isBarGrabbed = true
                    barGrabStartTime = nil
                    DispatchQueue.main.async {
                        self.feedbackMessageLabel.text = "턱걸이를 시작하세요!"
                    }
                } else {
                    DispatchQueue.main.async {
                        self.feedbackMessageLabel.text = "봉을 잡으세요!"
                    }
                }
            } else {
                barGrabStartTime = nil
                DispatchQueue.main.async {
                    self.feedbackMessageLabel.text = "봉을 잡으세요!"
                }
            }
            return
        }
        
        if isBarGrabbed && !isInPullUpPosition {
            if barReleaseStartTime == nil {
                barReleaseStartTime = Date()
            }
            let releaseDuration = Date().timeIntervalSince(barReleaseStartTime!)
            if releaseDuration >= 1.5 {
                isBarGrabbed = false
                barReleaseStartTime = nil
                DispatchQueue.main.async {
                    self.feedbackMessageLabel.text = "봉을 잡으세요!"
                }
                return
            }
        } else {
            barReleaseStartTime = nil
        }
        
        let currentAverageWristY = wristY
        let now = Date()
        if let lastWrist = self.lastWristY, let lastUpdate = self.lastWristUpdateTime, !isInPullUpPosition, isPositionCorrect {
            let dt = now.timeIntervalSince(lastUpdate)
            let dropSpeed = (currentAverageWristY - lastWrist) / CGFloat(dt)
            if dropSpeed > 30.0 {
                isPositionCorrect = false
                return
            }
        }
        self.lastWristY = currentAverageWristY
        self.lastWristUpdateTime = now
        
        DispatchQueue.main.async {
            self.feedbackMessageLabel.text = "턱걸이를 시작하세요!"
        }
        if isInPullUpPosition {
            if !isPositionCorrect {
                isPositionCorrect = true
                holdStartTime = Date()
            }
        } else {
            if isPositionCorrect {
                let holdDuration = Date().timeIntervalSince(holdStartTime ?? Date())
                if holdDuration >= 0 {
                    if vibrationEnabled {
                        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                    }
                    countRepetition()
                }
                isPositionCorrect = false
            }
        }
    }
    
    // MARK: - 팔꿈치 각도 계산 (코사인 법칙 사용)
    func computeElbowAngle(shoulder: VNRecognizedPoint, elbow: VNRecognizedPoint, wrist: VNRecognizedPoint) -> CGFloat {
        let shoulderPos = CGPoint(x: shoulder.location.x, y: shoulder.location.y)
        let elbowPos = CGPoint(x: elbow.location.x, y: elbow.location.y)
        let wristPos = CGPoint(x: wrist.location.x, y: wrist.location.y)
        let a = hypot(shoulderPos.x - elbowPos.x, shoulderPos.y - elbowPos.y)
        let b = hypot(wristPos.x - elbowPos.x, wristPos.y - elbowPos.y)
        let c = hypot(shoulderPos.x - wristPos.x, shoulderPos.y - wristPos.y)
        if a == 0 || b == 0 { return 0 }
        let cosineAngle = max(min((a*a + b*b - c*c) / (2 * a * b), 1), -1)
        let angle = acos(cosineAngle)
        return angle * 180 / .pi
    }
    
    // MARK: - Overlay Drawing
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try requestHandler.perform([bodyPoseRequest])
            if let results = bodyPoseRequest.results?.first {
                DispatchQueue.main.async {
                    self.drawOverlay(for: results)
                    switch self.selectedMode {
                    case .squat:
                        if !self.squatReady {
                            // Perform full-body joint confidence + in-view check
                            if let recognizedPoints = try? results.recognizedPoints(.all) {
                                let requiredJoints: [VNHumanBodyPoseObservation.JointName] = [
                                    .leftShoulder, .rightShoulder,
                                    .leftElbow, .rightElbow,
                                    .leftWrist, .rightWrist,
                                    .leftHip, .rightHip,
                                    .leftKnee, .rightKnee,
                                    .leftAnkle, .rightAnkle
                                ]
                                let threshold: Float = 0.3
                                let isFullBodyDetected = requiredJoints.allSatisfy { joint in
                                    guard let point = recognizedPoints[joint], point.confidence > threshold else {
                                        return false
                                    }
                                    let devicePoint = CGPoint(x: point.location.x, y: 1 - point.location.y)
                                    let viewPoint = self.previewLayer.layerPointConverted(fromCaptureDevicePoint: devicePoint)
                                    return self.cameraView.bounds.contains(viewPoint)
                                }
                                if isFullBodyDetected {
                                    // Start or continue timing detection
                                    if self.squatDetectionStartTime == nil {
                                        self.squatDetectionStartTime = Date()
                                    } else if Date().timeIntervalSince(self.squatDetectionStartTime!) >= 1.0 {
                                        self.squatReady = true
                                        self.squatDetectionStartTime = nil
                                        if self.isSpeechEnabled {
                                            self.speak("운동 시작")
                                        }
                                        self.startCountdown()
                                    }
                                } else {
                                    // Reset timing if detection lost or low confidence
                                    self.squatDetectionStartTime = nil
                                }
                            } else {
                                self.squatDetectionStartTime = nil
                            }
                            break
                        }
                        self.analyzeSquat(results: results)
                    case .pushUp:
                        // Insert comprehensive readiness check before analyzePushUp
                        if !self.hasStartedExercise {
                            if let recognizedPoints = try? results.recognizedPoints(.all),
                               let leftShoulder = recognizedPoints[.leftShoulder],
                               let rightShoulder = recognizedPoints[.rightShoulder],
                               let nose = recognizedPoints[.nose],
                               let leftEye = recognizedPoints[.leftEye],
                               let rightEye = recognizedPoints[.rightEye],
                               leftShoulder.confidence > 0.3, rightShoulder.confidence > 0.3,
                               nose.confidence > 0.3, leftEye.confidence > 0.3, rightEye.confidence > 0.3 {
                                
                                let leftShoulderPos = self.previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: leftShoulder.location.x, y: 1 - leftShoulder.location.y))
                                let rightShoulderPos = self.previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: rightShoulder.location.x, y: 1 - rightShoulder.location.y))
                                let nosePos = self.previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: nose.location.x, y: 1 - nose.location.y))
                                let leftEyePos = self.previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: leftEye.location.x, y: 1 - leftEye.location.y))
                                let rightEyePos = self.previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: rightEye.location.x, y: 1 - rightEye.location.y))

                                if self.cameraView.bounds.contains(leftShoulderPos)
                                    && self.cameraView.bounds.contains(rightShoulderPos)
                                    && self.cameraView.bounds.contains(nosePos)
                                    && self.cameraView.bounds.contains(leftEyePos)
                                    && self.cameraView.bounds.contains(rightEyePos) {
                                    if self.squatDetectionStartTime == nil {
                                        self.squatDetectionStartTime = Date()
                                    } else if Date().timeIntervalSince(self.squatDetectionStartTime!) >= 1.0 {
                                        self.hasStartedExercise = true
                                        self.squatDetectionStartTime = nil
                                        if self.isSpeechEnabled {
                                            self.speak("운동 시작")
                                        }
                                        self.startCountdown()
                                    }
                                    return
                                }
                            }
                            self.squatDetectionStartTime = nil
                            DispatchQueue.main.async {
                                self.feedbackMessageLabel.text = "카메라를 주시한 상태로 엎드리세요"
                            }
                            return
                        }
                        self.analyzePushUp(results: results)
                    case .pullUp:
                        if !self.pullUpReady {
                            if let recognizedPoints = try? results.recognizedPoints(.all),
                               let leftShoulder = recognizedPoints[.leftShoulder],
                               let rightShoulder = recognizedPoints[.rightShoulder],
                               let leftWrist = recognizedPoints[.leftWrist],
                               let rightWrist = recognizedPoints[.rightWrist] {
                                // Convert to view coordinates
                                let leftShoulderPos = self.previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: leftShoulder.location.x, y: 1 - leftShoulder.location.y))
                                let rightShoulderPos = self.previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: rightShoulder.location.x, y: 1 - rightShoulder.location.y))
                                let shoulderY = (leftShoulderPos.y + rightShoulderPos.y) / 2
                                let leftWristPos = self.previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: leftWrist.location.x, y: 1 - leftWrist.location.y))
                                let rightWristPos = self.previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: rightWrist.location.x, y: 1 - rightWrist.location.y))
                                let wristY = (leftWristPos.y + rightWristPos.y) / 2
                                if wristY < shoulderY - 40 {
                                    if self.barGrabStartTime == nil {
                                        self.barGrabStartTime = Date()
                                    }
                                    let duration = Date().timeIntervalSince(self.barGrabStartTime!)
                                    if duration >= 0.7 {
                                        self.pullUpReady = true
                                        if self.isSpeechEnabled {
                                            self.speak("운동 시작")
                                        }
                                        self.startCountdown()
                                    }
                                } else {
                                    self.barGrabStartTime = nil
                                }
                            }
                            break
                        }
                        self.analyzePullUp(results: results)
                    
                        break
                    }
                }
            }
        } catch {
            // 오류 처리 (필요 시 추가)
        }
    }
    
    func drawOverlay(for observation: VNHumanBodyPoseObservation) {
        guard let recognizedPoints = try? observation.recognizedPoints(.all) else { return }
        let path = UIBezierPath()
        overlayLayer.path = nil
        
        func drawJoint(at point: VNRecognizedPoint) {
            let position = previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: point.location.x, y: 1 - point.location.y))
            if cameraView.bounds.contains(position) {
                path.move(to: position)
                path.addArc(withCenter: position, radius: 5, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: true)
            }
        }
        
        func connect(_ p1: VNRecognizedPoint, _ p2: VNRecognizedPoint) {
            let point1 = previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: p1.location.x, y: 1 - p1.location.y))
            let point2 = previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: p2.location.x, y: 1 - p2.location.y))
            if cameraView.bounds.contains(point1) && cameraView.bounds.contains(point2) {
                path.move(to: point1)
                path.addLine(to: point2)
            }
        }
        
        if let leftShoulder = recognizedPoints[.leftShoulder],
           let rightShoulder = recognizedPoints[.rightShoulder],
           let leftElbow = recognizedPoints[.leftElbow],
           let rightElbow = recognizedPoints[.rightElbow],
           let leftWrist = recognizedPoints[.leftWrist],
           let rightWrist = recognizedPoints[.rightWrist],
           let leftHip = recognizedPoints[.leftHip],
           let rightHip = recognizedPoints[.rightHip],
           let leftKnee = recognizedPoints[.leftKnee],
           let rightKnee = recognizedPoints[.rightKnee],
           let leftAnkle = recognizedPoints[.leftAnkle],
           let rightAnkle = recognizedPoints[.rightAnkle] {
            
            drawJoint(at: leftShoulder)
            drawJoint(at: rightShoulder)
            connect(leftShoulder, rightShoulder)
            connect(leftShoulder, leftElbow)
            connect(rightShoulder, rightElbow)
            connect(leftElbow, leftWrist)
            connect(rightElbow, rightWrist)
            
            drawJoint(at: leftHip)
            drawJoint(at: rightHip)
            connect(leftShoulder, leftHip)
            connect(rightShoulder, rightHip)
            connect(leftHip, rightHip)
            connect(leftHip, leftKnee)
            connect(rightHip, rightKnee)
            connect(leftKnee, leftAnkle)
            connect(rightKnee, rightAnkle)
        }
        
        overlayLayer.path = path.cgPath
    }
    
    // MARK: - Angle Calculation
    func calculateAngle(point1: VNRecognizedPoint, point2: VNRecognizedPoint) -> CGFloat {
        let dx = point2.location.x - point1.location.x
        let dy = point2.location.y - point1.location.y
        return atan2(dy, dx) * 180 / .pi
    }
    
    // MARK: - Real-Time 칼로리 계산
    func startCalorieTimer() {
        calorieTimer?.cancel()
        calorieTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        calorieTimer?.schedule(deadline: .now(), repeating: 1.0)
        calorieTimer?.setEventHandler { [weak self] in
            self?.updateCalories()
        }
        calorieTimer?.resume()
    }
    
    func stopCalorieTimer() {
        calorieTimer?.cancel()
        calorieTimer = nil
    }
    
    @objc func updateCalories() {
        if isPositionCorrect {
            if let lastTime = lastActiveTime {
                let elapsed = Date().timeIntervalSince(lastTime)
                activeExerciseTime += elapsed
                lastActiveTime = Date()
                caloriesBurned = calculateCaloriesBurned(exerciseMode: selectedMode, activeExerciseTime: activeExerciseTime)
                caloriesValueLabel.text = String(format: "%.2f kcal", caloriesBurned)
            } else {
                lastActiveTime = Date()
            }
        }
    }
    
    // MARK: - 메인 타이머 시작
    func startMainTimer() {
        mainTimer?.invalidate()
        if exerciseStartTime == nil {
            exerciseStartTime = Date()
        }
        mainTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self, let startTime = self.exerciseStartTime else {
                timer.invalidate()
                return
            }
            let elapsed = Date().timeIntervalSince(startTime)
            let minutes = Int(elapsed) / 60
            let seconds = Int(elapsed) % 60
            self.timerLabel.text = String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    // MARK: - 에러 메시지 표시
    func displayError(message: String) {
        feedbackMessageLabel.text = message
        feedbackMessageLabel.backgroundColor = UIColor.red.withAlphaComponent(0.6)
    }
    
    // MARK: - 사용자가 미리보기에서 저장 선택 시, Photo Library에서 복사하여 Documents/Videos에 저장
    func saveVideoToDocuments() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1
        let fetchResult = PHAsset.fetchAssets(with: .video, options: fetchOptions)
        guard let asset = fetchResult.firstObject else { return }
        let options = PHVideoRequestOptions()
        options.deliveryMode = .highQualityFormat
        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { (avAsset, audioMix, info) in
            guard let avAsset = avAsset else { return }
            guard let exportSession = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetHighestQuality) else { return }
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let videosDirectory = documentsDirectory.appendingPathComponent("Videos", isDirectory: true)
            if !FileManager.default.fileExists(atPath: videosDirectory.path) {
                try? FileManager.default.createDirectory(at: videosDirectory, withIntermediateDirectories: true, attributes: nil)
            }
            // 수정된 부분: 운동 모드에 따라 파일명 생성 (예: "푸쉬업_타임스탬프.mp4")
            let exerciseType: String
            switch self.selectedMode {
            case .squat:
                exerciseType = "스쿼트"
            case .pushUp:
                exerciseType = "푸쉬업"
            case .pullUp:
                exerciseType = "턱걸이"
            
            }
            let outputURL = videosDirectory.appendingPathComponent("\(exerciseType)_\(Date().timeIntervalSince1970).mp4")
            exportSession.outputURL = outputURL
            exportSession.outputFileType = .mp4
            // Modern async/await export
            if #available(iOS 15.0, *) {
                Task {
                    await exportSession.export()
                    DispatchQueue.main.async {
                        print("Video saved to Documents/Videos: \(outputURL)")
                        NotificationCenter.default.post(name: NSNotification.Name("VideoExportCompleted"), object: nil)
                    }
                }
            } else {
                exportSession.exportAsynchronously {
                    if exportSession.status == .completed {
                        DispatchQueue.main.async {
                            print("Video saved to Documents/Videos: \(outputURL)")
                            NotificationCenter.default.post(name: NSNotification.Name("VideoExportCompleted"), object: nil)
                        }
                    } else if let error = exportSession.error {
                        print("Export error: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

// MARK: - RPPreviewViewControllerDelegate 확장
extension ExerciseViewController: RPPreviewViewControllerDelegate {
    func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
        previewController.dismiss(animated: true, completion: nil)
        self.recordedPreviewController = nil
    }
    
    // 사용자가 미리보기에서 '저장' 버튼을 누르면 호출 (activityTypes를 문자열 리터럴로 체크)
    func previewController(_ previewController: RPPreviewViewController, didFinishWithActivityTypes activityTypes: Set<String>) {
        let addToPhotosType = UIActivity.ActivityType(rawValue: "com.apple.UIKit.activity.addToPhotos")
        if #available(iOS 15.0, *) {
            if activityTypes.contains(UIActivity.ActivityType.saveToCameraRoll.rawValue) ||
               activityTypes.contains(addToPhotosType.rawValue) {
                self.saveVideoToDocuments()
            }
        } else {
            if activityTypes.contains(UIActivity.ActivityType.saveToCameraRoll.rawValue) {
                self.saveVideoToDocuments()
            }
        }
        previewController.dismiss(animated: true, completion: nil)
        self.recordedPreviewController = nil
    }
}

// MARK: - AVSpeechSynthesizerDelegate 확장
extension ExerciseViewController: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        self.isStanceFeedbackPlaying = false
    }
}

// MARK: - Push-Up shallow zone flag
extension ExerciseViewController {
    // 푸쉬업 미달 하강 플래그
    var wasInShallowZone: Bool {
        get {
            return objc_getAssociatedObject(self, &wasInShallowZoneKey) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(self, &wasInShallowZoneKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

private var wasInShallowZoneKey: UInt8 = 0
