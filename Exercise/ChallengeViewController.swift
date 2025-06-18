//
//  ChallengeViewController.swift
//  YourApp
//

import UIKit

/// 지난 7일간 평균을 기반으로 적절한 난이도의 과제를 랜덤 생성
struct Challenge {
    enum ExerciseType: String, CaseIterable {
        case squat = "스쿼트"
        case pushUp = "푸쉬업"
        case pullUp = "턱걸이"
    }
    let type: ExerciseType
    let reps: Int
    let sets: Int
    let description: String
}

class ChallengeViewController: UIViewController {
    // Prevents showing multiple alerts
    private var hasShownChallengeCompletionAlert = false
    private struct DefaultsKeys {
        static let dailyChallengeDate = "dailyChallengeDate"
        static let dailyChallengeData = "dailyChallengeData"
    }
    
    // MARK: - UI
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "오늘의 도전 과제"
        l.font = .boldSystemFont(ofSize: 24)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let descriptionLabel: UILabel = {
        let l = UILabel()
        l.numberOfLines = 0
        l.font = .systemFont(ofSize: 16)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()
    private let startButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("시작하기", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    
    // MARK: - Data
    private var challenge: Challenge!
    private var checklist: [String] = []
    private var allExerciseRecords: [[String: Any]] = []
    /// Tracks whether today's challenge has been completed
    private var isChallengeCompleted = false
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.title = ""
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh,
                                                            target: self,
                                                            action: #selector(refreshChallenge))
        generateChallenge()
        setupUI()
        applyChallengeToUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // After returning from ExerciseViewController, check for challenge completion
        if !hasShownChallengeCompletionAlert {
            checkChallengeCompletion()
        }
    }
    
    // MARK: - Challenge Logic
    private func generateChallenge(forceRefresh: Bool = false) {
        // Check if already saved for today
        let todayString = DateFormatter.cachedFormatter(format: "yyyy-MM-dd").string(from: Date())
        if !forceRefresh,
           let savedDate = UserDefaults.standard.string(forKey: DefaultsKeys.dailyChallengeDate),
           savedDate == todayString,
           let saved = UserDefaults.standard.dictionary(forKey: DefaultsKeys.dailyChallengeData),
           let typeRaw = saved["type"] as? String,
           let reps = saved["reps"] as? Int,
           let sets = saved["sets"] as? Int,
           let type = Challenge.ExerciseType(rawValue: typeRaw) {
            // reuse saved
            let desc = "\(type.rawValue) \(reps)회 × \(sets)세트 도전!"
            challenge = Challenge(type: type, reps: reps, sets: sets, description: desc)
        } else {
            // load records and compute new
            loadExerciseRecords()
            let candidates = Challenge.ExerciseType.allCases.filter {
                averageRepsLastWeek(for: $0) > 0
            }
            let type = candidates.randomElement() ?? Challenge.ExerciseType.allCases.randomElement()!
            let avgReps = averageRepsLastWeek(for: type)
            let rawReps = Int(avgReps * Double.random(in: 0.9...1.1))
            let reps = min(max(rawReps, 5), 30)
            let sets = Int.random(in: 2...4)
            let desc = "\(type.rawValue) \(reps)회 × \(sets)세트 도전!"
            challenge = Challenge(type: type, reps: reps, sets: sets, description: desc)
            // save to defaults
            UserDefaults.standard.setValue(todayString, forKey: DefaultsKeys.dailyChallengeDate)
            UserDefaults.standard.setValue(["type": type.rawValue, "reps": reps, "sets": sets], forKey: DefaultsKeys.dailyChallengeData)
        }
        print("🎯 [Challenge] Generated: \(challenge.description)")
        checklist = (1...challenge.sets).map { "세트 \($0) 완료" }
    }
    
    private func averageRepsLastWeek(for type: Challenge.ExerciseType) -> Double {
        let allSeven = loadLast7DaysRecords()
        let repsArray = allSeven.compactMap { dict -> Int? in
            guard
                let t = dict["exerciseType"] as? String, t == type.rawValue,
                let r = dict["reps"] as? Int, r > 0
            else { return nil }
            return r
        }
        print("🔢 [Challenge] Reps array for \(type.rawValue): \(repsArray)")
        guard !repsArray.isEmpty else {
            return Double(10)  // 기록 없으면 기본 10회
        }
        let avg = Double(repsArray.reduce(0, +)) / Double(repsArray.count)
        print("⚖️ [Challenge] Average reps last week for \(type.rawValue): \(avg)")
        return avg
    }

    /// Returns exercise summary records for the past 7 days (including today)
    private func loadLast7DaysRecords() -> [[String: Any]] {
        let raw = UserDefaults.standard.array(forKey: "exerciseSummaries") as? [[String: Any]] ?? []
        let cal = Calendar.current
        let start = cal.startOfDay(for: cal.date(byAdding: .day, value: -7, to: Date())!)
        let end = cal.date(bySettingHour: 23, minute: 59, second: 59, of: Date())!
        let filteredRecords = raw.filter { record in
            guard let recDate = record["date"] as? Date else { return false }
            return recDate >= start && recDate <= end
        }
        let nonZero = filteredRecords.filter { ($0["reps"] as? Int ?? 0) > 0 }
        print("🔍 [Challenge] Last 7 days non-zero record count: \(nonZero.count)")
        return nonZero
    }
    
    /// Fetch all saved exercise summaries from UserDefaults
    private func loadExerciseRecords() {
        let raw = UserDefaults.standard.array(forKey: "exerciseSummaries") as? [[String: Any]] ?? []
        allExerciseRecords = raw.compactMap { rec in
            guard let date = rec["date"] as? Date,
                  let type = rec["exerciseType"] as? String,
                  let reps = rec["reps"] as? Int else { return nil }
            return ["date": date, "exerciseType": type, "reps": reps]
        }
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.addSubview(titleLabel)
        view.addSubview(descriptionLabel)
        view.addSubview(tableView)
        view.addSubview(startButton)
        
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "CheckCell")
        tableView.allowsSelection = false
        
        startButton.addTarget(self, action: #selector(startChallenge), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            
            tableView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: startButton.topAnchor, constant: -16),
            
            startButton.topAnchor.constraint(equalTo: tableView.bottomAnchor, constant: 16),
            startButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            startButton.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }
    
    private func applyChallengeToUI() {
        descriptionLabel.text = challenge.description
        tableView.reloadData()
    }
    
    // MARK: - Actions
    @objc private func startChallenge() {
        // 1) Instantiate ExerciseViewController from the **Main** storyboard
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let exerciseVC = storyboard
                .instantiateViewController(withIdentifier: "ExerciseViewController") as? ExerciseViewController else {
            print("❗️[Challenge] Could not find ExerciseViewController in Main.storyboard")
            return
        }

        // 2) Map challenge type → ExerciseMode
        switch challenge.type {
        case .squat:
            exerciseVC.selectedMode = .squat
        case .pushUp:
            exerciseVC.selectedMode = .pushUp
        case .pullUp:
            exerciseVC.selectedMode = .pullUp
        }

        // 3) Pass today‑challenge parameters
        exerciseVC.targetRepetitions = challenge.reps
        exerciseVC.targetSets        = challenge.sets
        // 휴식 시간은 사용자가 기존에 저장해 둔 값(UserDefaults) 그대로 사용
        // 단, ExerciseViewController가 viewWillAppear에서 불러갈 수 있도록 저장도 해둔다.
        UserDefaults.standard.set(challenge.reps, forKey: "targetRepetitions")
        UserDefaults.standard.set(challenge.sets, forKey: "targetSets")

        // 4) Always show the exercise screen full‑screen
        exerciseVC.modalPresentationStyle = .fullScreen

        // 5) Present: ChallengeViewController 자체가 모달(시트)로 떠 있기 때문에
        //    여기서 바로 present 하면 위로 완전히 덮어쓰면서 잘 동작한다.
        self.present(exerciseVC, animated: true)
    }
    
    @objc private func refreshChallenge() {
        generateChallenge(forceRefresh: true)
        applyChallengeToUI()
    }

    /// Checks the most recent exercise summary against today's challenge and shows a congratulatory alert.
    private func checkChallengeCompletion() {
        // Fetch latest summary
        guard let all = UserDefaults.standard.array(forKey: "exerciseSummaries") as? [[String: Any]],
              let last = all.last,
              let type = last["exerciseType"] as? String,
              let reps = last["reps"] as? Int,
              let sets = last["sets"] as? Int
        else { return }

        // If it matches today's challenge exactly
        if type == challenge.type.rawValue && reps == challenge.reps && sets == challenge.sets {
            hasShownChallengeCompletionAlert = true
            isChallengeCompleted = true
            tableView.reloadData()
            startButton.isEnabled = false
            startButton.setTitle("완료됨", for: .normal)
            let alert = UIAlertController(title: "🎉 축하합니다!",
                                          message: "오늘의 도전 과제를 모두 완료하셨어요!",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "확인", style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
        }
    }
}

extension ChallengeViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int {
        return checklist.count
    }
    func tableView(_ tv: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(withIdentifier: "CheckCell", for: indexPath)
        cell.textLabel?.text = checklist[indexPath.row]
        print("📝 [Challenge] Displaying checklist row \(indexPath.row): \(cell.textLabel?.text ?? "")")
        if isChallengeCompleted {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        return cell
    }
    /*
    func tableView(_ tv: UITableView, didSelectRowAt indexPath: IndexPath) {
        // 완료 체크 토글
        let cell = tv.cellForRow(at: indexPath)!
        if cell.accessoryType == .none {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        tv.deselectRow(at: indexPath, animated: true)
    }
    */
}
