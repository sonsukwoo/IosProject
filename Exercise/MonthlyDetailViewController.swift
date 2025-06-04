import UIKit  // 차트

import DGCharts

/// 값 라벨을 소수점 없이 정수로 표시하기 위한 포매터
final class IntValueFormatter: NSObject, ValueFormatter {
    func stringForValue(_ value: Double,
                        entry: ChartDataEntry,
                        dataSetIndex: Int,
                        viewPortHandler: ViewPortHandler?) -> String {
        let intVal = Int(value.rounded())
        return intVal == 0 ? "" : String(intVal)   // 0 값은 라벨 표시 안 함
    }
}

class MonthlyDetailViewController: UIViewController {
    
    // MARK: - UI 요소
    // 기존 하단 닫기 버튼 제거 → 네비게이션 바 뒤로 버튼으로 대체
    private let closeButton: UIButton? = nil
    let segmentedControl = UISegmentedControl(items: ["일", "주", "월", "년"])

    /// 네비게이션 바가 없을 때만 보여 줄 임시 타이틀 라벨
    private let fallbackTitleLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "통계 차트"
        lbl.font = .boldSystemFont(ofSize: 24)
        lbl.textColor = .white
        lbl.textAlignment = .left
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()
    
    let chartScrollView = UIScrollView()
    let chartStackView  = UIStackView()
    
    // 각 운동별 카드 & 차트
    let squatCard   = UIView()
    let pushUpCard  = UIView()
    let pullUpCard  = UIView()
    
    let squatChart  = BarChartView()
    let pushUpChart = BarChartView()
    let pullUpChart = BarChartView()
    
    // 전달받은 기준 날짜
    var currentMonth: Date?
    var selectedDate: Date?
    /// 외부에서 전달받은 초기 세그먼트 인덱스 (0:일, 1:주, 2:월, 3:년)
    var initialSegmentIndex: Int = 0
    
    // MARK: - 생명주기
    override func viewDidLoad() {
        super.viewDidLoad()
        // 화면을 항상 다크 모드로 고정
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = .black
        
        configureNavigationBar()
        setupUI()
        // 왼쪽 가장자리 스와이프 → 뒤로가기 (모달/네비 모두 지원)
        let edgeSwipe = UIScreenEdgePanGestureRecognizer(target: self,
                                                         action: #selector(closeButtonTapped))
        edgeSwipe.edges = .left
        view.addGestureRecognizer(edgeSwipe)
        updateAllCharts(for: initialSegmentIndex, baseDate: selectedDate)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    // MARK: - NavigationBar
    private func configureNavigationBar() {
        title = "통계 차트"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]

        let appear = UINavigationBarAppearance()
        appear.configureWithTransparentBackground()   // 투명 배경
        appear.backgroundColor = .clear
        appear.shadowColor = .clear                   // 하단 구분선 제거
        appear.titleTextAttributes = [.foregroundColor: UIColor.white]

        let navBar = navigationController?.navigationBar
        navBar?.standardAppearance    = appear
        navBar?.scrollEdgeAppearance  = appear
        navBar?.compactAppearance     = appear

        let backItem = UIBarButtonItem(title: "뒤로",
                                       style: .plain,
                                       target: self,
                                       action: #selector(closeButtonTapped))
        if let chevron = UIImage(systemName: "chevron.backward") {
            backItem.image = chevron
        }
        backItem.tintColor = .systemGreen   // Health 앱과 비슷한 연두색
        navigationItem.leftBarButtonItem = backItem
    }
    
    // MARK: - UI
    private func setupUI() {
        let topAnchor: NSLayoutYAxisAnchor
        if navigationController == nil {
            view.addSubview(fallbackTitleLabel)
            NSLayoutConstraint.activate([
                fallbackTitleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
                fallbackTitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
                fallbackTitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
            ])
            topAnchor = fallbackTitleLabel.bottomAnchor
        } else {
            topAnchor = view.safeAreaLayoutGuide.topAnchor
        }
        segmentedControl.selectedSegmentIndex = initialSegmentIndex
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.addTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)

        view.addSubview(segmentedControl)
        view.addSubview(chartScrollView)

        chartScrollView.translatesAutoresizingMaskIntoConstraints = false
        chartStackView.axis = .vertical
        chartStackView.spacing = 20
        chartStackView.translatesAutoresizingMaskIntoConstraints = false
        chartScrollView.addSubview(chartStackView)

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            chartScrollView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 20),
            chartScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            chartScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            chartScrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            chartStackView.topAnchor.constraint(equalTo: chartScrollView.topAnchor),
            chartStackView.leadingAnchor.constraint(equalTo: chartScrollView.leadingAnchor),
            chartStackView.trailingAnchor.constraint(equalTo: chartScrollView.trailingAnchor),
            chartStackView.bottomAnchor.constraint(equalTo: chartScrollView.bottomAnchor),
            chartStackView.widthAnchor.constraint(equalTo: chartScrollView.widthAnchor)
        ])

        addChartCard(title: "스쿼트", card: squatCard, chart: squatChart)
        addChartCard(title: "푸쉬업", card: pushUpCard, chart: pushUpChart)
        addChartCard(title: "턱걸이", card: pullUpCard, chart: pullUpChart)
    }
    
    private func addChartCard(title: String, card: UIView, chart: BarChartView) {
        card.backgroundColor = UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1)
        card.layer.cornerRadius = 20
        card.layer.cornerCurve  = .continuous
        card.layer.masksToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        chart.translatesAutoresizingMaskIntoConstraints = false
        chart.backgroundColor = UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1) // 짙은 회색 배경
        chart.layer.cornerRadius = 12
        chart.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner] // top‑left & top‑right만 둥글게
        chart.layer.cornerCurve  = .continuous   // smooth iOS‑style corners
        chart.clipsToBounds     = true
        
        card.addSubview(titleLabel)
        card.addSubview(chart)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            
            chart.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            chart.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            chart.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
            chart.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
            chart.heightAnchor.constraint(equalToConstant: 150)
        ])
        chartStackView.addArrangedSubview(card)
    }
    
    // MARK: - 차트 업데이트
    private func updateAllCharts(for index: Int, baseDate: Date?) {
        let cal = Calendar.current
        let records = UserDefaults.standard.array(forKey: "exerciseSummaries") as? [[String: Any]] ?? []

        // Helper: 특정 기간 레코드 필터
        func filterRecords(_ cond: (_ date: Date)->Bool) -> [[String:Any]] {
            records.filter {
                guard let d = $0["date"] as? Date else { return false }
                return cond(d)
            }
        }

        switch index {
        case 0: // 일
            let day = baseDate ?? Date()
            let dayRecords = filterRecords { cal.isDate($0, inSameDayAs: day) }
            updateDailyCharts(with: dayRecords)

        case 1: // 주
            let day = baseDate ?? Date()
            let w  = cal.component(.weekOfYear, from: day)
            let yW = cal.component(.yearForWeekOfYear, from: day)
            let weekRecords = filterRecords {
                cal.component(.weekOfYear, from: $0) == w &&
                cal.component(.yearForWeekOfYear, from: $0) == yW
            }
            updateWeeklyCharts(with: weekRecords)

        case 2: // 월  → 일자(선택 월의 1…마지막 날)로 기능 변경
            let base = currentMonth ?? Date()
            let m = cal.component(.month, from: base)
            let y = cal.component(.year,  from: base)
            let monthRecords = filterRecords {
                cal.component(.month, from: $0) == m &&
                cal.component(.year,  from: $0) == y
            }
            updateDayOfMonthCharts(with: monthRecords, monthBase: base)

        case 3: // 년  → 연간(월별) 차트
            let base = currentMonth ?? Date()
            let y = cal.component(.year, from: base)
            let yearRecords = filterRecords { cal.component(.year, from: $0) == y }
            updateMonthlyCharts(with: yearRecords, year: y)

        default:
            resetCharts(with: "데이터 없음")
        }
    }

    // 공통 초기화: 차트에 데이터가 없을 때 메시지 표시
    private func resetCharts(with message: String) {
        [squatChart, pushUpChart, pullUpChart].forEach {
            $0.data = nil
            $0.noDataText = message
            $0.noDataTextColor = .lightGray
        }
    }
    
    // MARK: - 차트별 세부 업데이트
    /// 선택된 하루 ‑ 시간대(0‑23시) 별 차트
    private func updateDailyCharts(with recs: [[String:Any]]) {
        guard !recs.isEmpty else { return resetCharts(with: "기록 없음") }
        
        // 시간대별(0‥23) 집계용 배열
        var byHour: [String:[Int]] = [:]
        ["스쿼트","푸쉬업","턱걸이"].forEach { byHour[$0] = Array(repeating: 0, count: 24) }
        
        let cal = Calendar.current
        recs.forEach {
            guard let t  = $0["exerciseType"] as? String,
                  let r  = $0["reps"]          as? Int,
                  let dt = $0["date"]          as? Date else { return }
            let h = cal.component(.hour, from: dt)        // 0‥23
            byHour[t]![h] += r
        }
        
        // X축 라벨: 0,1,2 … 23
        let hourLabels = (0...23).map { "\($0)" }
        
        applyMultiBar(to: squatChart,
                      values: (0...23).map { Double(byHour["스쿼트"]![$0]) },
                      labels: hourLabels,
                      color: .systemGreen)
        
        applyMultiBar(to: pushUpChart,
                      values: (0...23).map { Double(byHour["푸쉬업"]![$0]) },
                      labels: hourLabels,
                      color: .systemBlue)
        
        applyMultiBar(to: pullUpChart,
                      values: (0...23).map { Double(byHour["턱걸이"]![$0]) },
                      labels: hourLabels,
                      color: .systemPurple)
    }
    
    private func updateWeeklyCharts(with recs: [[String:Any]]) {
        guard !recs.isEmpty else { return resetCharts(with: "기록 없음") }
        let cal = Calendar.current
        var byDay: [String:[Int]] = [:] // key 운동, 배열 1...7
        ["스쿼트","푸쉬업","턱걸이"].forEach { byDay[$0] = Array(repeating: 0, count: 8) }
        recs.forEach {
            guard let t = $0["exerciseType"] as? String,
                  let r = $0["reps"] as? Int,
                  let d = $0["date"] as? Date else { return }
            let w = cal.component(.weekday, from: d)
            byDay[t]![w] += r
        }
        let order = [1,2,3,4,5,6,7]
        let labels = ["일","월","화","수","목","금","토"]
        applyMultiBar(to: squatChart, values: order.map{Double(byDay["스쿼트"]![$0])}, labels: labels, color: .systemGreen)
        applyMultiBar(to: pushUpChart, values: order.map{Double(byDay["푸쉬업"]![$0])}, labels: labels, color: .systemBlue)
        applyMultiBar(to: pullUpChart, values: order.map{Double(byDay["턱걸이"]![$0])}, labels: labels, color: .systemPurple)
    }
    
    private func updateMonthlyCharts(with recs: [[String:Any]], year: Int) {
        let cal = Calendar.current
        var byMonth = ["스쿼트":Array(repeating:0, count:13),
                       "푸쉬업":Array(repeating:0, count:13),
                       "턱걸이":Array(repeating:0, count:13)]
        recs.forEach {
            guard let t = $0["exerciseType"] as? String,
                  let r = $0["reps"] as? Int,
                  let d = $0["date"] as? Date else { return }
            let m = cal.component(.month, from: d)
            byMonth[t]![m] += r
        }
        let labels = (1...12).map { "\($0)월" }
        applyMultiBar(to: squatChart, values: (1...12).map{Double(byMonth["스쿼트"]![$0])}, labels: labels, color: .systemGreen)
        applyMultiBar(to: pushUpChart, values: (1...12).map{Double(byMonth["푸쉬업"]![$0])},  labels: labels, color: .systemBlue)
        applyMultiBar(to: pullUpChart, values: (1...12).map{Double(byMonth["턱걸이"]![$0])}, labels: labels, color: .systemPurple)
    }
    
    private func updateYearlyCharts(with recs: [[String:Any]]) {
        guard !recs.isEmpty else { return resetCharts(with: "기록 없음") }
        let cal = Calendar.current
        let years = Set(recs.compactMap {
            ($0["date"] as? Date).map { cal.component(.year, from: $0) }
        }).sorted()
        var byYear = ["스쿼트":Array(repeating:0, count: years.count),
                      "푸쉬업":Array(repeating:0, count: years.count),
                      "턱걸이":Array(repeating:0, count: years.count)]
        for (idx, y) in years.enumerated() {
            recs.forEach {
                guard let t = $0["exerciseType"] as? String,
                      let r = $0["reps"] as? Int,
                      let d = $0["date"] as? Date else { return }
                if cal.component(.year, from: d) == y {
                    byYear[t]![idx] += r
                }
            }
        }
        let labels = years.map { "\($0)" }
        applyMultiBar(to: squatChart, values: byYear["스쿼트"]!.map{Double($0)}, labels: labels, color: .systemGreen)
        applyMultiBar(to: pushUpChart, values: byYear["푸쉬업"]!.map{Double($0)},  labels: labels, color: .systemBlue)
        applyMultiBar(to: pullUpChart, values: byYear["턱걸이"]!.map{Double($0)}, labels: labels, color: .systemPurple)
    }
    
    // MARK: - 차트 Helper
    private func applySingleBar(to chart: BarChartView, value: Int, color: UIColor) {
        let entry = BarChartDataEntry(x: 0, y: Double(value))
        let set   = BarChartDataSet(entries: [entry], label: "")
        let intFormatter = IntValueFormatter()
        set.valueFormatter = intFormatter
        set.colors = [color]

        let data = BarChartData(dataSet: set)
        data.setValueFormatter(intFormatter)

        chart.data = data
        configureXAxis(chart, labels: ["전체"])
    }
    
    private func applyMultiBar(to chart: BarChartView, values: [Double], labels: [String], color: UIColor) {
        let entries = values.enumerated().map { BarChartDataEntry(x: Double($0.offset), y: $0.element) }
        let set     = BarChartDataSet(entries: entries, label: "")
        let intFormatter = IntValueFormatter()
        set.valueFormatter = intFormatter
        set.colors  = [color]

        let data    = BarChartData(dataSet: set)
        data.setValueFormatter(intFormatter)

        chart.data  = data
        configureXAxis(chart, labels: labels)
    }
    
    private func configureXAxis(_ chart: BarChartView, labels: [String]) {
        chart.xAxis.valueFormatter = IndexAxisValueFormatter(values: labels)
        chart.xAxis.labelPosition  = .bottom
        chart.xAxis.labelCount = labels.count              // 원하는 라벨 개수(강제 X)
        // 첫‑마지막 라벨을 정확히 가운데 정렬하기 위해 클리핑 방지 옵션 끔
        chart.xAxis.avoidFirstLastClippingEnabled = false
        chart.xAxis.granularity = 1
        // 하루(0‥23) 차트일 때 너무 촘촘한 라벨을 3시간 간격으로만 표시
        if labels.count == 24 {
            chart.xAxis.labelCount = 9   // 0,3,6 … 24
            chart.xAxis.granularity = 3
        }
        else if labels.count >= 28 {
            // 1, 8, 15, 22, 29 처럼 7일 간격으로만 라벨 표시
            chart.xAxis.setLabelCount(5, force: true)
            chart.xAxis.granularity = 7
        }
        chart.leftAxis.axisMinimum = 0
        // 가로(수평) 그리드 라인 및 라벨 개수를 줄여 거미줄 느낌 완화
        chart.leftAxis.labelCount = 4          // 기본 6 → 4로 축소
        chart.rightAxis.enabled    = false
        // --- 차트 상호작용 비활성화 & 가장자리 잘림 방지 ---
        chart.setScaleEnabled(false)           // pinch‑zoom
        chart.pinchZoomEnabled     = false
        chart.doubleTapToZoomEnabled = false
        chart.dragEnabled          = false
        chart.highlightPerTapEnabled  = false
        chart.highlightPerDragEnabled = false

        // --- 막대 폭을 항목 수 + 실제 데이터 개수에 따라 자동 조정 ---
        // 기본 폭은 라벨 개수 기준
        var barWidth: Double
        switch labels.count {
        case 0...10:   barWidth = 0.7          // 항목이 적으면 넓게
        case 11...20:  barWidth = 0.5
        case 21...27:  barWidth = 0.4
        default:       barWidth = 0.3          // 28개 이상(1~31일, 0~23시간 등)
        }

        // ---- 연간(12개월) 차트는 막대 폭을 약간 더 넓게 ----
        if labels.count == 12 {      // 년 탭
            barWidth = max(barWidth, 0.8)  // 0.6으로 확대 (주/월/일 차트는 그대로)
        }

        // ---- 기록(값>0) 개수가 적을 경우 막대 폭을 더 키움 (일 & 월 탭 전용) ----
        // 주(7개)·년(12개) 차트는 그대로 둠
        if labels.count >= 24 {   // 일(24시간) 또는 월(1~28/29/30/31) 뷰
            if let firstSet = chart.data?.dataSets.first as? BarChartDataSet {
                let nonZero = firstSet.entries.filter { $0.y > 0 }.count
                switch nonZero {
                case 0...3:      // 기록이 매우 적음
                    barWidth = 0.9
                case 4...8:      // 소량
                    barWidth = 0.8
                case 9...16:     // 중간
                    barWidth = 0.6
                default:         // 그 이상은 기본 규칙 유지
                    break
                }
            }
        }

        if let data = chart.data as? BarChartData {
            data.barWidth = barWidth
        }
        // 막대 폭의 절반 + 여분 패딩만큼 좌우 여백을 주어 첫‧마지막 막대도 정확히 중앙에 & 화면에 붙지 않음
        let halfBar = barWidth / 2.0
        let extraPad = 0.2               // 여분 0.2칸 패딩
        chart.xAxis.axisMinimum = -(halfBar + extraPad)
        chart.xAxis.axisMaximum = Double(labels.count - 1) + halfBar + extraPad

        chart.chartDescription.enabled = false
        chart.legend.enabled = false
    }
    
    /// 선택된 월의 일자(1‥28/29/30/31) 별 차트
    private func updateDayOfMonthCharts(with recs: [[String:Any]], monthBase: Date) {
        guard !recs.isEmpty else { return resetCharts(with: "기록 없음") }
        let cal = Calendar.current
        let range = cal.range(of: .day, in: .month, for: monthBase) ?? 1..<32   // 기본값을 ClosedRange → Range 로 변경
        var byDay = ["스쿼트":Array(repeating:0, count: range.count + 1),
                     "푸쉬업":Array(repeating:0, count: range.count + 1),
                     "턱걸이":Array(repeating:0, count: range.count + 1)]
        recs.forEach {
            guard let t = $0["exerciseType"] as? String,
                  let r = $0["reps"] as? Int,
                  let d = $0["date"] as? Date else { return }
            let day = cal.component(.day, from: d)
            byDay[t]![day] += r
        }
        let labels = range.map { "\($0)" }
        applyMultiBar(to: squatChart, values: range.map{Double(byDay["스쿼트"]![$0])}, labels: labels, color: .systemGreen)
        applyMultiBar(to: pushUpChart, values: range.map{Double(byDay["푸쉬업"]![$0])},  labels: labels, color: .systemBlue)
        applyMultiBar(to: pullUpChart, values: range.map{Double(byDay["턱걸이"]![$0])}, labels: labels, color: .systemPurple)
    }

    // MARK: - Actions
    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        updateAllCharts(for: sender.selectedSegmentIndex, baseDate: selectedDate)
    }
    
    @objc private func closeButtonTapped() {
        if let nav = navigationController {
            if nav.viewControllers.first != self {
                // 푸시 스택 중간이라면 pop
                nav.popViewController(animated: true)
            } else {
                // 루트 VC라면 모달로 올라온 NavigationController 자체를 닫음
                nav.dismiss(animated: true)
            }
        } else {
            // 네비게이션 컨트롤러 없이 단독 모달
            dismiss(animated: true)
        }
    }
}
 
