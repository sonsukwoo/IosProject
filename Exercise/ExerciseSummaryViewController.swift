import UIKit

class ExerciseSummaryViewController: UIViewController {
    
    // MARK: - Properties
    var caloriesBurned: Double = 0.0 // 소모한 칼로리
    var completedSets: Int = 0       // 완료된 세트 수
    var totalRepetitions: Int = 0    // 총 반복 횟수
    var exerciseDuration: Int = 0    // 운동 시간 (분)
    
    var exerciseSummaryText: String = "" {
        didSet {
            saveSummaryToUserDefaults()
        }
    }
    
    // MARK: - UI Elements
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "운동 요약"
        label.font = UIFont.boldSystemFont(ofSize: 24)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let summaryLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.numberOfLines = 0 // 여러 줄 표시 가능
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("완료", for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.backgroundColor = UIColor.systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateSummaryLabel()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor.systemGroupedBackground
        
        // Add subviews
        view.addSubview(titleLabel)
        view.addSubview(summaryLabel)
        view.addSubview(closeButton)
        
        // Add constraints
        NSLayoutConstraint.activate([
            // Title Label Constraints
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            // Summary Label Constraints
            summaryLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            summaryLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            summaryLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            // Close Button Constraints
            closeButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            closeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            closeButton.heightAnchor.constraint(equalToConstant: 50),
            closeButton.widthAnchor.constraint(equalToConstant: 120)
        ])
    }
    
    // MARK: - Update Summary
    private func updateSummaryLabel() {
        // 운동 요약 텍스트 생성
        exerciseSummaryText = """
        소모한 칼로리: \(String(format: "%.2f", caloriesBurned)) kcal
        완료된 세트: \(completedSets) 세트
        반복 횟수: \(totalRepetitions) 회
        운동 시간: \(exerciseDuration) 분
        """
        summaryLabel.text = exerciseSummaryText
    }
    
    // MARK: - UserDefaults Methods
    private func saveSummaryToUserDefaults() {
        UserDefaults.standard.set(exerciseSummaryText, forKey: "ExerciseSummaryText")
    }
    
    private func loadSummaryFromUserDefaults() {
        if let savedSummary = UserDefaults.standard.string(forKey: "ExerciseSummaryText") {
            exerciseSummaryText = savedSummary
            summaryLabel.text = exerciseSummaryText
        }
    }
    
    // MARK: - Actions
    @objc private func closeButtonTapped() {
        // 모든 모달을 닫고 초기 화면으로 돌아가기
        if let presentingVC = self.presentingViewController {
            presentingVC.dismiss(animated: true) {
                // TabBarController의 첫 번째 탭으로 이동
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let sceneDelegate = windowScene.delegate as? SceneDelegate,
                   let tabBarController = sceneDelegate.window?.rootViewController as? UITabBarController {
                    
                    // 첫 번째 탭(초기 화면)으로 이동
                    tabBarController.selectedIndex = 0
                }
            }
        }
    }
}
