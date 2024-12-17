import UIKit

class StatisticsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    // MARK: - UI Elements
    let tableView = UITableView()
    var datePicker: UIDatePicker!
    var allExerciseRecords: [[String: Any]] = [] // 전체 기록
    var filteredRecords: [[String: Any]] = []   // 필터링된 기록
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "운동 기록"
        view.backgroundColor = .systemBackground
        setupDatePicker()
        setupTableView()
        loadExerciseRecords()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadExerciseRecords()
        filterRecords(by: datePicker.date)
    }
    
    // MARK: - 데이터 불러오기 및 필터링
    func loadExerciseRecords() {
        allExerciseRecords = UserDefaults.standard.array(forKey: "exerciseSummaries") as? [[String: Any]] ?? []
    }
    
    func filterRecords(by date: Date) {
        let calendar = Calendar.current
        filteredRecords = allExerciseRecords.filter { record in
            if let recordDate = record["date"] as? Date {
                return calendar.isDate(recordDate, inSameDayAs: date)
            }
            return false
        }
        
        // 최신 기록이 위로 올라오도록 내림차순 정렬
        filteredRecords.sort {
            guard let date1 = $0["date"] as? Date, let date2 = $1["date"] as? Date else { return false }
            return date1 > date2
        }
        
        // 기록이 없을 때 배경뷰 설정
        if filteredRecords.isEmpty {
            let noDataLabel = UILabel()
            noDataLabel.text = "기록 없음"
            noDataLabel.textColor = .gray
            noDataLabel.textAlignment = .center
            noDataLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
            tableView.backgroundView = noDataLabel
        } else {
            tableView.backgroundView = nil
        }
        tableView.reloadData()
    }
    
    // MARK: - UI 설정
    func setupDatePicker() {
        datePicker = UIDatePicker()
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .inline
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        datePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
        view.addSubview(datePicker)
        
        NSLayoutConstraint.activate([
            datePicker.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            datePicker.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            datePicker.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ExerciseCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: datePicker.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor) // Safe Area를 기준으로
        ])
    }
    
    @objc func dateChanged() {
        filterRecords(by: datePicker.date)
    }
    
    // MARK: - TableView DataSource & Delegate
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredRecords.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ExerciseCell", for: indexPath)
        let record = filteredRecords[indexPath.row]
        
        // 운동 정보
        let exerciseType = record["exerciseType"] as? String ?? "알 수 없음"
        let reps = record["reps"] as? Int ?? 0
        
        // 종료 시간 포맷
        let exerciseEndDate = record["date"] as? Date ?? Date()
        let formattedTime = formatTime(exerciseEndDate)
        
        // 셀 텍스트 설정
        cell.textLabel?.text = "\(exerciseType): \(reps)회 / \(formattedTime)"
        cell.textLabel?.textColor = .label
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let record = filteredRecords[indexPath.row]
        showExerciseSummaryModal(record: record)
    }
    
    // MARK: - 운동 요약 모달
    func showExerciseSummaryModal(record: [String: Any]) {
        let exerciseName = record["exerciseType"] as? String ?? "N/A"
        let totalSets = "\(record["sets"] as? Int ?? 0)세트"
        let totalReps = "\(record["reps"] as? Int ?? 0)회"
        let totalDuration = "\(formatDuration(record["duration"] as? Double ?? 0))"
        let averageSpeed = String(format: "%.1f초", record["averageSpeed"] as? Double ?? 0.0)
        let totalCalories = String(format: "%.2f kcal", record["calories"] as? Double ?? 0.0)
        
        let exerciseEndDate = record["date"] as? Date ?? Date()
        let formattedTime = formatTime(exerciseEndDate)
        
        // 요약 항목
        let items = [
            ("figure.walk", "운동 종류", exerciseName),
            ("checkmark", "반복 횟수", totalReps),
            ("checkmark.seal", "세트수", totalSets),
            ("clock", "지속 시간", totalDuration),
            ("bolt", "회당 평균 속도", averageSpeed),
            ("flame", "소모 칼로리", totalCalories)
        ]
        
        // 모달 뷰컨트롤러 생성
        let summaryVC = UIViewController()
        summaryVC.modalPresentationStyle = .pageSheet
        summaryVC.view.backgroundColor = .systemBackground
        
        if let sheet = summaryVC.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        
        // 헤더: "운동 요약" 타이틀
        let headerLabel = UILabel()
        headerLabel.text = "운동 요약"
        headerLabel.font = UIFont.boldSystemFont(ofSize: 24)
        headerLabel.textAlignment = .center
        headerLabel.textColor = .label
        
        let timeLabel = UILabel()
        timeLabel.text = "오늘 \(formattedTime)"
        timeLabel.font = UIFont.systemFont(ofSize: 16)
        timeLabel.textAlignment = .center
        timeLabel.textColor = .systemGray
        
        let headerStackView = UIStackView(arrangedSubviews: [headerLabel, timeLabel])
        headerStackView.axis = .vertical
        headerStackView.alignment = .center
        headerStackView.spacing = 5
        headerStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // 요약 스택뷰
        let summaryStackView = UIStackView()
        summaryStackView.axis = .vertical
        summaryStackView.spacing = 15
        summaryStackView.translatesAutoresizingMaskIntoConstraints = false
        
        for (iconName, title, value) in items {
            let itemStackView = UIStackView()
            itemStackView.axis = .horizontal
            itemStackView.spacing = 10
            
            let iconImageView = UIImageView(image: UIImage(systemName: iconName))
            iconImageView.tintColor = .systemGreen
            iconImageView.translatesAutoresizingMaskIntoConstraints = false
            iconImageView.widthAnchor.constraint(equalToConstant: 24).isActive = true
            iconImageView.heightAnchor.constraint(equalToConstant: 24).isActive = true
            
            let titleLabel = UILabel()
            titleLabel.text = title
            titleLabel.textColor = .gray
            titleLabel.font = UIFont.systemFont(ofSize: 16)
            
            let valueLabel = UILabel()
            valueLabel.text = value
            valueLabel.font = UIFont.boldSystemFont(ofSize: 16)
            valueLabel.textAlignment = .right
            
            itemStackView.addArrangedSubview(iconImageView)
            itemStackView.addArrangedSubview(titleLabel)
            itemStackView.addArrangedSubview(valueLabel)
            summaryStackView.addArrangedSubview(itemStackView)
        }
        
        // 확인 버튼
        let confirmButton = UIButton(type: .system)
        confirmButton.setTitle("확인", for: .normal)
        confirmButton.backgroundColor = .systemGreen
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.layer.cornerRadius = 10
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        confirmButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        confirmButton.addTarget(self, action: #selector(dismissModal), for: .touchUpInside)
        
        let mainStackView = UIStackView(arrangedSubviews: [headerStackView, summaryStackView, confirmButton])
        mainStackView.axis = .vertical
        mainStackView.spacing = 20
        mainStackView.alignment = .fill
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        
        summaryVC.view.addSubview(mainStackView)
        
        NSLayoutConstraint.activate([
            mainStackView.leadingAnchor.constraint(equalTo: summaryVC.view.leadingAnchor, constant: 20),
            mainStackView.trailingAnchor.constraint(equalTo: summaryVC.view.trailingAnchor, constant: -20),
            mainStackView.centerYAnchor.constraint(equalTo: summaryVC.view.centerYAnchor)
        ])
        
        present(summaryVC, animated: true)
    }
    
    @objc func dismissModal() {
        dismiss(animated: true)
    }
    
    // MARK: - 시간 포맷 함수
    func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes)분 \(seconds)초"
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm" // "오전/오후 h:mm" 형식
        return formatter.string(from: date)
    }
}
