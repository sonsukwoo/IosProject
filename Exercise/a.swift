import UIKit
import Vision
import AVFoundation
import AudioToolbox

// MARK: - 클래스 정의 & 프로토콜 구현
class a: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
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
    var targetSets: Int = 3 // 초기값, ViewController에서 설정
    var restTime: Int = 30 // 초기값, ViewController에서 설정
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
    
    // Timer for Real-Time Calories using DispatchSourceTimer
    var calorieTimer: DispatchSourceTimer?
    
    // Main Timer for 운동 시간 표시
    var mainTimer: Timer?
    
    // 카운트다운 타이머
    var countdownTimer: Timer?
    
    // 추가된 활동 시간 추적 변수
    var activeExerciseTime: TimeInterval = 0.0 // 실제 운동 시간 추적
    var lastActiveTime: Date?
    
    // 평균 속도 추적 변수
    var totalRepetitionTime: TimeInterval = 0.0
    var repetitionCountForAverage: Int = 0
    
    // MARK: - 음성 합성기
    let speechSynthesizer = AVSpeechSynthesizer()
    var isSpeechEnabled: Bool = true
    
    // MARK: - UI Elements (프로그램 방식으로 정의)
    
    // 카메라 회전 버튼 (좌측 상단) - 배경색 제거
    let switchCameraButton: UIButton = {
        let button = UIButton(type: .system)
        let image = UIImage(systemName: "camera.rotate")
        button.setImage(image, for: .normal)
        button.tintColor = .white
        // backgroundColor 제거
        // button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.7) // 배경색 제거
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
        // 소리 버튼의 배경색 제거
        // button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.7)
        button.layer.cornerRadius = 20
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // 타이머 레이블 (중앙 상단)
    let timerLabel: UILabel = {
        let label = UILabel()
        label.text = "00:00"
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 20, weight: .medium)
        label.textColor = .white // 텍스트는 흰색
        label.backgroundColor = UIColor.red // 배경색은 빨간색
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
        label.textColor = .white // 텍스트는 흰색
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
        label.layer.cornerRadius = 100 // 원형을 위해
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
        stackView.axis = .vertical // 수직으로 설정
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
        label.textColor = .gray // 회색으로 설정
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 세트 수 제목 레이블
    let setsTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "세트 수"
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = .gray // 회색으로 설정
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 평균 속도 제목 레이블
    let averageSpeedTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "평균 속도"
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = .gray // 회색으로 설정
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 칼로리 제목 레이블
    let caloriesTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "칼로리"
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = .gray // 회색으로 설정
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 반복 횟수 값 레이블
    let repetitionsValueLabel: UILabel = {
        let label = UILabel()
        label.text = "0 / 10" // 초기값, ViewController에서 설정
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textColor = .white // 흰색으로 설정
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 세트 수 값 레이블
    let setsValueLabel: UILabel = {
        let label = UILabel()
        label.text = "1 / 3" // 초기값, ViewController에서 설정
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textColor = .white // 흰색으로 설정
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 평균 속도 값 레이블
    let averageSpeedValueLabel: UILabel = {
        let label = UILabel()
        label.text = "0.0초"
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textColor = .white // 흰색으로 설정
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 칼로리 값 레이블
    let caloriesValueLabel: UILabel = {
        let label = UILabel()
        label.text = "0.00 kcal"
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textColor = .white // 흰색으로 설정
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
    
    // MARK: - 뷰 라이프사이클
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCamera()
        setupCountdownProgress()
        setupSoundToggle()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 앱 라이프사이클 알림 등록
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        
        // UserDefaults에서 설정 불러오기
        if let savedTargetRepetitions = UserDefaults.standard.value(forKey: "targetRepetitions") as? Int, savedTargetRepetitions > 0 {
            targetRepetitions = savedTargetRepetitions
        }
        
        if let savedTargetSets = UserDefaults.standard.value(forKey: "targetSets") as? Int, savedTargetSets > 0 {
            targetSets = savedTargetSets
        }
        
        if let savedRestTime = UserDefaults.standard.value(forKey: "restTime") as? Int, savedRestTime > 0 {
            restTime = savedRestTime
        }
        
        // 운동 시작 자동화: selectedMode가 설정된 후 이 뷰로 전환될 때 startExercise 호출
        if selectedMode != .none {
            startExercise()
        } else {
            feedbackMessageLabel.text = "운동 모드를 선택하세요."
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // previewLayer와 overlayLayer의 프레임을 업데이트하여 레이아웃 완료 후 설정
        previewLayer.frame = cameraView.bounds
        overlayLayer.frame = cameraView.bounds
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 앱 라이프사이클 알림 제거
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
        
        // 카메라 회전 버튼
        view.addSubview(switchCameraButton)
        NSLayoutConstraint.activate([
            switchCameraButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            switchCameraButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            switchCameraButton.widthAnchor.constraint(equalToConstant: 40),
            switchCameraButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        switchCameraButton.addTarget(self, action: #selector(switchCamera), for: .touchUpInside)
        
        // 소리 토글 버튼
        view.addSubview(soundToggleButton)
        NSLayoutConstraint.activate([
            soundToggleButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            soundToggleButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            soundToggleButton.widthAnchor.constraint(equalToConstant: 40),
            soundToggleButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        soundToggleButton.addTarget(self, action: #selector(toggleSound), for: .touchUpInside)
        
        // 타이머 레이블
        view.addSubview(timerLabel)
        NSLayoutConstraint.activate([
            timerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            timerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            timerLabel.widthAnchor.constraint(equalToConstant: 100),
            timerLabel.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // 피드백 메시지 레이블
        view.addSubview(feedbackMessageLabel)
        NSLayoutConstraint.activate([
            feedbackMessageLabel.topAnchor.constraint(equalTo: timerLabel.bottomAnchor, constant: 10),
            feedbackMessageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            feedbackMessageLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            feedbackMessageLabel.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        // 카메라 뷰
        view.addSubview(cameraView)
        NSLayoutConstraint.activate([
            cameraView.topAnchor.constraint(equalTo: feedbackMessageLabel.bottomAnchor, constant: 10),
            cameraView.leadingAnchor.constraint(equalTo: view.leadingAnchor), // 좌우 여백 제거
            cameraView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cameraView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.6)
        ])
        
        // 정보 스택뷰 구성
        // 정보 제목 스택뷰
        infoTitlesStackView.addArrangedSubview(repetitionsTitleLabel)
        infoTitlesStackView.addArrangedSubview(setsTitleLabel)
        infoTitlesStackView.addArrangedSubview(averageSpeedTitleLabel)
        infoTitlesStackView.addArrangedSubview(caloriesTitleLabel)
        
        // 정보 값 스택뷰
        infoValuesStackView.addArrangedSubview(repetitionsValueLabel)
        infoValuesStackView.addArrangedSubview(setsValueLabel)
        infoValuesStackView.addArrangedSubview(averageSpeedValueLabel)
        infoValuesStackView.addArrangedSubview(caloriesValueLabel)
        
        // 정보 전체 스택뷰에 추가
        infoStackView.addArrangedSubview(infoTitlesStackView)
        infoStackView.addArrangedSubview(infoValuesStackView)
        
        view.addSubview(infoStackView)
        NSLayoutConstraint.activate([
            infoStackView.topAnchor.constraint(equalTo: cameraView.bottomAnchor, constant: 10),
            infoStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            infoStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            infoStackView.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        // 하단 버튼들 - 가로로 길게 배치
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
        
        // 카운트다운 레이블
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
        // 초기 아이콘 설정
        updateSoundToggleButton()
    }
    
    @objc func toggleSound() {
        isSpeechEnabled.toggle()
        updateSoundToggleButton()
    }
    
    func updateSoundToggleButton() {
        let imageName = isSpeechEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill"
        let image = UIImage(systemName: imageName)
        soundToggleButton.setImage(image, for: .normal)
    }
    
    // MARK: - 카운트다운 프로그레스 바 설정
    func setupCountdownProgress() {
        let circularPath = UIBezierPath(arcCenter: CGPoint(x: 100, y: 100), radius: 90, startAngle: -CGFloat.pi / 2, endAngle: 1.5 * CGFloat.pi, clockwise: true)
        
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
                self.previewLayer.frame = self.cameraView.bounds // 초기 설정, 실제 프레임은 viewDidLayoutSubviews에서 업데이트
                
                self.cameraView.layer.insertSublayer(self.previewLayer, at: 0)
                
                // 오버레이 레이어 설정
                self.overlayLayer.strokeColor = UIColor.orange.cgColor // 기본 색상: 오렌지색
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
                feedbackMessageLabel.text = "턱걸이 모드로 시작하세요!"
            case .none:
                feedbackMessageLabel.text = "운동 모드를 선택하세요."
            }
        }
    }
    
    // MARK: - 앱 라이프사이클 핸들러
    @objc func appWillResignActive() {
        // 앱이 비활성화될 때 타이머 일시 중지
        stopCalorieTimer()
        mainTimer?.invalidate()
    }
    
    @objc func appDidBecomeActive() {
        // 앱이 활성화될 때 타이머 재개
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
        
        // 운동 시작 초기화
        currentSet = 1
        repetitions = 0
        sessionStartTime = nil // 세션 시작 시간을 카운트다운 후에 설정
        setStartTime = Date()
        setSummaries.removeAll()
        hasStartedExercise = false
        caloriesBurned = 0.0
        activeExerciseTime = 0.0
        lastActiveTime = nil
        totalRepetitionTime = 0.0
        repetitionCountForAverage = 0
        
        exerciseStartTime = nil // 운동 시작 시간을 카운트다운 후에 설정
        
        // 정보 레이블 초기화
        repetitionsValueLabel.text = "0 / \(targetRepetitions)"
        setsValueLabel.text = "\(currentSet) / \(targetSets)"
        averageSpeedValueLabel.text = "0.0초"
        caloriesValueLabel.text = "0.00 kcal"
        
        // 타이머 라벨 초기화
        timerLabel.text = "00:00"
        
        // 피드백 메시지 초기화
        feedbackMessageLabel.text = "운동을 시작합니다..."
        
        // 오버레이 색상 초기화
        overlayLayer.strokeColor = UIColor.orange.cgColor
        
        // 카운트다운 시작
        startCountdown()
    }
    
    // MARK: - 카운트다운 구현
    func startCountdown() {
        var countdown = 3
        countdownLabel.text = "\(countdown)"
        countdownLabel.isHidden = false
        countdownProgressLayer.strokeEnd = 0
        
        // 프로그레스 애니메이션
        let progressAnimation = CABasicAnimation(keyPath: "strokeEnd")
        progressAnimation.fromValue = 0
        progressAnimation.toValue = 1
        progressAnimation.duration = 3.0
        countdownProgressLayer.add(progressAnimation, forKey: "progressAnimation")
        
        // 프로그레스 업데이트 (strokeEnd을 실제로 업데이트)
        countdownProgressLayer.strokeEnd = 1
        
        // 기존 Timer를 countdownTimer에 할당
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
                self.feedbackMessageLabel.text = "운동을 시작하세요!"
                
                // 칼로리 타이머 시작
                self.startCalorieTimer()
                
                // 운동 타이머 시작
                self.startMainTimer()
            }
        }
    }
    //MARK: - 임시
    func saveExerciseSummary() {
        // 운동 종료 시간
        let endTime = Date()
        
        // 운동 종류
        let exerciseName: String
        switch selectedMode {
        case .squat: exerciseName = "스쿼트"
        case .pushUp: exerciseName = "푸쉬업"
        case .pullUp: exerciseName = "턱걸이"
        case .none: exerciseName = "선택되지 않음"
        }
        
        // 운동 요약 데이터 가져오기
        let summary: [String: Any] = [
            "date": endTime,                                  // 운동 종료 시간
            "exerciseType": exerciseName,                     // 운동 종류
            "sets": currentSet,                               // 총 세트 수
            "reps": repetitions,                              // 총 반복 횟수
            "calories": caloriesBurned,                       // 소모 칼로리
            "duration": endTime.timeIntervalSince(exerciseStartTime ?? endTime), // 운동 시간 (초)
            "averageSpeed": repetitionCountForAverage > 0 ? totalRepetitionTime / Double(repetitionCountForAverage) : 0.0, // 평균 속도
            "restTime": restTime                              // 세트 간 쉬는 시간
        ]
        
        // UserDefaults를 통해 저장
        var exerciseData = UserDefaults.standard.array(forKey: "exerciseSummaries") as? [[String: Any]] ?? []
        exerciseData.append(summary)
        UserDefaults.standard.setValue(exerciseData, forKey: "exerciseSummaries")
    }
    
    // MARK: - 운동 정지 액션
    @objc func stopExercise() {
        // 캡처 세션 정지
        captureSession.stopRunning()
        
        // 칼로리 타이머 정지
        stopCalorieTimer()
        
        // 메인 타이머 정지
        mainTimer?.invalidate()
        mainTimer = nil
        
        // 카운트다운 타이머 정지
        countdownTimer?.invalidate()
        countdownTimer = nil
        
        // 카메라 뷰 숨기기
        cameraView.isHidden = true
        
        // 피드백 메시지 업데이트
        feedbackMessageLabel.text = "운동 종료"
        
        // 운동 요약 표시
        displaySessionSummary()
        
        //결과 저장 임시
        saveExerciseSummary()
    }
    
    // MARK: - 일시정지 및 재시작 액션
    @objc func togglePauseResume() {
        if captureSession.isRunning {
            // 일시정지
            captureSession.stopRunning()
            stopCalorieTimer()
            mainTimer?.invalidate()
            
            // 버튼 제목 변경
            pauseResumeButton.setTitle("재시작", for: .normal)
            
            // 피드백 메시지 업데이트
            feedbackMessageLabel.text = "운동이 일시정지되었습니다."
        } else {
            // 재시작
            captureSession.startRunning()
            startCalorieTimer()
            startMainTimer()
            
            // 버튼 제목 변경
            pauseResumeButton.setTitle("일시정지", for: .normal)
            
            // 피드백 메시지 업데이트
            feedbackMessageLabel.text = "운동을 재개했습니다."
        }
    }
    
    // MARK: - 카메라 전환 액션
    @objc func switchCamera() {
        let newPosition: AVCaptureDevice.Position = (currentCameraPosition == .back) ? .front : .back
        configureCamera(position: newPosition)
    }
    
    
    // MARK: - 운동 요약 표시 메서드
    func displaySessionSummary() {
        // 운동 종료 시간
        let exerciseEndTime = Date()
        
        // 총 지속 시간 계산 (운동 시작부터 종료까지)
        let totalDuration = exerciseStartTime != nil ? exerciseEndTime.timeIntervalSince(exerciseStartTime!) : 0.0
        let totalTimeText = "\(Int(totalDuration / 60))분 \(Int(totalDuration) % 60)초"
        
        // 회당 평균 속도 계산 (총 반복 시간을 반복 횟수로 나눔)
        let averageSpeed: Double = repetitionCountForAverage > 0 ? totalRepetitionTime / Double(repetitionCountForAverage) : 0.0
        let averageSpeedText = String(format: "%.1f초", averageSpeed)
        
        // 운동 요약 내용
        let totalRepsText = "\(repetitions)회"
        let totalCaloriesText = String(format: "%.2f kcal", caloriesBurned) // 소수점 두 자리 표시
        
        // 현재 시간 (운동 종료 시간)
        let formatter = DateFormatter()
        formatter.dateFormat = "a h:mm" // "오전 6:34" 형식
        let currentTime = formatter.string(from: exerciseEndTime)
        
        // 모달 뷰컨트롤러 생성
        let summaryVC = UIViewController()
        summaryVC.modalPresentationStyle = .pageSheet
        summaryVC.view.backgroundColor = .systemBackground
        
        // 모달 시트 스타일 설정 (iOS 15+)
        if let sheet = summaryVC.sheetPresentationController {
            sheet.detents = [.medium()] // 모달 크기 변경: .medium() 사용
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        
        // preferredContentSize 설정 (약간 크기를 늘림)
        summaryVC.preferredContentSize = CGSize(width: view.bounds.width * 0.9, height: view.bounds.height * 0.5)
        
        // 헤더: 운동 완료 시간 및 메시지
        let headerLabel = UILabel()
        headerLabel.text = "운동 요약"
        headerLabel.font = UIFont.boldSystemFont(ofSize: 24)
        headerLabel.textAlignment = .center
        headerLabel.textColor = .systemGray
        
        let timeLabel = UILabel()
        timeLabel.text = "오늘 \(currentTime)"
        timeLabel.font = UIFont.systemFont(ofSize: 16)
        timeLabel.textAlignment = .center
        timeLabel.textColor = .systemGray
        
        // 운동 종류 문자열 변환
        let exerciseName: String
        switch selectedMode {
        case .squat:
            exerciseName = "스쿼트"
        case .pushUp:
            exerciseName = "푸쉬업"
        case .pullUp:
            exerciseName = "턱걸이"
        case .none:
            exerciseName = "선택되지 않음"
        }
        
        // 총 세트수 문자열
        let totalSetsText = "\(currentSet)세트"
        
        // 요약 항목 스택뷰 준비
        var items = [
            ("figure.walk", "운동 종류", exerciseName),
            ("checkmark", "반복 횟수", totalRepsText),
            ("checkmark.seal", "세트수", totalSetsText),
            ("clock", "지속 시간", totalTimeText),
            ("bolt", "회당 평균 속도", averageSpeedText),
            ("flame", "소모 칼로리", totalCaloriesText)
        ]
        
        // 세트간 쉬는 시간 조건부 추가
        if currentSet > 1 {
            let restTimeText = "\(restTime)초"
            items.insert(("timer", "세트간 쉬는 시간", restTimeText), at: 2) // 세 번째 항목으로 삽입
        }
        
        let summaryStackView = UIStackView()
        summaryStackView.axis = .vertical
        summaryStackView.spacing = 15 // 약간의 여유 공간 추가
        summaryStackView.alignment = .fill
        
        for (iconName, title, value) in items {
            let itemStackView = UIStackView()
            itemStackView.axis = .horizontal
            itemStackView.spacing = 10
            itemStackView.alignment = .center
            
            if let image = UIImage(systemName: iconName) {
                let iconImageView = UIImageView(image: image)
                iconImageView.tintColor = UIColor.systemGreen
                iconImageView.contentMode = .scaleAspectFit
                iconImageView.translatesAutoresizingMaskIntoConstraints = false
                iconImageView.widthAnchor.constraint(equalToConstant: 24).isActive = true
                iconImageView.heightAnchor.constraint(equalToConstant: 24).isActive = true
                
                itemStackView.addArrangedSubview(iconImageView)
            }
            
            let titleLabel = UILabel()
            titleLabel.text = title
            titleLabel.font = UIFont.systemFont(ofSize: 18)
            titleLabel.textColor = UIColor.systemGray
            
            let valueLabel = UILabel()
            valueLabel.text = value
            valueLabel.font = UIFont.boldSystemFont(ofSize: 18)
            valueLabel.textAlignment = .right
            valueLabel.translatesAutoresizingMaskIntoConstraints = false
            valueLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
            valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
            
            itemStackView.addArrangedSubview(titleLabel)
            itemStackView.addArrangedSubview(valueLabel)
            summaryStackView.addArrangedSubview(itemStackView)
        }
        
        // 확인 버튼
        let confirmButton = UIButton(type: .system)
        confirmButton.setTitle("확인", for: .normal)
        confirmButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.backgroundColor = UIColor.systemGreen
        confirmButton.layer.cornerRadius = 10
        confirmButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        confirmButton.addTarget(self, action: #selector(dismissSummary), for: .touchUpInside)
        
        // 메인 스택뷰
        let mainStackView = UIStackView(arrangedSubviews: [headerLabel, timeLabel, summaryStackView, confirmButton])
        mainStackView.axis = .vertical
        mainStackView.spacing = 20
        mainStackView.alignment = .fill
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        
        summaryVC.view.addSubview(mainStackView)
        
        // 레이아웃 설정
        NSLayoutConstraint.activate([
            mainStackView.leadingAnchor.constraint(equalTo: summaryVC.view.leadingAnchor, constant: 20),
            mainStackView.trailingAnchor.constraint(equalTo: summaryVC.view.trailingAnchor, constant: -20),
            mainStackView.centerYAnchor.constraint(equalTo: summaryVC.view.centerYAnchor)
        ])
        
        // 운동 종료 시 카메라 뷰 숨기기 및 피드백 메시지 업데이트
        cameraView.isHidden = true
        feedbackMessageLabel.text = "운동 종료"
        
        // 모달 표시
        present(summaryVC, animated: true, completion: nil)
    }

    // MARK: - 모달 닫기 및 홈화면으로 전환 메서드
    @objc func dismissSummary() {
        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            // 네비게이션 컨트롤러가 있는지 확인
            if let navigationController = self.navigationController {
                // 루트 뷰컨트롤러로 돌아감 (홈화면)
                navigationController.popToRootViewController(animated: true)
            } else {
                // 네비게이션 컨트롤러가 없으면 현재 뷰컨트롤러 닫기
                self.dismiss(animated: true, completion: nil)
            }
            
            // 카메라 뷰 숨기기 및 피드백 메시지 업데이트
            self.cameraView.isHidden = true
            self.feedbackMessageLabel.text = "운동 종료"
        }
    }
    
    // MARK: - 피드백 메시지 레이블 업데이트 메서드
    func updateFeedbackMessage(text: String) {
        feedbackMessageLabel.text = text
    }
    
    // MARK: - BMR 계산 메서드 (Harris-Benedict Equation)
    func calculateBMR(gender: Int, age: Int, height: Double, weight: Double) -> Double {
        // gender: 0 = 남성, 1 = 여성
        if gender == 0 {
            // 남성 BMR = 88.362 + (13.397 * 체중 kg) + (4.799 * 키 cm) - (5.677 * 나이)
            return 88.362 + (13.397 * weight) + (4.799 * height) - (5.677 * Double(age))
        } else {
            // 여성 BMR = 447.593 + (9.247 * 체중 kg) + (3.098 * 키 cm) - (4.330 * 나이)
            return 447.593 + (9.247 * weight) + (3.098 * height) - (4.330 * Double(age))
        }
    }
    
    // MARK: - 칼로리 계산 메서드 (BMR 및 MET 기반)
    func calculateCaloriesBurned(exerciseMode: ExerciseMode, activeExerciseTime: TimeInterval) -> Double {
        // 사용자 정보 불러오기
        let weight = UserDefaults.standard.double(forKey: "weight")
        let height = UserDefaults.standard.double(forKey: "height")
        let age = UserDefaults.standard.integer(forKey: "age")
        let genderIndex = UserDefaults.standard.integer(forKey: "gender") // 0: 남성, 1: 여성
        
        // 사용자 정보 유효성 검사
        guard weight > 0, height > 0, age > 0, (genderIndex == 0 || genderIndex == 1) else {
            return 0.0
        }
        
        // BMR 계산
        let bmr = calculateBMR(gender: genderIndex, age: age, height: height, weight: weight)
        
        // MET 값 설정
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
        
        // 운동 시간 계산 (초 단위에서 분 단위로 변환)
        let activeExerciseTimeMinutes = activeExerciseTime / 60.0
        
        // MET * (BMR / 1440) * 운동 시간(분) = 소모 칼로리
        let caloriesBurned = mets * (bmr / 1440.0) * activeExerciseTimeMinutes
        
        return caloriesBurned
    }
    
    // MARK: - 반복 카운트 메서드
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
        
        // 칼로리 소모 업데이트
        caloriesBurned = calculateCaloriesBurned(exerciseMode: selectedMode, activeExerciseTime: activeExerciseTime)
        caloriesValueLabel.text = String(format: "%.2f kcal", caloriesBurned) // 소수점 두 자리 표시
        
        repetitionsValueLabel.text = "\(repetitions) / \(targetRepetitions)"
        
        // 평균 속도 실시간 업데이트
        if repetitionCountForAverage > 0 {
            let averageSpeed = totalRepetitionTime / Double(repetitionCountForAverage)
            averageSpeedValueLabel.text = String(format: "%.1f초", averageSpeed)
        }
        
        if repetitions >= targetRepetitions {
            completeSet()
        }
        
        // 타이머 레이블 애니메이션 추가
        animateTimerLabel()
        
        // 타이머 라벨 배경을 초록색으로 변경
        timerLabel.backgroundColor = .systemGreen
        
        // 오버레이 색상 변경
        overlayLayer.strokeColor = UIColor.systemGreen.cgColor
        
        // 0.5초 후 다시 빨간색으로 변경
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.timerLabel.backgroundColor = .red
            self.overlayLayer.strokeColor = UIColor.orange.cgColor
            
        }
        
        // AI 음성 피드백
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
    
    // MARK: - 숫자 음성 피드백 메서드
    func speakNumber(count: Int) {
        guard isSpeechEnabled else { return }
        
        let koreanNumbers = ["영", "하나", "둘", "셋", "넷", "다섯", "여섯", "일곱", "여덟", "아홉", "열",
                             "열하나", "열둘", "열셋", "열넷", "열다섯", "열여섯", "열일곱", "열여덟", "열아홉", "스물"]
        
        if count <= koreanNumbers.count && count >= 0 {
            let numberString = koreanNumbers[count]
            let utterance = AVSpeechUtterance(string: numberString)
            utterance.voice = AVSpeechSynthesisVoice(language: "ko-KR")
            speechSynthesizer.speak(utterance)
        }
    }
    
    // MARK: - 라벨 색상 업데이트 메서드
    func updateInfoLabelsColor(isActive: Bool) {
        // 정보 제목은 회색으로, 정보 값은 흰색으로 유지
        // 별도의 색상 변경이 필요 없으므로 빈 메서드로 유지
    }
    
    // MARK: - 휴식 타이머 & 다음 세트 시작
    func startRestTimer() {
        remainingRestTime = restTime
        updateRestCountdown()
        
        // 휴식 시간 동안 카메라 뷰를 숨기고 피드백 메시지 설정
        cameraView.isHidden = true
        feedbackMessageLabel.text = "휴식 시간 시작"
        
        // 카운트다운 레이블과 프로그레스 바 표시
        countdownLabel.text = "\(remainingRestTime)"
        countdownLabel.isHidden = false
        countdownProgressLayer.strokeEnd = 0
        
        // 프로그레스 애니메이션 설정
        let progressAnimation = CABasicAnimation(keyPath: "strokeEnd")
        progressAnimation.fromValue = 0
        progressAnimation.toValue = 1
        progressAnimation.duration = TimeInterval(restTime)
        countdownProgressLayer.add(progressAnimation, forKey: "restProgressAnimation")
        
        // 프로그레스 바 실제 업데이트
        countdownProgressLayer.strokeEnd = 1
        
        // 휴식 타이머 시작
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
        // Modified: 쉬는 시간 동안 카운트다운 레이블 업데이트
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
            // Modified: 카메라 뷰 다시 보이기
            cameraView.isHidden = false
            
            // Modified: 카운트다운 시작 제거하고 즉시 운동 인식 시작
            setupExerciseMode()
            feedbackMessageLabel.text = "운동을 시작하세요!"
            
            // Modified: 운동 인식을 시작하기 위해 캡처 세션 실행
            captureSession.startRunning()
            
            // Modified: 휴식 시간 후 검은 배경 해제 및 카운트다운 숨기기
            DispatchQueue.main.async {
                self.cameraView.backgroundColor = .clear // 기본 색상으로 설정
                self.countdownLabel.isHidden = true
                self.countdownProgressLayer.strokeEnd = 0
                self.overlayLayer.strokeColor = UIColor.orange.cgColor
            }
            
            // 칼로리 타이머와 운동 타이머 시작
            startCalorieTimer()
            startMainTimer()
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
            stopCalorieTimer() // 휴식 중 칼로리 타이머 정지
            startRestTimer()
        }
    }
    
    // MARK: - 각 운동 분석 메서드
    func analyzeSquat(results: VNHumanBodyPoseObservation) {
        guard let recognizedPoints = try? results.recognizedPoints(.all) else { return }
        
        if let leftKnee = recognizedPoints[.leftKnee], let rightKnee = recognizedPoints[.rightKnee],
           let leftHip = recognizedPoints[.leftHip], let rightHip = recognizedPoints[.rightHip] {
            
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
                            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                            countRepetition()
                        }
                        isPositionCorrect = false
                    }
                }
            }
        }
    }
    
    func analyzePushUp(results: VNHumanBodyPoseObservation) {
        guard let recognizedPoints = try? results.recognizedPoints(.all) else { return }
        
        if let leftElbow = recognizedPoints[.leftElbow], let rightElbow = recognizedPoints[.rightElbow],
           let leftShoulder = recognizedPoints[.leftShoulder], let rightShoulder = recognizedPoints[.rightShoulder] {
            
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
                        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                        countRepetition()
                    }
                    isPositionCorrect = false
                }
            }
        }
    }
    
    func analyzePullUp(results: VNHumanBodyPoseObservation) {
        guard let recognizedPoints = try? results.recognizedPoints(.all) else { return }
        
        guard let leftShoulder = recognizedPoints[.leftShoulder],
              let rightShoulder = recognizedPoints[.rightShoulder],
              let leftWrist = recognizedPoints[.leftWrist],
              let rightWrist = recognizedPoints[.rightWrist] else { return }
        
        let leftShoulderPos = previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: leftShoulder.location.x, y: 1 - leftShoulder.location.y))
        let rightShoulderPos = previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: rightShoulder.location.x, y: 1 - rightShoulder.location.y))
        let leftWristPos = previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: leftWrist.location.x, y: 1 - leftWrist.location.y))
        let rightWristPos = previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: rightWrist.location.x, y: 1 - rightWrist.location.y))
        
        let shoulderY = (leftShoulderPos.y + rightShoulderPos.y) / 2
        let wristY = (leftWristPos.y + rightWristPos.y) / 2
        
        let isInPullUpPosition = wristY < shoulderY - 50
        
        if isInPullUpPosition {
            if !isPositionCorrect {
                isPositionCorrect = true
                holdStartTime = Date()
            }
        } else {
            if isPositionCorrect {
                let holdDuration = Date().timeIntervalSince(holdStartTime ?? Date())
                if holdDuration >= 1.0 {
                    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                    countRepetition()
                }
                isPositionCorrect = false
            }
        }
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
            // 오류 발생 시 별도의 처리가 필요하다면 여기에 추가
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

        if let leftShoulder = recognizedPoints[.leftShoulder], let rightShoulder = recognizedPoints[.rightShoulder],
           let leftElbow = recognizedPoints[.leftElbow], let rightElbow = recognizedPoints[.rightElbow],
           let leftWrist = recognizedPoints[.leftWrist], let rightWrist = recognizedPoints[.rightWrist],
           let leftHip = recognizedPoints[.leftHip], let rightHip = recognizedPoints[.rightHip],
           let leftKnee = recognizedPoints[.leftKnee], let rightKnee = recognizedPoints[.rightKnee],
           let leftAnkle = recognizedPoints[.leftAnkle], let rightAnkle = recognizedPoints[.rightAnkle] {
            
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
        // 기존 타이머 취소
        calorieTimer?.cancel()
        
        // 새로운 타이머 생성
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
        // 현재 운동 상태에 따라 activeExerciseTime 업데이트
        if isPositionCorrect {
            if let lastTime = lastActiveTime {
                let elapsed = Date().timeIntervalSince(lastTime)
                activeExerciseTime += elapsed
                lastActiveTime = Date()
                
                // 칼로리 소모 업데이트
                caloriesBurned = calculateCaloriesBurned(exerciseMode: selectedMode, activeExerciseTime: activeExerciseTime)
                caloriesValueLabel.text = String(format: "%.2f kcal", caloriesBurned) // 소수점 두 자리 표시
            } else {
                // 운동이 시작된 시점 기록
                lastActiveTime = Date()
            }
        }
    }
    
    // MARK: - 메인 타이머 시작 메서드
    func startMainTimer() {
        // 기존 타이머 정지
        mainTimer?.invalidate()
        
        // 운동 시작 시간을 기록
        if exerciseStartTime == nil {
            exerciseStartTime = Date()
        }
        
        // 새로운 타이머 시작
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
