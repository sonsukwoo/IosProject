import UIKit  //설정창

class SettingsViewController: UIViewController {
    
    // MARK: - 상단 안내
    let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "신체 스펙 설정"
        label.font = UIFont.boldSystemFont(ofSize: 24)
        label.textAlignment = .center
        return label
    }()
    
    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.text = """
        해당 정보는 칼로리 소모 데이터를
        보다 정확하게 제공하기 위해서만 사용되고 있습니다.
        
        *저장 버튼을 눌러야 해당 값들이 저장됩니다.
        """
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .systemGray
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()
    
    // MARK: - 카드 컨테이너 (라운드 16, 배경색 변경)
    let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1)
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        return view
    }()

    
    // MARK: - 항목: 성별, 나이, 신장, 체중
    let genderRow = UIControl()
    let genderLeftLabel = UILabel()
    let genderRightLabel = UILabel()
    
    let ageRow = UIControl()
    let ageLeftLabel = UILabel()
    let ageRightLabel = UILabel()
    
    let heightRow = UIControl()
    let heightLeftLabel = UILabel()
    let heightRightLabel = UILabel()
    
    let weightRow = UIControl()
    let weightLeftLabel = UILabel()
    let weightRightLabel = UILabel()
    
    // MARK: - 저장 버튼
    let saveButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("저장", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.layer.cornerRadius = 8
        return button
    }()
    
    // MARK: - 진동 스위치 (저장 버튼 아래 추가)
    let vibrationLabel: UILabel = {
        let label = UILabel()
        label.text = "카운트 진동 피드백"
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let vibrationSwitch: UISwitch = {
        let sw = UISwitch()
        sw.translatesAutoresizingMaskIntoConstraints = false
        sw.onTintColor = .systemBlue
        return sw
    }()
    
    // MARK: - Picker 관련
    enum PickerType {
        case gender, age, height, weight
    }
    
    let pickerContainerView = UIView()
    let pickerView = UIPickerView()
    var currentPickerType: PickerType?
    
    // 피커 옵션 배열 수정:
    let genderOptions = ["설정 안됨", "남성", "여성"]
    let ageOptions = Array(0...100).map { "\($0)" }         // "0" ~ "100"
    let heightOptions = Array(0...250).map { "\($0)cm" }      // "0cm" ~ "250cm"
    let weightOptions = Array(0...150).map { "\($0)kg" }      // "0kg" ~ "150kg"
    
    // 툴바 + 피커 실제 높이
    var totalPickerHeight: CGFloat = 0
    
    // MARK: - 피커 완료 시 저장할 인덱스
    var selectedGenderIndex: Int? = nil
    var selectedAgeIndex: Int? = nil
    var selectedHeightIndex: Int? = nil
    var selectedWeightIndex: Int? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 다크 모드 강제
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = .black
        
        setupLayout()
        setupCardRows()
        setupPickerContainer()
        loadUserInfo()
        setupGestureToDismissPicker()
        
        // 진동 스위치 상태 불러오기 (저장된 값이 없으면 기본 true)
        if let savedVibration = UserDefaults.standard.value(forKey: "isVibrationEnabled") as? Bool {
            vibrationSwitch.isOn = savedVibration
        } else {
            vibrationSwitch.isOn = true
        }
        // 스위치 상태 변경 시 액션 추가
        vibrationSwitch.addTarget(self, action: #selector(vibrationSwitchChanged(_:)), for: .valueChanged)
    }
    
    // MARK: - Layout
    func setupLayout() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(titleLabel)
        view.addSubview(descriptionLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
        
        // 카드
        cardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardView)
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 16),
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
        
        // 저장 버튼
        saveButton.addTarget(self, action: #selector(saveUserInfo), for: .touchUpInside)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(saveButton)
        
        NSLayoutConstraint.activate([
            saveButton.topAnchor.constraint(equalTo: cardView.bottomAnchor, constant: 15),
            saveButton.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            saveButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            saveButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        // 진동 스위치와 라벨 (저장 버튼 밑에 추가)
        view.addSubview(vibrationLabel)
        view.addSubview(vibrationSwitch)
        
        NSLayoutConstraint.activate([
            vibrationLabel.topAnchor.constraint(equalTo: saveButton.bottomAnchor, constant: 16),
            vibrationLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            
            vibrationSwitch.centerYAnchor.constraint(equalTo: vibrationLabel.centerYAnchor),
            vibrationSwitch.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16)
        ])
    }
    
    // MARK: - 카드 내부 항목
    func setupCardRows() {
        func setupRowStyle(_ row: UIControl,
                           leftLabel: UILabel,
                           rightLabel: UILabel,
                           title: String,
                           addDivider: Bool = true) {
            row.translatesAutoresizingMaskIntoConstraints = false
            row.backgroundColor = .clear
            
            leftLabel.text = title
            leftLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
            leftLabel.textColor = .lightGray
            leftLabel.translatesAutoresizingMaskIntoConstraints = false
            
            rightLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
            rightLabel.textColor = .systemBlue
            rightLabel.textAlignment = .right
            rightLabel.translatesAutoresizingMaskIntoConstraints = false
            
            row.addSubview(leftLabel)
            row.addSubview(rightLabel)
            
            NSLayoutConstraint.activate([
                leftLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
                leftLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                rightLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
                rightLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                row.heightAnchor.constraint(equalToConstant: 40)
            ])
            
            if addDivider {
                addBottomBorder(to: row)
            }
        }
        
        // 성별
        setupRowStyle(genderRow, leftLabel: genderLeftLabel, rightLabel: genderRightLabel, title: "성별")
        genderRow.addTarget(self, action: #selector(genderRowTapped), for: .touchUpInside)
        
        // 나이
        setupRowStyle(ageRow, leftLabel: ageLeftLabel, rightLabel: ageRightLabel, title: "나이")
        ageRow.addTarget(self, action: #selector(ageRowTapped), for: .touchUpInside)
        
        // 신장
        setupRowStyle(heightRow, leftLabel: heightLeftLabel, rightLabel: heightRightLabel, title: "신장")
        heightRow.addTarget(self, action: #selector(heightRowTapped), for: .touchUpInside)
        
        // 체중 (마지막 구분선 제거)
        setupRowStyle(weightRow, leftLabel: weightLeftLabel, rightLabel: weightRightLabel, title: "체중", addDivider: false)
        weightRow.addTarget(self, action: #selector(weightRowTapped), for: .touchUpInside)
        
        let stackView = UIStackView(arrangedSubviews: [genderRow, ageRow, heightRow, weightRow])
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: cardView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor)
        ])
    }
    
    func addBottomBorder(to row: UIView) {
        let divider = UIView()
        divider.backgroundColor = UIColor.lightGray.withAlphaComponent(0.3)
        divider.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(divider)
        
        NSLayoutConstraint.activate([
            divider.heightAnchor.constraint(equalToConstant: 1),
            divider.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            divider.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            divider.bottomAnchor.constraint(equalTo: row.bottomAnchor)
        ])
    }
    
    // MARK: - Picker 설정
    func setupPickerContainer() {
        pickerContainerView.backgroundColor = .systemBackground
        pickerContainerView.frame = CGRect(x: 0, y: view.frame.height,
                                           width: view.frame.width, height: 300)
        
        let toolbar = UIToolbar()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        let flexible = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneBtn = UIBarButtonItem(title: "완료", style: .done, target: self, action: #selector(donePicker))
        toolbar.setItems([flexible, doneBtn], animated: false)
        
        pickerView.translatesAutoresizingMaskIntoConstraints = false
        pickerView.delegate = self
        pickerView.dataSource = self
        
        pickerContainerView.addSubview(toolbar)
        pickerContainerView.addSubview(pickerView)
        view.addSubview(pickerContainerView)
        
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: pickerContainerView.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: pickerContainerView.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: pickerContainerView.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 44),
            
            pickerView.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            pickerView.leadingAnchor.constraint(equalTo: pickerContainerView.leadingAnchor),
            pickerView.trailingAnchor.constraint(equalTo: pickerContainerView.trailingAnchor),
            pickerView.bottomAnchor.constraint(equalTo: pickerContainerView.bottomAnchor)
        ])
        
        pickerContainerView.layoutIfNeeded()
        let totalHeight = toolbar.frame.height + pickerView.frame.height
        totalPickerHeight = totalHeight
        
        pickerContainerView.frame = CGRect(x: 0,
                                           y: view.frame.height,
                                           width: view.frame.width,
                                           height: totalHeight)
    }
    
    // MARK: - Row Tap (피커 열기)
    @objc func genderRowTapped() {
        currentPickerType = .gender
        highlightRow(genderRow)
        
        pickerView.reloadAllComponents()
        let currentIndex: Int
        if let savedIndex = selectedGenderIndex {
            currentIndex = savedIndex
        } else if let genderText = genderRightLabel.text,
                  let found = genderOptions.firstIndex(of: genderText) {
            currentIndex = found
        } else {
            currentIndex = 0
        }
        pickerView.selectRow(currentIndex, inComponent: 0, animated: false)
        showPickerContainer()
    }
    
    @objc func ageRowTapped() {
        currentPickerType = .age
        highlightRow(ageRow)
        
        pickerView.reloadAllComponents()
        let currentIndex: Int
        if let savedIndex = selectedAgeIndex {
            currentIndex = savedIndex
        } else if let ageText = ageRightLabel.text,
                  let found = ageOptions.firstIndex(of: ageText) {
            currentIndex = found
        } else {
            currentIndex = 0
        }
        pickerView.selectRow(currentIndex, inComponent: 0, animated: false)
        showPickerContainer()
    }
    
    @objc func heightRowTapped() {
        currentPickerType = .height
        highlightRow(heightRow)
        
        pickerView.reloadAllComponents()
        let currentIndex: Int
        if let savedIndex = selectedHeightIndex {
            currentIndex = savedIndex
        } else if let heightText = heightRightLabel.text,
                  let found = heightOptions.firstIndex(of: heightText) {
            currentIndex = found
        } else {
            currentIndex = 0
        }
        pickerView.selectRow(currentIndex, inComponent: 0, animated: false)
        showPickerContainer()
    }
    
    @objc func weightRowTapped() {
        currentPickerType = .weight
        highlightRow(weightRow)
        
        pickerView.reloadAllComponents()
        let currentIndex: Int
        if let savedIndex = selectedWeightIndex {
            currentIndex = savedIndex
        } else if let weightText = weightRightLabel.text,
                  let found = weightOptions.firstIndex(of: weightText) {
            currentIndex = found
        } else {
            currentIndex = 0
        }
        pickerView.selectRow(currentIndex, inComponent: 0, animated: false)
        showPickerContainer()
    }
    
    func highlightRow(_ row: UIControl) {
        resetRowHighlight()
        row.backgroundColor = UIColor(white: 1.0, alpha: 0.15)
        row.layer.cornerRadius = 0
        row.clipsToBounds = true
    }
    
    func resetRowHighlight() {
        for r in [genderRow, ageRow, heightRow, weightRow] {
            r.backgroundColor = .clear
            r.layer.cornerRadius = 0
        }
    }
    
    // MARK: - Picker Show / Hide
    func showPickerContainer() {
        let offset: CGFloat = 40
        UIView.animate(withDuration: 0.3) {
            self.pickerContainerView.frame.origin.y =
                self.view.frame.height - self.totalPickerHeight - offset
        }
    }
    
    func hidePickerContainer() {
        UIView.animate(withDuration: 0.3) {
            self.pickerContainerView.frame.origin.y = self.view.frame.height
        }
    }
    
    // MARK: - “완료” 버튼 동작 (Picker 선택 완료)
    @objc func donePicker() {
        guard let type = currentPickerType else { return }
        let row = pickerView.selectedRow(inComponent: 0)
        
        switch type {
        case .gender:
            selectedGenderIndex = row
            genderRightLabel.text = genderOptions[row]
        case .age:
            selectedAgeIndex = row
            ageRightLabel.text = ageOptions[row]
        case .height:
            selectedHeightIndex = row
            heightRightLabel.text = heightOptions[row]
        case .weight:
            selectedWeightIndex = row
            weightRightLabel.text = weightOptions[row]
        }
        
        resetRowHighlight()
        hidePickerContainer()
    }
    
    // MARK: - 저장 버튼 동작 (UserDefaults에 최종 저장)
    @objc func saveUserInfo() {
        if let genderText = genderRightLabel.text,
           let genderIndex = genderOptions.firstIndex(of: genderText) {
            UserDefaults.standard.set(genderIndex, forKey: "gender")
        }
        
        if let ageText = ageRightLabel.text,
           let ageValue = Int(ageText) {
            UserDefaults.standard.set(ageValue, forKey: "age")
        }
        
        if let heightText = heightRightLabel.text {
            let numeric = heightText.replacingOccurrences(of: "cm", with: "")
            if let heightValue = Int(numeric) {
                UserDefaults.standard.set(heightValue, forKey: "height")
            }
        }
        
        if let weightText = weightRightLabel.text {
            let numeric = weightText.replacingOccurrences(of: "kg", with: "")
            if let weightValue = Int(numeric) {
                UserDefaults.standard.set(weightValue, forKey: "weight")
            }
        }
        
        let alert = UIAlertController(title: "저장 완료", message: "사용자 정보가 저장되었습니다.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default, handler: nil))
        present(alert, animated: true)
    }
    
    func loadUserInfo() {
        let gIdx = UserDefaults.standard.integer(forKey: "gender")
        if gIdx < genderOptions.count {
            genderRightLabel.text = genderOptions[gIdx]
        } else {
            genderRightLabel.text = "설정 안됨"
        }
        
        let ageVal = UserDefaults.standard.integer(forKey: "age")
        ageRightLabel.text = "\(ageVal)"
        
        let hVal = UserDefaults.standard.integer(forKey: "height")
        heightRightLabel.text = "\(hVal)cm"
        
        let wVal = UserDefaults.standard.integer(forKey: "weight")
        weightRightLabel.text = "\(wVal)kg"
    }
    
    // MARK: - 탭 시 피커 숨김
    func setupGestureToDismissPicker() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapOutsidePicker))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc func tapOutsidePicker(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        if !pickerContainerView.frame.contains(location) {
            resetRowHighlight()
            hidePickerContainer()
        }
    }
    
    // MARK: - 진동 스위치 변경 액션
    @objc func vibrationSwitchChanged(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: "isVibrationEnabled")
    }
}

// MARK: - UIPickerViewDataSource & Delegate

extension SettingsViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
    
    func pickerView(_ pickerView: UIPickerView,
                    numberOfRowsInComponent component: Int) -> Int {
        switch currentPickerType {
        case .gender:   return genderOptions.count
        case .age:      return ageOptions.count
        case .height:   return heightOptions.count
        case .weight:   return weightOptions.count
        case .none:     return 0
        }
    }
    
    func pickerView(_ pickerView: UIPickerView,
                    attributedTitleForRow row: Int,
                    forComponent component: Int) -> NSAttributedString? {
        let textColor: UIColor = .white
        let text: String
        switch currentPickerType {
        case .gender:   text = genderOptions[row]
        case .age:      text = ageOptions[row]
        case .height:   text = heightOptions[row]
        case .weight:   text = weightOptions[row]
        case .none:     text = ""
        }
        return NSAttributedString(string: text, attributes: [.foregroundColor: textColor])
    }
}
