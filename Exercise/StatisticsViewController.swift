import UIKit

class StatisticsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    // MARK: - UI Elements
    let tableView = UITableView()
    var datePicker: UIDatePicker!
    var allExerciseRecords: [[String: Any]] = [] // 전체 기록
    var filteredRecords: [[String: Any]] = []   // 필터링된 기록
    
    // Containers for datePicker and tableView
    let datePickerContainer = UIView()
    let tableViewContainer = UIView()
    
    // Record label and sort button as properties
    let recordLabel = UILabel()
    let sortButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "운동 기록"
        view.backgroundColor = UIColor.black // 전체 배경을 더욱 어둡게 설정
        setupDatePickerContainer()
        setupRecordLabelAndSortButton()
        setupTableViewContainer()
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
        
        // 최신 기록이 위로 올라오도록 정렬
        filteredRecords.sort {
            guard let date1 = $0["date"] as? Date, let date2 = $1["date"] as? Date else { return false }
            return isDescendingOrder ? date1 > date2 : date1 < date2
        }
        
        // 기록이 없을 때 배경뷰 설정
        if filteredRecords.isEmpty {
            let noDataLabel = UILabel()
            noDataLabel.text = "기록 없음"
            noDataLabel.textColor = .lightGray // 어두운 배경에 맞는 색상
            noDataLabel.textAlignment = .center
            noDataLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
            tableView.backgroundView = noDataLabel
        } else {
            tableView.backgroundView = nil
        }
        tableView.reloadData()
    }
    
    // MARK: - UI 설정
    
    func setupDatePickerContainer() {
        // Container 설정
        datePickerContainer.translatesAutoresizingMaskIntoConstraints = false
        datePickerContainer.backgroundColor = UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1) // 매우 어두운 회색
        datePickerContainer.layer.cornerRadius = 12
        datePickerContainer.layer.masksToBounds = true
        view.addSubview(datePickerContainer)
        
        // DatePicker 설정
        datePicker = UIDatePicker()
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .inline
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        datePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
        datePickerContainer.addSubview(datePicker)
        
        // Container의 제약 설정 (기존 코드의 크기 유지)
        NSLayoutConstraint.activate([
            datePickerContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            datePickerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            datePickerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            datePickerContainer.heightAnchor.constraint(equalToConstant: 330),
            
            // DatePicker의 제약 설정 (내부 여백 추가)
            datePicker.topAnchor.constraint(equalTo: datePickerContainer.topAnchor, constant: 10),
            datePicker.bottomAnchor.constraint(equalTo: datePickerContainer.bottomAnchor, constant: -10),
            datePicker.leadingAnchor.constraint(equalTo: datePickerContainer.leadingAnchor, constant: 10),
            datePicker.trailingAnchor.constraint(equalTo: datePickerContainer.trailingAnchor, constant: -10)
        ])
    }
    
    func setupRecordLabelAndSortButton() {
        // "기록" 라벨 설정
        recordLabel.text = "기록"
        recordLabel.font = UIFont.systemFont(ofSize: 13) // 폰트 크기를 더 작게 조정
        recordLabel.textColor = .gray // 회색으로 수정
        recordLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(recordLabel)
        
        // 정렬 토글 버튼 설정
        sortButton.setTitle("내림차순", for: .normal)
        sortButton.setTitleColor(.systemBlue, for: .normal)
        sortButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        sortButton.translatesAutoresizingMaskIntoConstraints = false
        sortButton.addTarget(self, action: #selector(toggleSortOrder), for: .touchUpInside)
        
        // 정렬 버튼에 이미지 추가 (위아래 화살표)
        let sortImage = UIImage(systemName: "arrow.up.arrow.down") // SF Symbol for up/down arrows
        sortButton.setImage(sortImage, for: .normal)
        sortButton.tintColor = .systemBlue
        
        // 이미지와 텍스트의 위치 조정
        sortButton.semanticContentAttribute = .forceRightToLeft
        sortButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: -8)
        
        view.addSubview(sortButton)
        
        // 제약 설정
        NSLayoutConstraint.activate([
            recordLabel.topAnchor.constraint(equalTo: datePickerContainer.bottomAnchor, constant: 20),
            recordLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            sortButton.centerYAnchor.constraint(equalTo: recordLabel.centerYAnchor),
            sortButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    func setupTableViewContainer() {
        // Container 설정
        tableViewContainer.translatesAutoresizingMaskIntoConstraints = false
        tableViewContainer.backgroundColor = UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1) // 매우 어두운 회색
        tableViewContainer.layer.cornerRadius = 12
        tableViewContainer.layer.masksToBounds = true
        view.addSubview(tableViewContainer)
        
        // TableView 설정
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ExerciseCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear // 테이블 뷰 배경 투명하게 설정
        tableView.separatorStyle = .none // 구분선 제거 (필요에 따라 조정 가능)
        tableViewContainer.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableViewContainer.topAnchor.constraint(equalTo: recordLabel.bottomAnchor, constant: 5),
            tableViewContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            tableViewContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            tableViewContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            // TableView의 제약 설정 (내부 여백 추가)
            tableView.topAnchor.constraint(equalTo: tableViewContainer.topAnchor, constant: 10),
            tableView.leadingAnchor.constraint(equalTo: tableViewContainer.leadingAnchor, constant: 10),
            tableView.trailingAnchor.constraint(equalTo: tableViewContainer.trailingAnchor, constant: -10),
            tableView.bottomAnchor.constraint(equalTo: tableViewContainer.bottomAnchor, constant: -10)
        ])
    }
    
    @objc func dateChanged() {
        filterRecords(by: datePicker.date)
    }
    
    // MARK: - 정렬 토글 기능
    var isDescendingOrder = true // 초기값: 내림차순

    @objc func toggleSortOrder() {
        isDescendingOrder.toggle()
        
        // 버튼 텍스트 업데이트
        sortButton.setTitle(isDescendingOrder ? "내림차순" : "오름차순", for: .normal)
        
        // 기록 정렬 방향 변경
        filteredRecords.sort {
            guard let date1 = $0["date"] as? Date, let date2 = $1["date"] as? Date else { return false }
            return isDescendingOrder ? date1 > date2 : date1 < date2
        }
        tableView.reloadData()
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
        cell.textLabel?.textColor = .white // 어두운 배경에 대비되는 색상
        cell.backgroundColor = .clear // 셀 배경 투명하게 설정
        cell.accessoryType = .disclosureIndicator
        
        // 셀에 운동 종류에 따라 아이콘 추가 및 색상 설정
        var exerciseIconName = "figure.walk" // 기본 아이콘
        var iconTintColor: UIColor = .systemGreen // 기본 색상
        
        switch exerciseType {
        case "스쿼트":
            exerciseIconName = "figure.cross.training" // 유효한 SF Symbol 사용
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
        
        // 아이콘 크기 조정 (16pt로 줄임)
        if let image = UIImage(systemName: exerciseIconName)?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)) {
            cell.imageView?.image = image
        } else {
            cell.imageView?.image = UIImage(systemName: "figure.walk") // 기본 아이콘으로 대체
        }
        cell.imageView?.tintColor = iconTintColor // 운동 종류에 따른 색상 설정
        cell.imageView?.contentMode = .scaleAspectFit
        
        // 선택 시 배경색 설정
        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = UIColor.darkGray.withAlphaComponent(0.5)
        cell.selectedBackgroundView = selectedBackgroundView
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let record = filteredRecords[indexPath.row]
        showExerciseSummaryModal(record: record)
    }
    
    // MARK: - TableView Delegate
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "삭제") { (action, view, completionHandler) in
            // 삭제 로직
            self.deleteExerciseRecord(at: indexPath)
            completionHandler(true) // 삭제 완료 후 테이블 뷰 업데이트
        }
        
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction])
        return configuration
    }

    // MARK: - 삭제 기능을 위한 메서드
    func deleteExerciseRecord(at indexPath: IndexPath) {
        // 삭제할 기록 가져오기
        let recordToDelete = filteredRecords[indexPath.row]
        
        // allExerciseRecords에서 해당 기록 삭제
        if let index = allExerciseRecords.firstIndex(where: {
            guard let date1 = $0["date"] as? Date, let date2 = recordToDelete["date"] as? Date,
                  let type1 = $0["exerciseType"] as? String, let type2 = recordToDelete["exerciseType"] as? String
            else { return false }
            return date1 == date2 && type1 == type2
        }) {
            allExerciseRecords.remove(at: index)
        }
        
        // 필터링된 기록에서도 삭제
        filteredRecords.remove(at: indexPath.row)
        
        // 업데이트된 데이터를 UserDefaults에 저장
        UserDefaults.standard.set(allExerciseRecords, forKey: "exerciseSummaries")
        
        // 테이블 뷰 업데이트
        tableView.deleteRows(at: [indexPath], with: .automatic)
        
        // 기록이 없을 때 배경뷰 설정
        if filteredRecords.isEmpty {
            let noDataLabel = UILabel()
            noDataLabel.text = "기록 없음"
            noDataLabel.textColor = .lightGray
            noDataLabel.textAlignment = .center
            noDataLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
            tableView.backgroundView = noDataLabel
        }
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
        
        // 운동 종류에 따른 아이콘 매핑
        let exerciseType = record["exerciseType"] as? String ?? "알 수 없음"
        var exerciseIconName = "figure.walk" // 기본 아이콘
        var iconTintColor: UIColor = .systemGreen // 기본 색상
        
        switch exerciseType {
        case "스쿼트":
            exerciseIconName = "figure.cross.training" // 테이블 뷰 셀과 동일한 아이콘 사용
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
        
        // 요약 항목
        let items = [
            (exerciseIconName, "운동 종류", exerciseName), // 동일한 아이콘 사용
            ("checkmark", "반복 횟수", totalReps),
            ("checkmark.seal", "세트수", totalSets),
            ("clock", "지속 시간", totalDuration),
            ("bolt", "회당 평균 속도", averageSpeed),
            ("flame", "소모 칼로리", totalCalories)
        ]
        
        // 모달 뷰컨트롤러 생성
        let summaryVC = UIViewController()
        summaryVC.modalPresentationStyle = .pageSheet
        summaryVC.view.backgroundColor = UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1) // 매우 어두운 배경
        
        if let sheet = summaryVC.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        
        // 헤더: "운동 요약" 타이틀
        let headerLabel = UILabel()
        headerLabel.text = "운동 요약"
        headerLabel.font = UIFont.boldSystemFont(ofSize: 28) // 폰트 크기 증가
        headerLabel.textAlignment = .center
        headerLabel.textColor = .white // 어두운 배경에 대비되는 색상
        
        let timeLabel = UILabel()
        timeLabel.text = "오늘 \(formattedTime)"
        timeLabel.font = UIFont.systemFont(ofSize: 16) // 폰트 크기 증가
        timeLabel.textAlignment = .center
        timeLabel.textColor = .lightGray // 어두운 배경에 대비되는 색상
        
        let headerStackView = UIStackView(arrangedSubviews: [headerLabel, timeLabel])
        headerStackView.axis = .vertical
        headerStackView.alignment = .center
        headerStackView.spacing = 10 // 간격 증가
        headerStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // 요약 스택뷰
        let summaryStackView = UIStackView()
        summaryStackView.axis = .vertical
        summaryStackView.spacing = 20 // 간격 증가
        summaryStackView.translatesAutoresizingMaskIntoConstraints = false
        
        for (iconName, title, value) in items {
            let itemStackView = UIStackView()
            itemStackView.axis = .horizontal
            itemStackView.spacing = 15 // 간격 증가
            
            let iconImageView = UIImageView()
            if let image = UIImage(systemName: iconName)?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)) { // 포인트 크기 증가
                iconImageView.image = image
            } else {
                iconImageView.image = UIImage(systemName: "figure.walk") // 기본 아이콘으로 대체
            }
            iconImageView.tintColor = iconTintColor // 운동 종류에 따른 색상 설정
            iconImageView.contentMode = .scaleAspectFit
            iconImageView.translatesAutoresizingMaskIntoConstraints = false
            iconImageView.widthAnchor.constraint(equalToConstant: 20).isActive = true // 아이콘 크기 증가
            iconImageView.heightAnchor.constraint(equalToConstant: 20).isActive = true // 아이콘 크기 증가
            
            let titleLabel = UILabel()
            titleLabel.text = title
            titleLabel.textColor = .lightGray // 어두운 배경에 대비되는 색상
            titleLabel.font = UIFont.systemFont(ofSize: 18) // 폰트 크기 증가
            
            let valueLabel = UILabel()
            valueLabel.text = value
            valueLabel.font = UIFont.boldSystemFont(ofSize: 18) // 폰트 크기 증가
            valueLabel.textAlignment = .right
            valueLabel.textColor = .white // 어두운 배경에 대비되는 색상
            valueLabel.translatesAutoresizingMaskIntoConstraints = false
            valueLabel.widthAnchor.constraint(equalToConstant: 150).isActive = true // 고정 너비 설정
            
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
        confirmButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold) // 폰트 크기 증가
        confirmButton.layer.cornerRadius = 10
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        confirmButton.heightAnchor.constraint(equalToConstant: 50).isActive = true // 버튼 높이 증가
        confirmButton.addTarget(self, action: #selector(dismissModal), for: .touchUpInside)
        
        let mainStackView = UIStackView(arrangedSubviews: [headerStackView, summaryStackView, confirmButton])
        mainStackView.axis = .vertical
        mainStackView.spacing = 30 // 간격 증가
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
