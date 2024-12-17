import UIKit

// MARK: - ViewController 클래스
class ViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
    
    // MARK: - ExerciseSettings 구조체 정의
    struct ExerciseSettings: Codable {
        var targetRepetitions: Int
        var targetSets: Int
        var restTime: Int
    }
    
    // MARK: - ExerciseModeTag Enum 정의
    enum ExerciseModeTag: Int {
        case squat = 1
        case pushUp = 2
        case pullUp = 3
    }
    
    // MARK: - 프로퍼티
    // 운동 모드별 설정 저장을 위한 딕셔너리
    var exerciseSettings: [a.ExerciseMode: ExerciseSettings] = [
        .squat: ExerciseSettings(targetRepetitions: 10, targetSets: 1, restTime: 30),
        .pushUp: ExerciseSettings(targetRepetitions: 10, targetSets: 1, restTime: 30),
        .pullUp: ExerciseSettings(targetRepetitions: 10, targetSets: 1, restTime: 30),
        .none: ExerciseSettings(targetRepetitions: 10, targetSets: 1, restTime: 30)
    ]
    
    // 피커뷰 옵션
    let goalRepetitionsOptions = Array(1...50)
    let setsOptions = Array(1...10)
    let restTimeOptions = [10, 20, 30, 60, 90, 120]
    
    // 피커뷰 및 설정 UI 관련 프로퍼티
    var settingsContainerView: UIView!
    var repetitionsPicker: UIPickerView!
    var setsPicker: UIPickerView!
    var restTimePicker: UIPickerView!
    var saveSettingsButton: UIButton!
    var cancelSettingsButton: UIButton!
    
    // 운동 버튼들 참조를 유지하기 위한 프로퍼티
    var squatButton: UIView!
    var pushUpButton: UIView!
    var pullUpButton: UIView!
    var setButton: UIView!
    
    // 현재 설정 중인 운동 모드
    var currentExerciseMode: a.ExerciseMode?
    
    // MARK: - UserDefaults 키 정의
    struct UserDefaultsKeys {
        static let squatSettings = "squatSettings"
        static let pushUpSettings = "pushUpSettings"
        static let pullUpSettings = "pullUpSettings"
        static let noneSettings = "noneSettings"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadSettingsFromUserDefaults() // 설정 불러오기
        setupUI()
        updateButtonTitles() // 불러온 설정으로 버튼 타이틀 업데이트
    }
    
    // MARK: - UI 구성
    func setupUI() {
        // 배경색 설정
        view.backgroundColor = .systemBackground
        
        // 상단 제목 추가
        let headerLabel = UILabel()
        headerLabel.text = "EXERCISE"
        headerLabel.textAlignment = .left
        headerLabel.font = UIFont.boldSystemFont(ofSize: 40)
        headerLabel.textColor = UIColor.white
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerLabel)
        
        // 버튼 생성 및 참조 저장
        squatButton = createCustomButton(
            title: "스쿼트",
            subtitle: "\(exerciseSettings[.squat]?.targetRepetitions ?? 10)회 / \(exerciseSettings[.squat]?.targetSets ?? 1)set / \(exerciseSettings[.squat]?.restTime ?? 30)s 휴식",
            color: .systemGreen,
            iconName: "figure.cross.training",
            exerciseMode: .squat,
            mainAction: #selector(squatButtonTapped),
            settingsAction: #selector(settingsButtonTapped(_:))
        )
        pushUpButton = createCustomButton(
            title: "푸쉬업",
            subtitle: "\(exerciseSettings[.pushUp]?.targetRepetitions ?? 10)회 / \(exerciseSettings[.pushUp]?.targetSets ?? 1)set / \(exerciseSettings[.pushUp]?.restTime ?? 30)s 휴식",
            color: .systemBlue,
            iconName: "figure.wrestling",
            exerciseMode: .pushUp,
            mainAction: #selector(pushUpButtonTapped),
            settingsAction: #selector(settingsButtonTapped(_:))
        )
        pullUpButton = createCustomButton(
            title: "턱걸이",
            subtitle: "\(exerciseSettings[.pullUp]?.targetRepetitions ?? 10)회 / \(exerciseSettings[.pullUp]?.targetSets ?? 1)set / \(exerciseSettings[.pullUp]?.restTime ?? 30)s 휴식",
            color: .systemPurple,
            iconName: "figure.play",
            exerciseMode: .pullUp,
            mainAction: #selector(pullUpButtonTapped),
            settingsAction: #selector(settingsButtonTapped(_:))
        )
        setButton = createCustomButton(  // 추후 업데이트 기능
            title: "3개 운동 총합",
            subtitle: "",
            color: .systemOrange,
            iconName: "list.bullet",
            exerciseMode: .none,
            mainAction: #selector(setButtonTapped),
            settingsAction: nil
        )
        
        // 버튼 스택뷰 생성
        let stackView = UIStackView(arrangedSubviews: [squatButton, pushUpButton, pullUpButton, setButton])
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.alignment = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)
        
        // 하단 설명 라벨 추가
        let footerLabel = UILabel()
        footerLabel.text = "운동 목표를 설정하려면 각 버튼 설정 아이콘을 누르세요"
        footerLabel.textAlignment = .center
        footerLabel.font = UIFont.systemFont(ofSize: 14)
        footerLabel.textColor = UIColor.lightGray
        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        footerLabel.isUserInteractionEnabled = false
        view.addSubview(footerLabel)
        
        // 설정 컨테이너 뷰 생성 (숨김 상태)
        setupSettingsContainerView()
        
        // 오토레이아웃 설정
        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            headerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            headerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            stackView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 40),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            footerLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            footerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            footerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    // MARK: - 설정 컨테이너 뷰 설정
    func setupSettingsContainerView() {
        settingsContainerView = UIView()
        settingsContainerView.translatesAutoresizingMaskIntoConstraints = false
        settingsContainerView.backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        settingsContainerView.layer.cornerRadius = 15
        settingsContainerView.clipsToBounds = true
        settingsContainerView.isHidden = true // 초기에는 숨김
        view.addSubview(settingsContainerView)
        
        // 레이블 설정
        let repetitionsLabel = UILabel()
        repetitionsLabel.text = "개수"
        repetitionsLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        repetitionsLabel.textColor = .white
        repetitionsLabel.textAlignment = .center
        repetitionsLabel.translatesAutoresizingMaskIntoConstraints = false
        repetitionsLabel.isUserInteractionEnabled = false
        
        let setsLabel = UILabel()
        setsLabel.text = "세트"
        setsLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        setsLabel.textColor = .white
        setsLabel.textAlignment = .center
        setsLabel.translatesAutoresizingMaskIntoConstraints = false
        setsLabel.isUserInteractionEnabled = false
        
        let restTimeLabel = UILabel()
        restTimeLabel.text = "휴식 시간"
        restTimeLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        restTimeLabel.textColor = .white
        restTimeLabel.textAlignment = .center
        restTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        restTimeLabel.isUserInteractionEnabled = false
        
        // 피커뷰 설정
        repetitionsPicker = UIPickerView()
        repetitionsPicker.delegate = self
        repetitionsPicker.dataSource = self
        repetitionsPicker.tag = 1
        repetitionsPicker.translatesAutoresizingMaskIntoConstraints = false
        
        setsPicker = UIPickerView()
        setsPicker.delegate = self
        setsPicker.dataSource = self
        setsPicker.tag = 2
        setsPicker.translatesAutoresizingMaskIntoConstraints = false
        
        restTimePicker = UIPickerView()
        restTimePicker.delegate = self
        restTimePicker.dataSource = self
        restTimePicker.tag = 3
        restTimePicker.translatesAutoresizingMaskIntoConstraints = false
        
        // 초기 선택값 설정은 presentSettings에서 수행
        
        // 저장 버튼
        saveSettingsButton = UIButton(type: .system)
        saveSettingsButton.setTitle("저장", for: .normal)
        saveSettingsButton.setTitleColor(.white, for: .normal)
        saveSettingsButton.backgroundColor = .systemGreen
        saveSettingsButton.layer.cornerRadius = 10
        saveSettingsButton.translatesAutoresizingMaskIntoConstraints = false
        saveSettingsButton.addTarget(self, action: #selector(saveSettingsTapped), for: .touchUpInside)
        
        // 취소 버튼
        cancelSettingsButton = UIButton(type: .system)
        cancelSettingsButton.setTitle("취소", for: .normal)
        cancelSettingsButton.setTitleColor(.white, for: .normal)
        cancelSettingsButton.backgroundColor = .systemRed
        cancelSettingsButton.layer.cornerRadius = 10
        cancelSettingsButton.translatesAutoresizingMaskIntoConstraints = false
        cancelSettingsButton.addTarget(self, action: #selector(cancelSettingsTapped), for: .touchUpInside)
        
        // 각 레이블과 피커를 수직 스택뷰로 감싸기
        let repetitionsStack = UIStackView(arrangedSubviews: [repetitionsLabel, repetitionsPicker])
        repetitionsStack.axis = .vertical
        repetitionsStack.spacing = 5
        repetitionsStack.alignment = .fill
        repetitionsStack.translatesAutoresizingMaskIntoConstraints = false
        
        let setsStack = UIStackView(arrangedSubviews: [setsLabel, setsPicker])
        setsStack.axis = .vertical
        setsStack.spacing = 5
        setsStack.alignment = .fill
        setsStack.translatesAutoresizingMaskIntoConstraints = false
        
        let restTimeStack = UIStackView(arrangedSubviews: [restTimeLabel, restTimePicker])
        restTimeStack.axis = .vertical
        restTimeStack.spacing = 5
        restTimeStack.alignment = .fill
        restTimeStack.translatesAutoresizingMaskIntoConstraints = false
        
        // 세 개의 수직 스택뷰를 가로 스택뷰로 감싸기
        let pickersStack = UIStackView(arrangedSubviews: [repetitionsStack, setsStack, restTimeStack])
        pickersStack.axis = .horizontal
        pickersStack.spacing = 10
        pickersStack.alignment = .center
        pickersStack.distribution = .fillEqually
        pickersStack.translatesAutoresizingMaskIntoConstraints = false
        settingsContainerView.addSubview(pickersStack)
        
        // 버튼 스택뷰 추가
        let buttonsStack = UIStackView(arrangedSubviews: [saveSettingsButton, cancelSettingsButton])
        buttonsStack.axis = .horizontal
        buttonsStack.spacing = 20
        buttonsStack.alignment = .fill
        buttonsStack.distribution = .fillEqually
        buttonsStack.translatesAutoresizingMaskIntoConstraints = false
        settingsContainerView.addSubview(buttonsStack)
        
        // 오토레이아웃 설정
        NSLayoutConstraint.activate([
            settingsContainerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            settingsContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            settingsContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            settingsContainerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 250),
            
            pickersStack.topAnchor.constraint(equalTo: settingsContainerView.topAnchor, constant: 20),
            pickersStack.leadingAnchor.constraint(equalTo: settingsContainerView.leadingAnchor, constant: 20),
            pickersStack.trailingAnchor.constraint(equalTo: settingsContainerView.trailingAnchor, constant: -20),
            
            buttonsStack.topAnchor.constraint(equalTo: pickersStack.bottomAnchor, constant: 20),
            buttonsStack.leadingAnchor.constraint(equalTo: settingsContainerView.leadingAnchor, constant: 20),
            buttonsStack.trailingAnchor.constraint(equalTo: settingsContainerView.trailingAnchor, constant: -20),
            buttonsStack.heightAnchor.constraint(equalToConstant: 44),
            buttonsStack.bottomAnchor.constraint(equalTo: settingsContainerView.bottomAnchor, constant: -20)
        ])
    }
    
    // MARK: - 버튼 및 세팅 버튼 추가
    func createCustomButton(title: String, subtitle: String, color: UIColor, iconName: String, exerciseMode: a.ExerciseMode, mainAction: Selector?, settingsAction: Selector?) -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .black // 배경색을 검은색으로 변경
        containerView.layer.cornerRadius = 15
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = color.cgColor
        containerView.heightAnchor.constraint(equalToConstant: 90).isActive = true
        
        // 메인 버튼
        let mainButton = UIButton(type: .system)
        mainButton.translatesAutoresizingMaskIntoConstraints = false
        mainButton.backgroundColor = .clear // 투명하게 설정
        mainButton.addTarget(self, action: mainAction ?? #selector(doNothing), for: .touchUpInside)
        mainButton.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchDown)
        mainButton.addTarget(self, action: #selector(buttonReleased(_:)), for: [.touchUpInside, .touchCancel, .touchDragExit])
        containerView.addSubview(mainButton)
        
        // 아이콘과 텍스트 스택뷰
        let iconImageView = UIImageView(image: UIImage(systemName: iconName))
        iconImageView.tintColor = color
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.widthAnchor.constraint(equalToConstant: 40).isActive = true
        iconImageView.heightAnchor.constraint(equalToConstant: 40).isActive = true
        iconImageView.isUserInteractionEnabled = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = UIColor.white
        titleLabel.isUserInteractionEnabled = false
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = UIFont.systemFont(ofSize: 14)
        subtitleLabel.textColor = color
        subtitleLabel.isUserInteractionEnabled = false
        
        let textStackView = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStackView.axis = .vertical
        textStackView.spacing = 4
        textStackView.isUserInteractionEnabled = false
        
        let contentStackView = UIStackView(arrangedSubviews: [iconImageView, textStackView])
        contentStackView.axis = .horizontal
        contentStackView.spacing = 16
        contentStackView.alignment = .center
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.isUserInteractionEnabled = false
        mainButton.addSubview(contentStackView)
        
        // 오토레이아웃 설정
        NSLayoutConstraint.activate([
            contentStackView.leadingAnchor.constraint(equalTo: mainButton.leadingAnchor, constant: 16),
            contentStackView.centerYAnchor.constraint(equalTo: mainButton.centerYAnchor)
        ])
        
        // 설정 버튼 추가 (settingsAction이 있을 경우에만)
        if let settingsAction = settingsAction {
            let settingsButton = UIButton(type: .system)
            settingsButton.setImage(UIImage(systemName: "slider.horizontal.3"), for: .normal)
            settingsButton.tintColor = .white
            settingsButton.translatesAutoresizingMaskIntoConstraints = false
            settingsButton.addTarget(self, action: settingsAction, for: .touchUpInside)
            settingsButton.isUserInteractionEnabled = true
            // 설정 버튼의 태그를 ExerciseModeTag에 따라 설정
            switch exerciseMode {
            case .squat:
                settingsButton.tag = ExerciseModeTag.squat.rawValue
            case .pushUp:
                settingsButton.tag = ExerciseModeTag.pushUp.rawValue
            case .pullUp:
                settingsButton.tag = ExerciseModeTag.pullUp.rawValue
            case .none:
                settingsButton.tag = 0
            }
            
            containerView.addSubview(settingsButton)
            
            // 오토레이아웃 설정
            NSLayoutConstraint.activate([
                settingsButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
                settingsButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
                settingsButton.widthAnchor.constraint(equalToConstant: 24),
                settingsButton.heightAnchor.constraint(equalToConstant: 24)
            ])
        }
        
        // 오토레이아웃 설정
        NSLayoutConstraint.activate([
            mainButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            mainButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            mainButton.topAnchor.constraint(equalTo: containerView.topAnchor),
            mainButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        return containerView
    }
    
    // MARK: - 버튼 애니메이션 효과
    @objc func buttonPressed(_ sender: UIButton) {
        UIView.animate(withDuration: 0.2) {
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
    }
    
    @objc func buttonReleased(_ sender: UIButton) {
        UIView.animate(withDuration: 0.2) {
            sender.transform = CGAffineTransform.identity
        }
    }
    
    // MARK: - 버튼 동작
    @objc func squatButtonTapped() {
        navigateToExerciseMode(.squat)
    }
    
    @objc func pushUpButtonTapped() {
        navigateToExerciseMode(.pushUp)
    }
    
    @objc func pullUpButtonTapped() {
        navigateToExerciseMode(.pullUp)
    }
    
    @objc func setButtonTapped() {
        // 세트 프로 기능을 위한 액션 구현 예정
    }
    
    @objc func settingsButtonTapped(_ sender: UIButton) {
        // 설정 버튼의 태그를 통해 어떤 운동인지 식별
        switch sender.tag {
        case ExerciseModeTag.squat.rawValue:
            currentExerciseMode = .squat
        case ExerciseModeTag.pushUp.rawValue:
            currentExerciseMode = .pushUp
        case ExerciseModeTag.pullUp.rawValue:
            currentExerciseMode = .pullUp
        default:
            currentExerciseMode = .none
        }
        presentSettings()
    }
    
    @objc func doNothing() {
        // 아무 동작도 하지 않음
    }
    
    // MARK: - 화면 전환
    func navigateToExerciseMode(_ mode: a.ExerciseMode) {
        if let exerciseVC = storyboard?.instantiateViewController(withIdentifier: "ExerciseViewController") as? a {
            exerciseVC.selectedMode = mode
            // 해당 운동 모드의 설정을 전달
            if let settings = exerciseSettings[mode] {
                exerciseVC.targetRepetitions = settings.targetRepetitions
                exerciseVC.targetSets = settings.targetSets
                exerciseVC.restTime = settings.restTime
            }
            exerciseVC.modalPresentationStyle = .fullScreen
            present(exerciseVC, animated: true, completion: nil)
        } else {
            print("ExerciseViewController를 스토리보드에서 찾을 수 없습니다.") // 디버깅용
        }
    }
    
    // MARK: - 설정 화면 호출
    func presentSettings() {
        // 설정 컨테이너 뷰를 표시 (애니메이션 포함)
        settingsContainerView.alpha = 0
        settingsContainerView.isHidden = false
        UIView.animate(withDuration: 0.3) {
            self.settingsContainerView.alpha = 1.0
        }
        
        // 현재 운동 모드에 따른 피커뷰 값 반영
        guard let mode = currentExerciseMode else { return }
        
        if let settings = exerciseSettings[mode] {
            if let repetitionsIndex = goalRepetitionsOptions.firstIndex(of: settings.targetRepetitions) {
                repetitionsPicker.selectRow(repetitionsIndex, inComponent: 0, animated: false)
            }
            if let setsIndex = setsOptions.firstIndex(of: settings.targetSets) {
                setsPicker.selectRow(setsIndex, inComponent: 0, animated: false)
            }
            if let restTimeIndex = restTimeOptions.firstIndex(of: settings.restTime) {
                restTimePicker.selectRow(restTimeIndex, inComponent: 0, animated: false)
            }
        }
    }
    
    // MARK: - 설정 저장 및 취소 액션
    @objc func saveSettingsTapped() {
        guard let mode = currentExerciseMode else { return }
        
        // 현재 피커뷰에서 선택된 값 가져오기
        let repetitionsRow = repetitionsPicker.selectedRow(inComponent: 0)
        let setsRow = setsPicker.selectedRow(inComponent: 0)
        let restTimeRow = restTimePicker.selectedRow(inComponent: 0)
        
        let newRepetitions = goalRepetitionsOptions[repetitionsRow]
        let newSets = setsOptions[setsRow]
        let newRestTime = restTimeOptions[restTimeRow]
        
        // 운동별 설정 업데이트
        exerciseSettings[mode] = ExerciseSettings(targetRepetitions: newRepetitions, targetSets: newSets, restTime: newRestTime)
        
        // 설정 컨테이너 뷰 숨기기 (애니메이션 포함)
        UIView.animate(withDuration: 0.3, animations: {
            self.settingsContainerView.alpha = 0
        }) { _ in
            self.settingsContainerView.isHidden = true
        }
        
        // 해당 운동 버튼의 타이틀 업데이트
        updateButtonTitles(for: mode)
    }
    
    @objc func cancelSettingsTapped() {
        // 설정 컨테이너 뷰 숨기기 (애니메이션 포함)
        UIView.animate(withDuration: 0.3, animations: {
            self.settingsContainerView.alpha = 0
        }) { _ in
            self.settingsContainerView.isHidden = true
        }
        
        // 초기 설정값으로 피커뷰 리셋은 이미 settingsContainerView를 표시할 때 했으므로 별도의 작업이 필요 없습니다
    }
    
    // MARK: - UIPickerViewDataSource
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch pickerView.tag {
        case 1:
            return goalRepetitionsOptions.count
        case 2:
            return setsOptions.count
        case 3:
            return restTimeOptions.count
        default:
            return 0
        }
    }
    
    // MARK: - UIPickerViewDelegate
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        switch pickerView.tag {
        case 1:
            return "\(goalRepetitionsOptions[row]) 회"
        case 2:
            return "\(setsOptions[row]) set"
        case 3:
            return "\(restTimeOptions[row]) s"
        default:
            return nil
        }
    }
    
    // MARK: - 버튼 타이틀 업데이트
    func updateButtonTitles() {
        // 각 운동 모드별로 버튼 타이틀 업데이트
        for (mode, settings) in exerciseSettings {
            switch mode {
            case .squat:
                updateButtonSubtitle(button: squatButton, newSubtitle: "\(settings.targetRepetitions)회 / \(settings.targetSets)set / \(settings.restTime)s 휴식")
            case .pushUp:
                updateButtonSubtitle(button: pushUpButton, newSubtitle: "\(settings.targetRepetitions)회 / \(settings.targetSets)set / \(settings.restTime)s 휴식")
            case .pullUp:
                updateButtonSubtitle(button: pullUpButton, newSubtitle: "\(settings.targetRepetitions)회 / \(settings.targetSets)set / \(settings.restTime)s 휴식")
            case .none:
                // 세트 프로는 별도의 서브타이틀을 사용
                updateButtonSubtitle(button: setButton, newSubtitle: "세트 설정을 편집하려면 클릭하세요.")
            }
        }
    }
    
    func updateButtonTitles(for mode: a.ExerciseMode) {
        guard let settings = exerciseSettings[mode] else { return }
        switch mode {
        case .squat:
            updateButtonSubtitle(button: squatButton, newSubtitle: "\(settings.targetRepetitions)회 / \(settings.targetSets)set / \(settings.restTime)s 휴식")
        case .pushUp:
            updateButtonSubtitle(button: pushUpButton, newSubtitle: "\(settings.targetRepetitions)회 / \(settings.targetSets)set / \(settings.restTime)s 휴식")
        case .pullUp:
            updateButtonSubtitle(button: pullUpButton, newSubtitle: "\(settings.targetRepetitions)회 / \(settings.targetSets)set / \(settings.restTime)s 휴식")
        case .none:
            updateButtonSubtitle(button: setButton, newSubtitle: "세트 설정을 편집하려면 클릭하세요.")
        }
    }
    
    func updateButtonSubtitle(button: UIView, newSubtitle: String) {
        if let mainButton = button.subviews.first as? UIButton,
           let contentStackView = mainButton.subviews.first as? UIStackView,
           let textStackView = contentStackView.arrangedSubviews.last as? UIStackView,
           let subtitleLabel = textStackView.arrangedSubviews.last as? UILabel {
            subtitleLabel.text = newSubtitle
        }
    }
    
    // MARK: - 설정 저장 및 불러오기
    func saveSettingsToUserDefaults() {
        let encoder = JSONEncoder()
        
        if let squatData = try? encoder.encode(exerciseSettings[.squat]),
           let pushUpData = try? encoder.encode(exerciseSettings[.pushUp]),
           let pullUpData = try? encoder.encode(exerciseSettings[.pullUp]),
           let noneData = try? encoder.encode(exerciseSettings[.none]) {
            
            UserDefaults.standard.set(squatData, forKey: UserDefaultsKeys.squatSettings)
            UserDefaults.standard.set(pushUpData, forKey: UserDefaultsKeys.pushUpSettings)
            UserDefaults.standard.set(pullUpData, forKey: UserDefaultsKeys.pullUpSettings)
            UserDefaults.standard.set(noneData, forKey: UserDefaultsKeys.noneSettings)
        }
    }
    
    func loadSettingsFromUserDefaults() {
        let decoder = JSONDecoder()
        
        if let squatData = UserDefaults.standard.data(forKey: UserDefaultsKeys.squatSettings),
           let squatSettings = try? decoder.decode(ExerciseSettings.self, from: squatData) {
            exerciseSettings[.squat] = squatSettings
        }
        
        if let pushUpData = UserDefaults.standard.data(forKey: UserDefaultsKeys.pushUpSettings),
           let pushUpSettings = try? decoder.decode(ExerciseSettings.self, from: pushUpData) {
            exerciseSettings[.pushUp] = pushUpSettings
        }
        
        if let pullUpData = UserDefaults.standard.data(forKey: UserDefaultsKeys.pullUpSettings),
           let pullUpSettings = try? decoder.decode(ExerciseSettings.self, from: pullUpData) {
            exerciseSettings[.pullUp] = pullUpSettings
        }
        
        if let noneData = UserDefaults.standard.data(forKey: UserDefaultsKeys.noneSettings),
           let noneSettings = try? decoder.decode(ExerciseSettings.self, from: noneData) {
            exerciseSettings[.none] = noneSettings
        }
    }
}
