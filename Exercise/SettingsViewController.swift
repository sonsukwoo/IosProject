import UIKit

class SettingsViewController: UIViewController {
    
    // UI Elements
    let genderLabel = UILabel()
    let genderSegmentedControl = UISegmentedControl(items: ["남성", "여성"])
    
    let ageLabel = UILabel()
    let ageTextField = UITextField()
    
    let heightLabel = UILabel()
    let heightTextField = UITextField()
    
    let weightLabel = UILabel()
    let weightTextField = UITextField()
    
    let saveButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        loadUserInfo()
        setupGestureToDismissKeyboard()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateBackgroundColor()
    }
    
    func setupUI() {
        updateBackgroundColor()
        
        // Gender Selection
        genderLabel.text = "성별"
        genderLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        genderSegmentedControl.selectedSegmentIndex = 0
        
        // Age Input
        ageLabel.text = "나이"
        ageLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        ageTextField.placeholder = "나이를 입력하세요"
        ageTextField.borderStyle = .roundedRect
        ageTextField.keyboardType = .numberPad
        
        // Height Input
        heightLabel.text = "키 (cm)"
        heightLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        heightTextField.placeholder = "키를 입력하세요"
        heightTextField.borderStyle = .roundedRect
        heightTextField.keyboardType = .numberPad
        
        // Weight Input
        weightLabel.text = "몸무게 (kg)"
        weightLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        weightTextField.placeholder = "몸무게를 입력하세요"
        weightTextField.borderStyle = .roundedRect
        weightTextField.keyboardType = .numberPad
        
        // Save Button
        saveButton.setTitle("저장", for: .normal)
        saveButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        saveButton.backgroundColor = .systemBlue
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = 8
        saveButton.addTarget(self, action: #selector(saveUserInfo), for: .touchUpInside)
        
        // Stack View
        let stackView = UIStackView(arrangedSubviews: [
            genderLabel, genderSegmentedControl,
            ageLabel, ageTextField,
            heightLabel, heightTextField,
            weightLabel, weightTextField,
            saveButton
        ])
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            saveButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    func updateBackgroundColor() {
        if traitCollection.userInterfaceStyle == .dark {
            view.backgroundColor = .black
        } else {
            view.backgroundColor = .white
        }
    }
    
    @objc func saveUserInfo() {
        // 문자열을 숫자로 변환 후 저장
        let ageText = ageTextField.text ?? ""
        let heightText = heightTextField.text ?? ""
        let weightText = weightTextField.text ?? ""
        let genderIndex = genderSegmentedControl.selectedSegmentIndex

        if let ageValue = Int(ageText) {
            UserDefaults.standard.set(ageValue, forKey: "age")
        }
        if let heightValue = Double(heightText) {
            UserDefaults.standard.set(heightValue, forKey: "height")
        }
        if let weightValue = Double(weightText) {
            UserDefaults.standard.set(weightValue, forKey: "weight")
        }
        UserDefaults.standard.set(genderIndex, forKey: "gender")

        let alert = UIAlertController(title: "저장 완료", message: "사용자 정보가 저장되었습니다.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    func loadUserInfo() {
        let age = UserDefaults.standard.integer(forKey: "age")
        if age > 0 {
            ageTextField.text = "\(age)"
        }
        
        let height = UserDefaults.standard.double(forKey: "height")
        if height > 0 {
            heightTextField.text = "\(height)"
        }
        
        let weight = UserDefaults.standard.double(forKey: "weight")
        if weight > 0 {
            weightTextField.text = "\(weight)"
        }
        
        genderSegmentedControl.selectedSegmentIndex = UserDefaults.standard.integer(forKey: "gender")
    }
    
    func setupGestureToDismissKeyboard() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}
