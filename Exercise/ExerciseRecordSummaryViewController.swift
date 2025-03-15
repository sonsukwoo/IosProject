//
//  ExerciseRecordSummaryViewController.swift
//  YourAppName
//

import UIKit

class ExerciseRecordSummaryViewController: UIViewController {
    
    // MARK: - Public Properties
    /// 운동 기록 정보를 담은 딕셔너리 (키 예시: "exerciseType", "sets", "reps", "duration", "averageSpeed", "calories", "date")
    var record: [String: Any]?
    
    // MARK: - 생명주기 메서드
    override func viewDidLoad() {
        super.viewDidLoad()
        
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            if #available(iOS 16.0, *) {
                if UIScreen.main.bounds.height <= 667 {
                    // 작은 화면: iPhone SE 등 - 모달 높이를 650포인트로 고정
                    let customDetent = UISheetPresentationController.Detent.custom(identifier: .init("custom650")) { _ in
                        return 450
                    }
                    sheet.detents = [customDetent]
                    sheet.selectedDetentIdentifier = customDetent.identifier
                } else {
                    // 큰 화면: large 옵션 없이 medium 만 제공
                    sheet.detents = [.medium()]
                    sheet.selectedDetentIdentifier = .medium
                }
            } else {
                // iOS 16 미만: Custom Detent 기능이 없으므로, 모든 기기에서 medium 만 사용
                sheet.detents = [.medium()]
                sheet.selectedDetentIdentifier = .large
            }
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        
        view.backgroundColor = UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1)
        setupUI()
    }
    // MARK: - UI 구성
    private func setupUI() {
        guard let record = record else { return }
        
        // 기록 정보 추출
        let exerciseName = record["exerciseType"] as? String ?? "N/A"
        let totalSets = "\(record["sets"] as? Int ?? 0)세트"
        let totalReps = "\(record["reps"] as? Int ?? 0)회"
        let totalDurationSeconds = record["duration"] as? Double ?? 0.0
        let totalDuration = formatDuration(totalDurationSeconds)
        let averageSpeed = String(format: "%.1f초", record["averageSpeed"] as? Double ?? 0.0)
        let totalCalories = String(format: "%.2f kcal", record["calories"] as? Double ?? 0.0)
        let endDate = record["date"] as? Date ?? Date()
        let formattedFullDate = formatFullDate(endDate)
        
        // 운동 종류에 따른 아이콘 및 색상 설정
        var exerciseIconName = "figure.walk"
        var iconTintColor = UIColor.systemGreen
        switch exerciseName {
        case "스쿼트":
            exerciseIconName = "figure.cross.training"
            iconTintColor = .systemGreen
        case "푸쉬업":
            exerciseIconName = "figure.wrestling"
            iconTintColor = .systemBlue
        case "턱걸이":
            exerciseIconName = "figure.play"
            iconTintColor = .systemPurple
        default:
            exerciseIconName = "figure.walk"
            iconTintColor = .systemGreen
        }
        
        // 각 행에 표시할 아이템 (아이콘 이름, 타이틀, 값)
        let items: [(String, String, String)] = [
            (exerciseIconName, "운동 종류", exerciseName),
            ("checkmark", "반복 횟수", totalReps),
            ("checkmark.seal", "세트수", totalSets),
            ("clock", "지속 시간", totalDuration),
            ("bolt", "회당 평균 속도", averageSpeed),
            ("flame", "소모 칼로리", totalCalories)
        ]
        
        // 헤더: "운동 기록" 제목과 날짜
        let headerLabel = UILabel()
        headerLabel.text = "운동 기록"
        headerLabel.font = UIFont.boldSystemFont(ofSize: 28)
        headerLabel.textAlignment = .center
        headerLabel.textColor = .white
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let timeLabel = UILabel()
        timeLabel.text = formattedFullDate
        timeLabel.font = UIFont.systemFont(ofSize: 16)
        timeLabel.textAlignment = .center
        timeLabel.textColor = .lightGray
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let headerStack = UIStackView(arrangedSubviews: [headerLabel, timeLabel])
        headerStack.axis = .vertical
        headerStack.alignment = .center
        headerStack.spacing = 10
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        
        // 요약 정보 스택 구성
        let summaryStack = UIStackView()
        summaryStack.axis = .vertical
        summaryStack.spacing = 20
        summaryStack.translatesAutoresizingMaskIntoConstraints = false
        
        for (iconName, title, value) in items {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 15
            rowStack.translatesAutoresizingMaskIntoConstraints = false
            
            let iconView = UIImageView()
            if let img = UIImage(systemName: iconName)?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)) {
                iconView.image = img
            } else {
                iconView.image = UIImage(systemName: "figure.walk")
            }
            iconView.tintColor = iconTintColor
            iconView.contentMode = .scaleAspectFit
            iconView.translatesAutoresizingMaskIntoConstraints = false
            iconView.widthAnchor.constraint(equalToConstant: 20).isActive = true
            iconView.heightAnchor.constraint(equalToConstant: 20).isActive = true
            
            let titleLabel = UILabel()
            titleLabel.text = title
            titleLabel.textColor = .lightGray
            titleLabel.font = UIFont.systemFont(ofSize: 18)
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            
            let valueLabel = UILabel()
            valueLabel.text = value
            valueLabel.font = UIFont.boldSystemFont(ofSize: 18)
            valueLabel.textAlignment = .right
            valueLabel.textColor = .white
            valueLabel.translatesAutoresizingMaskIntoConstraints = false
            valueLabel.widthAnchor.constraint(equalToConstant: 150).isActive = true
            
            rowStack.addArrangedSubview(iconView)
            rowStack.addArrangedSubview(titleLabel)
            rowStack.addArrangedSubview(valueLabel)
            
            summaryStack.addArrangedSubview(rowStack)
        }
        
        // 확인 버튼
        let confirmButton = UIButton(type: .system)
        confirmButton.setTitle("확인", for: .normal)
        confirmButton.backgroundColor = .systemGreen
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        confirmButton.layer.cornerRadius = 10
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        confirmButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        confirmButton.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)
        
        // 메인 스택뷰에 모든 구성요소 추가
        let mainStack = UIStackView(arrangedSubviews: [headerStack, summaryStack, confirmButton])
        mainStack.axis = .vertical
        mainStack.spacing = 30
        mainStack.alignment = .fill
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(mainStack)
        
        // 오토레이아웃
        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            mainStack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    // MARK: - 액션 메서드
    @objc private func confirmButtonTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - 헬퍼 메서드
    private func formatDuration(_ durationSeconds: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: durationSeconds) ?? "0:00:00"
    }
    
    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일 HH:mm"
        return formatter.string(from: date)
    }
}
