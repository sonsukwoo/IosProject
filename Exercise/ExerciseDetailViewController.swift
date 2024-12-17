import UIKit

class ExerciseDetailViewController: UIViewController {
    
    // MARK: - 프로퍼티
    var record: [String: Any]
    
    // UI Elements
    let summaryLabel = UILabel()
    
    // MARK: - 초기화
    init(record: [String: Any]) {
        self.record = record
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "운동 요약"
        setupUI()
    }
    
    // MARK: - UI 설정
    func setupUI() {
        summaryLabel.text = createSummaryText()
        summaryLabel.numberOfLines = 0
        summaryLabel.textAlignment = .center
        summaryLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        summaryLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(summaryLabel)
        NSLayoutConstraint.activate([
            summaryLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            summaryLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            summaryLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            summaryLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    func createSummaryText() -> String {
        let exerciseType = record["exerciseType"] as? String ?? "알 수 없음"
        let sets = record["sets"] as? Int ?? 0
        let reps = record["reps"] as? Int ?? 0
        let calories = record["calories"] as? Double ?? 0.0
        let duration = record["duration"] as? Double ?? 0.0
        
        return """
        운동 종류: \(exerciseType)
        총 세트 수: \(sets)
        총 반복 횟수: \(reps)
        소모 칼로리: \(String(format: "%.2f", calories)) kcal
        운동 시간: \(Int(duration / 60))분 \(Int(duration) % 60)초
        """
    }
}
