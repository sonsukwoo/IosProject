import UIKit
import Vision
import AVFoundation
import AudioToolbox
import ReplayKit  // 화면 녹화를 위한 ReplayKit 임포트

// MARK: - ExerciseViewController 클래스 정의 및 프로토콜 구현
class ExerciseViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    // MARK: - 열거형 정의
    enum ExerciseMode {
        case squat
        case pushUp
        case pullUp
        case none
    }
    
    // MARK: - 기본 프로퍼티 정의
    var selectedMode: ExerciseMode = .none
    var captureSession = AVCaptureSession()
    var currentCameraPosition: AVCaptureDevice.Position = .back
    var bodyPoseRequest = VNDetectHumanBodyPoseRequest()
    var previewLayer: AVCaptureVideoPreviewLayer!
    var overlayLayer = CAShapeLayer()
    var lastRepetitionTime: Date?
    
    // 운동 상태 관련 프로퍼티
    var isPositionCorrect = false
    var repetitions = 0
    var targetRepetitions: Int = 10 // 초기값, ViewController에서 설정
    var targetSets: Int = 3         // 초기값, ViewController에서 설정
    var restTime: Int = 30          // 초기값, ViewController에서 설정
    var squatDepthThreshold: CGFloat = 80
    var holdStartTime: Date?
    var currentSet = 1
    var sessionStartTime: Date?
    var hasStartedExercise = false
    var setSummaries: [String] = []
    var setStartTime: Date?
    var restTimer: Timer?
    var remainingRestTime: Int = 0
    var exerciseCompleted = false
    var caloriesBurned: Double = 0.0
    var exerciseStartTime: Date?  // 운동 시작 시간
    
    var calorieTimer: DispatchSourceTimer?
    
    // Main Timer for 운동 시간 표시
    var mainTimer: Timer?
    
    // 카운트다운 타이머
    var countdownTimer: Timer?
    
    // 추가된 활동 시간 추적 변수
    var activeExerciseTime: TimeInterval = 0.0
    var lastActiveTime: Date?
    
    // 평균 속도 추적 변수
    var totalRepetitionTime: TimeInterval = 0.0
    var repetitionCountForAverage: Int = 0
    
    // MARK: - 음성 합성기
    let speechSynthesizer = AVSpeechSynthesizer()
    var isSpeechEnabled: Bool = true
    
    // 진동 기능 사용 여부 (UserDefaults)
    var vibrationEnabled: Bool {
        return UserDefaults.standard.bool(forKey: "isVibrationEnabled")
    }
    
    // 턱걸이 관련 상태 변수 – 기존 카운트 기준 방식을 고수합니다.
    var isBarGrabbed: Bool = false
    var barGrabStartTime: Date?
    // 봉 놓음(손목이 어깨 미만으로 내려간 상태) 유지 시간 체크
    var barReleaseStartTime: Date?
    
    var lastWristY: CGFloat?
    var lastWristUpdateTime: Date?
    
    // MARK: - 녹화 미리보기 저장용 프로퍼티 추가
    var recordedPreviewController: RPPreviewViewController?
    
    // MARK: - UI Elements (프로그램 방식으로 정의)
    
    // 카메라 회전 버튼 (좌측 상단)
    let switchCameraButton: UIButton = {
        let button = UIButton(type: .system)
        let image = UIImage(systemName: "camera.rotate")
        button.setImage(image, for: .normal)
        button.tintColor = .white
        button.layer.cornerRadius = 20
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // 소리 버튼 (우측 상단)
    let soundToggleButton: UIButton = {
        let button = UIButton(type: .system)
        let image = UIImage(systemName: "speaker.wave.2.fill")
        button.setImage(image, for: .normal)
        button.tintColor = .white
        button.layer.cornerRadius = 20
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // === 녹화 토글 버튼 추가 (우측 상단) ===
    let recordToggleButton: UIButton = {
        let button = UIButton(type: .system)
        let image = UIImage(systemName: "record.circle")  // 녹화 전 상태 아이콘
        button.setImage(image, for: .normal)
        button.tintColor = .white
        button.layer.cornerRadius = 20
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // 타이머 레이블 (중앙 상단)
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
    
    // 피드백 메시지 레이블 (타이머 아래)
    let feedbackMessageLabel: UILabel = {
        let label = UILabel()
        label.text = "운동을 시작하세요!"
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = UIColor.clear
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 카운트다운 프로그레스 바
    let countdownProgressLayer = CAShapeLayer()
    
    // 카운트다운 레이블 (카메라 뷰 중앙)
    let countdownLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.font = UIFont.boldSystemFont(ofSize: 80)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = UIColor.clear
        label.layer.cornerRadius = 100
        label.layer.masksToBounds = true
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
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
    let repetitionsTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "반복 횟수"
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = .gray
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 세트 수 제목 레이블
    let setsTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "세트 수"
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = .gray
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 평균 속도 제목 레이블
    let averageSpeedTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "평균 속도"
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = .gray
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 칼로리 제목 레이블
    let caloriesTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "칼로리"
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = .gray
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 반복 횟수 값 레이블
    let repetitionsValueLabel: UILabel = {
        let label = UILabel()
        label.text = "0 / 10"
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 세트 수 값 레이블
    let setsValueLabel: UILabel = {
        let label = UILabel()
        label.text = "1 / 3"
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 평균 속도 값 레이블
    let averageSpeedValueLabel: UILabel = {
        let label = UILabel()
        label.text = "0.0초"
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 칼로리 값 레이블
    let caloriesValueLabel: UILabel = {
        let label = UILabel()
        label.text = "0.00 kcal"
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
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
    
    // MARK: - (추가) CustomSummaryViewController 서브클래스
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
        
        // UserDefaults에서 음성 사용 여부 불러오기 (저장된 값이 없으면 기본 true)
        if let savedSpeechEnabled = UserDefaults.standard.value(forKey: "isSpeechEnabled") as? Bool {
            isSpeechEnabled = savedSpeechEnabled
        } else {
            isSpeechEnabled = true
        }
        
        setupUI()
        setupCamera()
        setupCountdownProgress()
        setupSoundToggle()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 운동 중에는 화면 꺼짐 방지
        UIApplication.shared.isIdleTimerDisabled = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        
        if let savedTargetRepetitions = UserDefaults.standard.value(forKey: "targetRepetitions") as? Int, savedTargetRepetitions > 0 {
            targetRepetitions = savedTargetRepetitions
        }
        
        if let savedTargetSets = UserDefaults.standard.value(forKey: "targetSets") as? Int, savedTargetSets > 0 {
            targetSets = savedTargetSets
        }
        
        if let savedRestTime = UserDefaults.standard.value(forKey: "restTime") as? Int, savedRestTime > 0 {
            restTime = savedRestTime
        }
        
        if selectedMode != .none {
            startExercise()
        } else {
            feedbackMessageLabel.text = "운동 모드를 선택하세요."
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = cameraView.bounds
        overlayLayer.frame = cameraView.bounds
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 화면 꺼짐 설정 원래대로 복원
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
        
        // === 녹화 버튼 UI 배치 ===
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
    
    // MARK: - 녹화 토글 메서드 (ReplayKit)
    @objc func toggleRecording() {
        let recorder = RPScreenRecorder.shared()
        
        if !recorder.isRecording {
            recorder.startRecording(withMicrophoneEnabled: true) { error in
                if let _ = error {
                    // 에러 출력 제거
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
                    // 에러 출력 제거
                }
                DispatchQueue.main.async {
                    let image = UIImage(systemName: "record.circle")
                    self.recordToggleButton.setImage(image, for: .normal)
                }
                if let previewController = previewController {
                    previewController.previewControllerDelegate = self
                    // 미리보기를 즉시 표시하지 않고 저장
                    self.recordedPreviewController = previewController
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
                DispatchQueue.main.async {
                    completion(granted)
                }
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
    
    // MARK: - 운동 모드 설정 메서드
    func setupExerciseMode() {
        if !exerciseCompleted {
            switch selectedMode {
            case .squat:
                feedbackMessageLabel.text = "스쿼트 모드로 시작하세요!"
            case .pushUp:
                feedbackMessageLabel.text = "푸쉬업 모드로 시작하세요!"
            case .pullUp:
                feedbackMessageLabel.text = "봉을 잡으세요!"  // pull-up 모드의 경우 카운트다운 후 처리됨
            case .none:
                feedbackMessageLabel.text = "운동 모드를 선택하세요."
            }
        }
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
        guard selectedMode != .none else {
            feedbackMessageLabel.text = "운동 모드를 선택하세요."
            return
        }
        
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
        
        // pull-up 모드일 경우 관련 상태 초기화
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
        
        startCountdown()
    }
    
    // MARK: - 카운트다운 구현
    func startCountdown() {
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
                self.captureSession.startRunning()
                self.setupExerciseMode()
                if self.selectedMode == .pullUp {
                    self.feedbackMessageLabel.text = "봉을 잡으세요!"
                } else {
                    self.feedbackMessageLabel.text = "운동을 시작하세요!"
                }
                self.startCalorieTimer()
                self.startMainTimer()
            }
        }
    }
    
    // MARK: - 운동 데이터 저장
    func saveExerciseSummary() {
        let endTime = Date()
        let exerciseName: String
        switch selectedMode {
        case .squat: exerciseName = "스쿼트"
        case .pushUp: exerciseName = "푸쉬업"
        case .pullUp: exerciseName = "턱걸이"
        case .none: exerciseName = "선택되지 않음"
        }
        
        let summary: [String: Any] = [
            "date": endTime,
            "exerciseType": exerciseName,
            "sets": currentSet,
            "reps": repetitions,
            "calories": caloriesBurned,
            "duration": endTime.timeIntervalSince(exerciseStartTime ?? endTime),
            "averageSpeed": repetitionCountForAverage > 0 ? totalRepetitionTime / Double(repetitionCountForAverage) : 0.0,
            "restTime": restTime
        ]
        
        var exerciseData = UserDefaults.standard.array(forKey: "exerciseSummaries") as? [[String: Any]] ?? []
        exerciseData.append(summary)
        UserDefaults.standard.setValue(exerciseData, forKey: "exerciseSummaries")
    }
    
    // MARK: - 운동 정지 액션
    @objc func stopExercise() {
        captureSession.stopRunning()
        stopCalorieTimer()
        mainTimer?.invalidate()
        mainTimer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        cameraView.isHidden = true
        feedbackMessageLabel.text = "운동 종료"
        
        // 운동 종료 시 화면 자동 잠금 복원
        UIApplication.shared.isIdleTimerDisabled = false
        
        let recorder = RPScreenRecorder.shared()
        if recorder.isRecording {
            recorder.stopRecording { previewController, error in
                if let _ = error {
                    // 오류 로그 제거됨
                }
                DispatchQueue.main.async {
                    let image = UIImage(systemName: "record.circle")
                    self.recordToggleButton.setImage(image, for: .normal)
                }
                if let previewController = previewController {
                    previewController.previewControllerDelegate = self
                    // 미리보기를 즉시 표시하지 않고 저장
                    self.recordedPreviewController = previewController
                }
                // 운동 기록 모달을 표시
                self.displaySessionSummary()
                self.saveExerciseSummary()
            }
        } else {
            self.displaySessionSummary()
            self.saveExerciseSummary()
        }
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
    
    // MARK: - 운동 기록 표시 메서드 (수정된 버전)
    func displaySessionSummary() {
        let exerciseEndTime = Date()
        let totalDuration = exerciseStartTime != nil ? exerciseEndTime.timeIntervalSince(exerciseStartTime!) : 0.0
        let averageSpeed: Double = repetitionCountForAverage > 0 ? totalRepetitionTime / Double(repetitionCountForAverage) : 0.0
        
        let record: [String: Any] = [
            "date": exerciseEndTime,
            "exerciseType": {
                switch selectedMode {
                case .squat:
                    return "스쿼트"
                case .pushUp:
                    return "푸쉬업"
                case .pullUp:
                    return "턱걸이"
                default:
                    return "선택되지 않음"
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
    
    // MARK: - 모달 닫기 및 홈화면으로 전환 메서드
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
    
    // MARK: - 피드백 메시지 레이블 업데이트 메서드
    func updateFeedbackMessage(text: String) {
        feedbackMessageLabel.text = text
    }
    
    // MARK: - BMR 계산 메서드 (Harris-Benedict Equation)
    func calculateBMR(gender: Int, age: Int, height: Double, weight: Double) -> Double {
        if gender == 0 {
            return 88.362 + (13.397 * weight) + (4.799 * height) - (5.677 * Double(age))
        } else {
            return 447.593 + (9.247 * weight) + (3.098 * height) - (4.330 * Double(age))
        }
    }
    
    // MARK: - 칼로리 계산 메서드 (BMR 및 MET 기반)
    func calculateCaloriesBurned(exerciseMode: ExerciseMode, activeExerciseTime: TimeInterval) -> Double {
        let weight = UserDefaults.standard.double(forKey: "weight")
        let height = UserDefaults.standard.double(forKey: "height")
        let age = UserDefaults.standard.integer(forKey: "age")
        let genderIndex = UserDefaults.standard.integer(forKey: "gender")
        
        guard weight > 0, height > 0, age > 0, (genderIndex == 0 || genderIndex == 1) else {
            return 0.0
        }
        
        let bmr = calculateBMR(gender: genderIndex, age: age, height: height, weight: weight)
        let mets: Double
        switch exerciseMode {
        case .squat:
            mets = 5.0
        case .pushUp:
            mets = 3.8
        case .pullUp:
            mets = 8.0
        default:
            mets = 0.0
        }
        
        let activeExerciseTimeMinutes = activeExerciseTime / 60.0
        let caloriesBurned = mets * (bmr / 1440.0) * activeExerciseTimeMinutes
        
        return caloriesBurned
    }
    
    // MARK: - 반복 카운트 메서드 (기존 기준 적용)
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
        
        // 진동 및 효과음 재생
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
        
        // 음성 피드백
        speakNumber(count: repetitions)
    }
    
    // MARK: - 타이머 레이블 애니메이션 메서드
    func animateTimerLabel() {
        UIView.animate(withDuration: 0.2,
                       animations: {
                        self.timerLabel.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                       },
                       completion: { _ in
                        UIView.animate(withDuration: 0.2) {
                            self.timerLabel.transform = CGAffineTransform.identity
                        }
                       })
    }
    
    // MARK: - 숫자 음성 피드백 메서드 (0 ~ 50까지 지원)
    func speakNumber(count: Int) {
        guard isSpeechEnabled else { return }
        
        let numberString = koreanNumber(for: count)
        let utterance = AVSpeechUtterance(string: numberString)
        utterance.voice = AVSpeechSynthesisVoice(language: "ko-KR")
        speechSynthesizer.speak(utterance)
    }
    
    /// 주어진 정수를 한글 숫자 문자열로 변환 (0 ~ 50까지 지원)
    func koreanNumber(for count: Int) -> String {
        if count < 0 { return "" }
        if count == 0 { return "영" }
        
        let tensWords = ["", "열", "스물", "서른", "마흔", "쉰"]
        let onesWords = ["", "하나", "둘", "셋", "넷", "다섯", "여섯", "일곱", "여덟", "아홉"]
        
        let tens = count / 10
        let ones = count % 10
        
        if ones == 0 {
            if tens < tensWords.count {
                return tensWords[tens]
            } else {
                return "\(count)"
            }
        } else {
            if tens < tensWords.count && ones < onesWords.count {
                return tensWords[tens] + onesWords[ones]
            } else {
                return "\(count)"
            }
        }
    }
    
    // MARK: - 라벨 색상 업데이트 메서드
    func updateInfoLabelsColor(isActive: Bool) {
        // 정보 제목은 회색, 정보 값은 흰색 (변경 없음)
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
        averageSpeedValueLabel.text = repetitionCountForAverage > 0 ? String(format: "%.1f초", totalRepetitionTime / Double(repetitionCountForAverage)) : "0.0초"
        setsValueLabel.text = "\(currentSet) / \(targetSets)"
        infoStackView.layoutIfNeeded()
        updateFeedbackMessage(text: "다음 세트 시작!")
        setStartTime = Date()
        
        if currentSet > targetSets {
            stopExercise()
        } else {
            cameraView.isHidden = false
            setupExerciseMode()
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
    
    // MARK: - 운동 측정 메소드
    // 스쿼트
    func analyzeSquat(results: VNHumanBodyPoseObservation) {
        guard let recognizedPoints = try? results.recognizedPoints(.all) else { return }
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
    
    // 푸쉬업
    func analyzePushUp(results: VNHumanBodyPoseObservation) {
        guard let recognizedPoints = try? results.recognizedPoints(.all) else { return }
        if let leftElbow = recognizedPoints[.leftElbow],
           let rightElbow = recognizedPoints[.rightElbow],
           let leftShoulder = recognizedPoints[.leftShoulder],
           let rightShoulder = recognizedPoints[.rightShoulder] {
            
            let leftElbowAngle = calculateAngle(point1: leftShoulder, point2: leftElbow)
            let rightElbowAngle = calculateAngle(point1: rightShoulder, point2: rightElbow)
            
            if leftElbowAngle < 90 && rightElbowAngle < 90 {
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
    
    // 턱걸이 – 조건
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
            let speedThreshold: CGFloat = 30.0
            if dropSpeed > speedThreshold {
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
    
    // MARK: - 팔꿈치 각도 계산 함수 (코사인 법칙 사용)
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
                        self.analyzeSquat(results: results)
                    case .pushUp:
                        self.analyzePushUp(results: results)
                    case .pullUp:
                        self.analyzePullUp(results: results)
                    default:
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
    
    // MARK: - Real-Time Calorie Calculation
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
    
    // MARK: - 메인 타이머 시작 메서드
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
    
    // MARK: - 에러 메시지 표시 메서드
    func displayError(message: String) {
        feedbackMessageLabel.text = message
        feedbackMessageLabel.backgroundColor = UIColor.red.withAlphaComponent(0.6)
    }
}

// MARK: - RPPreviewViewControllerDelegate 확장
extension ExerciseViewController: RPPreviewViewControllerDelegate {
    func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
        previewController.dismiss(animated: true, completion: nil)
        self.recordedPreviewController = nil
    }
}
