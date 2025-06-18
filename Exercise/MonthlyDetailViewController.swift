import UIKit  // 차트


import DGCharts

// ---- RoundedBarChartRenderer --------------------------------------------
/// DGCharts 기본 BarChartRenderer 를 확장해 막대 상단 모서리를 둥글게 그려준다.
/// (코드 출처: 커스텀 구현)
final class RoundedBarChartRenderer: BarChartRenderer {
    private let cornerRadius: CGFloat
    
    init(dataProvider: BarChartDataProvider,
         animator: Animator,
         viewPortHandler: ViewPortHandler,
         cornerRadius: CGFloat = 4.0) {
        self.cornerRadius = cornerRadius
        super.init(dataProvider: dataProvider,
                   animator: animator,
                   viewPortHandler: viewPortHandler)
    }
    
    override func drawDataSet(context: CGContext,
                              dataSet: BarChartDataSetProtocol,
                              index: Int) {
        guard let dataProvider = dataProvider,
              let barData = dataProvider.barData,
              let dataSet = dataSet as? BarChartDataSet else { return }
        
        let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
        let phaseY = CGFloat(animator.phaseY)
        let barWidthHalf = CGFloat(barData.barWidth / 2.0)
        let valueFont = dataSet.valueFont
        let valueFormatter = dataSet.valueFormatter ?? DefaultValueFormatter(decimals: 0)
         
        // 반복: 데이터셋 내 모든 항목
        for j in 0 ..< dataSet.entryCount {
            guard let e = dataSet.entryForIndex(j) as? BarChartDataEntry else { continue }
            
            let x = CGFloat(e.x)
            let y = CGFloat(e.y) * phaseY
            
            // 원본(값) 좌표 → 픽셀 좌표로 변환하기 위한 사각형
            var rect = CGRect(x: x - barWidthHalf,
                              y: 0,
                              width: barWidthHalf * 2.0,
                              height: y)
            trans.rectValueToPixel(&rect)
            
            // 화면 밖이면 건너뜀
            if !viewPortHandler.isInBoundsLeft(rect.maxX) { continue }
            if !viewPortHandler.isInBoundsRight(rect.minX) { break }
            
            // 상단 두 모서리만 둥글게
            let path = UIBezierPath(roundedRect: rect,
                                    byRoundingCorners: [.topLeft, .topRight],
                                    cornerRadii: CGSize(width: cornerRadius,
                                                        height: cornerRadius))
            
            context.saveGState()
            context.addPath(path.cgPath)
            context.setFillColor(dataSet.color(atIndex: j).cgColor)
            context.fillPath()
            context.restoreGState()
            
            // 값 라벨 그리기
            let valText = valueFormatter.stringForValue(e.y,
                                                       entry: e,
                                                       dataSetIndex: index,
                                                       viewPortHandler: viewPortHandler)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: valueFont,
                .foregroundColor: dataSet.valueTextColorAt(j),
                .paragraphStyle: paragraphStyle
            ]
            
            let textSize = valText.size(withAttributes: attributes)
            // 막대 상단 바로 위에 그리도록 위치 지정 (반경 2pt 여유)
            let textPos = CGPoint(
                x: rect.midX - textSize.width / 2.0,
                y: rect.origin.y - textSize.height - 2
            )
            valText.draw(at: textPos, withAttributes: attributes)
        }
    }
}
// -------------------------------------------------------------------------

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
    let segmentedControl = UISegmentedControl(items: ["일", "주", "월", "년"])
    // 토글: 개수/칼로리 전환 버튼
    // 네비게이션바 버튼 제거, 대신 인라인 버튼 사용
    private var showCalories = false
    
    let chartScrollView = UIScrollView()
    let chartStackView  = UIStackView()
    
    // 각 운동별 카드 & 차트
    let squatCard   = UIView()
    let pushUpCard  = UIView()
    let pullUpCard  = UIView()

    let squatChart  = BarChartView()
    let pushUpChart = BarChartView()
    let pullUpChart = BarChartView()

    // 각 운동별 서브타이틀 레이블
    let squatSubtitleLabel = UILabel()
    let pushUpSubtitleLabel = UILabel()
    let pullUpSubtitleLabel = UILabel()
    private let squatTotalLabel = UILabel()
    private let pushUpTotalLabel = UILabel()
    private let pullUpTotalLabel = UILabel()
    
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
        // 네비게이션 바도 강제로 다크 모드로 고정
        navigationController?.navigationBar.overrideUserInterfaceStyle = .dark
        view.backgroundColor = .black

        configureNavigationBar()
        setupUI()
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
        appear.configureWithOpaqueBackground()       // 불투명 배경
        appear.backgroundColor = .black             // 다크 배경 고정
        appear.shadowColor = .clear                 // 하단 구분선 제거
        appear.titleTextAttributes = [.foregroundColor: UIColor.white]

        let navBar = navigationController?.navigationBar
        navBar?.standardAppearance   = appear
        navBar?.scrollEdgeAppearance = appear
        navBar?.compactAppearance    = appear
        navBar?.barTintColor         = .black       // 바 자체를 검정으로 고정
        navBar?.tintColor            = .white       // 뒤로 버튼 색을 흰색으로
        navBar?.isTranslucent        = false        // 반투명 비활성화
        // 바 스타일을 검정으로 설정하여 항상 흰색 제목 보이도록
        navBar?.barStyle = .black

        // appearance 설정 이후에도 네비게이션 바를 다크 모드로 강제
        navigationController?.overrideUserInterfaceStyle = .dark

        let backItem = UIBarButtonItem(title: "뒤로",
                                       style: .plain,
                                       target: self,
                                       action: #selector(closeButtonTapped))
        if let chevron = UIImage(systemName: "chevron.backward") {
            backItem.image = chevron
        }
        backItem.tintColor = .systemBlue   // Blue back button
        navigationItem.leftBarButtonItem = backItem
        // --- Custom Toggle Button with Title and Icon ---
        let toggleButton = UIButton(type: .system)
        toggleButton.setTitle(showCalories ? "칼로리" : "개수", for: .normal)
        if let icon = UIImage(systemName: "arrow.up.arrow.down") {
            toggleButton.setImage(icon, for: .normal)
        }
        toggleButton.tintColor = .systemBlue
        toggleButton.semanticContentAttribute = .forceRightToLeft
        toggleButton.addTarget(self, action: #selector(toggleUnit), for: .touchUpInside)
        // 버튼 크기를 텍스트와 아이콘에 맞춰 자동 조정하고, 여유 패딩 추가
        toggleButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        toggleButton.sizeToFit()
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: toggleButton)
    }
    
    // MARK: - UI
    private func setupUI() {
        let topAnchor = view.safeAreaLayoutGuide.topAnchor
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


        addChartCard(title: "스쿼트", subtitleLabel: squatSubtitleLabel, totalLabel: squatTotalLabel, card: squatCard, chart: squatChart)
        addChartCard(title: "푸쉬업", subtitleLabel: pushUpSubtitleLabel, totalLabel: pushUpTotalLabel, card: pushUpCard, chart: pushUpChart)
        addChartCard(title: "턱걸이", subtitleLabel: pullUpSubtitleLabel, totalLabel: pullUpTotalLabel, card: pullUpCard, chart: pullUpChart)
    }
    
    private func addChartCard(title: String, subtitleLabel: UILabel, totalLabel: UILabel, card: UIView, chart: BarChartView) {
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

        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .lightGray
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = ""

        // 총합 라벨
        totalLabel.font = .systemFont(ofSize: 20, weight: .medium)
        totalLabel.textColor = .white
        totalLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(totalLabel)

        chart.translatesAutoresizingMaskIntoConstraints = false
        chart.backgroundColor = UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1) // 짙은 회색 배경
        chart.layer.cornerRadius = 12
        chart.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner] // top‑left & top‑right만 둥글게
        chart.layer.cornerCurve  = .continuous   // smooth iOS‑style corners
        // chart.renderer 설정은 각 update 함수에서 별도 지정
        chart.clipsToBounds     = true

        card.addSubview(titleLabel)
        card.addSubview(subtitleLabel)
        card.addSubview(chart)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            subtitleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),

            // 운동 이름과 서브타이틀 사이 중앙에 배치
            totalLabel.centerYAnchor.constraint(equalTo: subtitleLabel.topAnchor),
            totalLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),

            chart.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 2),
            chart.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            chart.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
            chart.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
            chart.heightAnchor.constraint(equalToConstant: 150)
        ])
        chartStackView.addArrangedSubview(card)
    }
    
    // MARK: - 차트 업데이트
    private func updateAllCharts(for index: Int, baseDate: Date?) {
        updateSubtitles(for: index, baseDate: baseDate)
        // 세그먼트를 변경할 때 이전에 그려진 데이터를 먼저 제거
        resetCharts(with: "데이터 없음")
        let cal = Calendar.current
        let rawRecords = UserDefaults.standard.array(forKey: "exerciseSummaries") as? [[String: Any]] ?? []

        // Parse records from UserDefaults; support "date" (Date) or "timestamp" (TimeInterval)
        let records: [[String: Any]] = rawRecords.compactMap { rec in
            guard let type = rec["exerciseType"] as? String,
                  let reps = rec["reps"] as? Int else { return nil }
            // Determine date
            let date: Date
            if let d = rec["date"] as? Date {
                date = d
            } else if let ts = rec["timestamp"] as? TimeInterval {
                date = Date(timeIntervalSince1970: ts)
            } else {
                return nil
            }
            // Build new record
            var newRec: [String: Any] = [
                "exerciseType": type,
                "reps": reps,
                "date": date
            ]
            // Handle calories stored as Double or Int
            if let calD = rec["calories"] as? Double {
                newRec["calories"] = calD
            } else if let calI = rec["calories"] as? Int {
                newRec["calories"] = Double(calI)
            }
            return newRec
        }

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
            updateTotals(with: dayRecords)

        case 1: // 주
            let day = baseDate ?? Date()
            let w  = cal.component(.weekOfYear, from: day)
            let yW = cal.component(.yearForWeekOfYear, from: day)
            let weekRecords = filterRecords {
                cal.component(.weekOfYear, from: $0) == w &&
                cal.component(.yearForWeekOfYear, from: $0) == yW
            }
            updateWeeklyCharts(with: weekRecords)
            updateTotals(with: weekRecords)

        case 2: // 월  → 일자(선택 월의 1…마지막 날)로 기능 변경
            let base = currentMonth ?? Date()
            let m = cal.component(.month, from: base)
            let y = cal.component(.year,  from: base)
            let monthRecords = filterRecords {
                cal.component(.month, from: $0) == m &&
                cal.component(.year,  from: $0) == y
            }
            updateDayOfMonthCharts(with: monthRecords, monthBase: base)
            updateTotals(with: monthRecords)

        case 3: // 년  → 연간(월별) 차트
            let base = currentMonth ?? Date()
            let y = cal.component(.year, from: base)
            let yearRecords = filterRecords { cal.component(.year, from: $0) == y }
            updateMonthlyCharts(with: yearRecords, year: y)
            updateTotals(with: yearRecords)

        default:
            resetCharts(with: "데이터 없음")
            updateTotals(with: [])
        }
    }

    private func updateTotals(with recs: [[String: Any]]) {
        func computeTotals(for type: String) -> (count: Int, cal: Double) {
            let filtered = recs.filter { $0["exerciseType"] as? String == type }
            let countSum = filtered.reduce(0) { $0 + ($1["reps"] as? Int ?? 0) }
            let calSum = filtered.reduce(0.0) { $0 + ($1["calories"] as? Double ?? 0.0) }
            return (countSum, calSum)
        }
        let squat = computeTotals(for: "스쿼트")
        let pushUp = computeTotals(for: "푸쉬업")
        let pullUp = computeTotals(for: "턱걸이")
        DispatchQueue.main.async {
            if self.showCalories {
                self.squatTotalLabel.text = "총 \(String(format: "%.1f", squat.cal)) kcal"
                self.pushUpTotalLabel.text = "총 \(String(format: "%.1f", pushUp.cal)) kcal"
                self.pullUpTotalLabel.text = "총 \(String(format: "%.1f", pullUp.cal)) kcal"
            } else {
                self.squatTotalLabel.text = "총 \(squat.count)개"
                self.pushUpTotalLabel.text = "총 \(pushUp.count)개"
                self.pullUpTotalLabel.text = "총 \(pullUp.count)개"
            }
        }
    }

    // 공통 초기화: 차트에 데이터가 없을 때 메시지 표시
    private func resetCharts(with message: String) {
        [squatChart, pushUpChart, pullUpChart].forEach {
            // 내부 상태와 화면을 모두 초기화
            $0.clear()                       // data = nil + 즉시 리프레시
            $0.noDataText = message
            $0.noDataTextColor = .lightGray
        }
    }
    
    // MARK: - 차트별 세부 업데이트
    /// 선택된 하루 ‑ 시간대(0‑23시) 별 차트
    private func updateDailyCharts(with recs: [[String:Any]]) {
        guard !recs.isEmpty else { return resetCharts(with: "기록 없음") }
        // 시간대별(0‥23) 집계용 배열 (개수, 칼로리)
        var byHourCount: [String:[Int]] = [:]
        var byHourCal:   [String:[Double]] = [:]
        ["스쿼트","푸쉬업","턱걸이"].forEach {
            byHourCount[$0] = Array(repeating: 0, count: 24)
            byHourCal[$0]   = Array(repeating: 0.0, count: 24)
        }
        let cal = Calendar.current
        recs.forEach {
            guard let t  = $0["exerciseType"] as? String,
                  let r  = $0["reps"]          as? Int,
                  let dt = $0["date"]          as? Date else { return }
            let h = cal.component(.hour, from: dt)        // 0‥23
            byHourCount[t]![h] += r
            if let calVal = $0["calories"] as? Double { byHourCal[t]![h] += calVal }
        }
        // X축 라벨: 0,1,2 … 23
        let hourLabels = (0...23).map { "\($0)" }
        // 일차트는 둥근 모서리 반경 2로 설정
        squatChart.renderer = RoundedBarChartRenderer(
            dataProvider: squatChart,
            animator: squatChart.chartAnimator,
            viewPortHandler: squatChart.viewPortHandler,
            cornerRadius: 2
        )
        pushUpChart.renderer = RoundedBarChartRenderer(
            dataProvider: pushUpChart,
            animator: pushUpChart.chartAnimator,
            viewPortHandler: pushUpChart.viewPortHandler,
            cornerRadius: 2
        )
        pullUpChart.renderer = RoundedBarChartRenderer(
            dataProvider: pullUpChart,
            animator: pullUpChart.chartAnimator,
            viewPortHandler: pullUpChart.viewPortHandler,
            cornerRadius: 2
        )
        applyMultiBar(to: squatChart,
                      values: showCalories ? (0...23).map { Double(byHourCal["스쿼트"]![$0]) }
                                         : (0...23).map { Double(byHourCount["스쿼트"]![$0]) },
                      labels: hourLabels,
                      color: .systemGreen)
        applyMultiBar(to: pushUpChart,
                      values: showCalories ? (0...23).map { Double(byHourCal["푸쉬업"]![$0]) }
                                         : (0...23).map { Double(byHourCount["푸쉬업"]![$0]) },
                      labels: hourLabels,
                      color: .systemBlue)
        applyMultiBar(to: pullUpChart,
                      values: showCalories ? (0...23).map { Double(byHourCal["턱걸이"]![$0]) }
                                         : (0...23).map { Double(byHourCount["턱걸이"]![$0]) },
                      labels: hourLabels,
                      color: .systemPurple)
    }
    
    private func updateWeeklyCharts(with recs: [[String:Any]]) {
        guard !recs.isEmpty else { return resetCharts(with: "기록 없음") }
        let cal = Calendar.current
        var byDayCount: [String:[Int]] = [:] // key 운동, 배열 1...7
        var byDayCal:   [String:[Double]] = [:]
        ["스쿼트","푸쉬업","턱걸이"].forEach {
            byDayCount[$0] = Array(repeating: 0, count: 8)
            byDayCal[$0]   = Array(repeating: 0.0, count: 8)
        }
        recs.forEach {
            guard let t = $0["exerciseType"] as? String,
                  let r = $0["reps"] as? Int,
                  let d = $0["date"] as? Date else { return }
            let w = cal.component(.weekday, from: d)
            byDayCount[t]![w] += r
            if let calVal = $0["calories"] as? Double { byDayCal[t]![w] += calVal }
        }
        let order = [1,2,3,4,5,6,7]
        let labels = ["일","월","화","수","목","금","토"]
        // 주차트는 모서리 반경 4
        squatChart.renderer = RoundedBarChartRenderer(
            dataProvider: squatChart,
            animator: squatChart.chartAnimator,
            viewPortHandler: squatChart.viewPortHandler,
            cornerRadius: 4
        )
        pushUpChart.renderer = RoundedBarChartRenderer(
            dataProvider: pushUpChart,
            animator: pushUpChart.chartAnimator,
            viewPortHandler: pushUpChart.viewPortHandler,
            cornerRadius: 4
        )
        pullUpChart.renderer = RoundedBarChartRenderer(
            dataProvider: pullUpChart,
            animator: pullUpChart.chartAnimator,
            viewPortHandler: pullUpChart.viewPortHandler,
            cornerRadius: 4
        )
        applyMultiBar(to: squatChart,
                      values: showCalories ? order.map{ Double(byDayCal["스쿼트"]![$0]) }
                                          : order.map{ Double(byDayCount["스쿼트"]![$0]) },
                      labels: labels, color: .systemGreen)
        applyMultiBar(to: pushUpChart,
                      values: showCalories ? order.map{ Double(byDayCal["푸쉬업"]![$0]) }
                                          : order.map{ Double(byDayCount["푸쉬업"]![$0]) },
                      labels: labels, color: .systemBlue)
        applyMultiBar(to: pullUpChart,
                      values: showCalories ? order.map{ Double(byDayCal["턱걸이"]![$0]) }
                                          : order.map{ Double(byDayCount["턱걸이"]![$0]) },
                      labels: labels, color: .systemPurple)
    }
    
    private func updateMonthlyCharts(with recs: [[String:Any]], year: Int) {
        let cal = Calendar.current
        var byMonthCount = ["스쿼트":Array(repeating:0, count:13),
                            "푸쉬업":Array(repeating:0, count:13),
                            "턱걸이":Array(repeating:0, count:13)]
        var byMonthCal = ["스쿼트":Array(repeating:0.0, count:13),
                          "푸쉬업":Array(repeating:0.0, count:13),
                          "턱걸이":Array(repeating:0.0, count:13)]
        recs.forEach {
            guard let t = $0["exerciseType"] as? String,
                  let r = $0["reps"] as? Int,
                  let d = $0["date"] as? Date else { return }
            let m = cal.component(.month, from: d)
            byMonthCount[t]![m] += r
            if let calVal = $0["calories"] as? Double { byMonthCal[t]![m] += calVal }
        }
        let labels = (1...12).map { "\($0)월" }
        // 월차트는 모서리 반경 4
        squatChart.renderer = RoundedBarChartRenderer(
            dataProvider: squatChart,
            animator: squatChart.chartAnimator,
            viewPortHandler: squatChart.viewPortHandler,
            cornerRadius: 4
        )
        pushUpChart.renderer = RoundedBarChartRenderer(
            dataProvider: pushUpChart,
            animator: pushUpChart.chartAnimator,
            viewPortHandler: pushUpChart.viewPortHandler,
            cornerRadius: 4
        )
        pullUpChart.renderer = RoundedBarChartRenderer(
            dataProvider: pullUpChart,
            animator: pullUpChart.chartAnimator,
            viewPortHandler: pullUpChart.viewPortHandler,
            cornerRadius: 4
        )
        applyMultiBar(to: squatChart,
                      values: showCalories ? (1...12).map{ Double(byMonthCal["스쿼트"]![$0]) }
                                          : (1...12).map{ Double(byMonthCount["스쿼트"]![$0]) },
                      labels: labels, color: .systemGreen)
        applyMultiBar(to: pushUpChart,
                      values: showCalories ? (1...12).map{ Double(byMonthCal["푸쉬업"]![$0]) }
                                          : (1...12).map{ Double(byMonthCount["푸쉬업"]![$0]) },
                      labels: labels, color: .systemBlue)
        applyMultiBar(to: pullUpChart,
                      values: showCalories ? (1...12).map{ Double(byMonthCal["턱걸이"]![$0]) }
                                          : (1...12).map{ Double(byMonthCount["턱걸이"]![$0]) },
                      labels: labels, color: .systemPurple)
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
        set.valueFont = UIFont.systemFont(ofSize: 10) // 숫자 크기 키우기
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
        else if labels.count == 28 {
            chart.xAxis.setLabelCount(4, force: true)
            chart.xAxis.granularity = 7
            chart.xAxis.granularityEnabled = true
        }
        else if labels.count == 29 {
            chart.xAxis.setLabelCount(4, force: true)
            chart.xAxis.granularity = 7
            chart.xAxis.granularityEnabled = true
        }
        else if labels.count == 30 {
            chart.xAxis.setLabelCount(5, force: true)
            chart.xAxis.granularity = 7
            chart.xAxis.granularityEnabled = true
        }
        else if labels.count == 31 {
            chart.xAxis.setLabelCount(3, force: true)
            chart.xAxis.granularity = 15
            chart.xAxis.granularityEnabled = true
        }
        // Y축 최소값 0으로 고정
        chart.leftAxis.axisMinimum = 0
        // Y축 라벨을 정수 단위로 표시
        chart.leftAxis.granularity = 1
        chart.leftAxis.granularityEnabled = true
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
        // Y축 최댓값을 데이터 최대값보다 약간 더 크게 설정하여 레이블이 잘리지 않도록 함
        if let data = chart.data as? BarChartData {
            let maxValue = data.yMax
            chart.leftAxis.axisMaximum = maxValue * 1.2 // 10% 여유
        }
        // 월별 차트: 1, 8, 15, 22, 29 기준으로 라벨 표시하고 패딩 제거
        if labels.count == 12 {
            let halfBar = barWidth / 2.0
            chart.xAxis.axisMinimum = -halfBar
            chart.xAxis.axisMaximum = Double(labels.count - 1) + halfBar
        }
        else if labels.count >= 28 && labels.count <= 31 {
            chart.xAxis.axisMinimum = 0
            chart.xAxis.axisMaximum = Double(labels.count - 1)
        } else {
            // 기본: 패딩 포함하여 첫·마지막 막대 중앙 정렬
            let halfBar = barWidth / 2.0
            let extraPad = 0.2               // 여분 0.2칸 패딩
            chart.xAxis.axisMinimum = -(halfBar + extraPad)
            chart.xAxis.axisMaximum = Double(labels.count - 1) + halfBar + extraPad
        }

        // Add extra left padding so Y-axis labels are not clipped
        chart.setExtraOffsets(left: 0, top: 0, right: 0, bottom: 0)

        chart.chartDescription.enabled = false
        chart.legend.enabled = false
    }

    // MARK: - Subtitle Helper
    private func updateSubtitles(for index: Int, baseDate: Date?) {
        let cal = Calendar.current
        let date = baseDate ?? Date()
        let year = cal.component(.year, from: date)
        let month = cal.component(.month, from: date)
        var subtitleText = ""
        switch index {
        case 0:
            let day = cal.component(.day, from: date)
            subtitleText = "\(year)년 \(month)월 \(day)일"
        case 1:
            let weekOfMonth = cal.component(.weekOfMonth, from: date)
            subtitleText = "\(year)년 \(month)월 \(weekOfMonth)주"
        case 2:
            subtitleText = "\(year)년 \(month)월"
        case 3:
            subtitleText = "\(year)년"
        default:
            break
        }
        [squatSubtitleLabel, pushUpSubtitleLabel, pullUpSubtitleLabel].forEach { $0.text = subtitleText }
    }
    
    /// 선택된 월의 일자(1‥28/29/30/31) 별 차트
    private func updateDayOfMonthCharts(with recs: [[String:Any]], monthBase: Date) {
        guard !recs.isEmpty else { return resetCharts(with: "기록 없음") }
        let cal = Calendar.current
        let range = cal.range(of: .day, in: .month, for: monthBase) ?? 1..<32   // 기본값을 ClosedRange → Range 로 변경
        var byDayOfMonthCount = ["스쿼트":Array(repeating:0, count: range.count + 1),
                                 "푸쉬업":Array(repeating:0, count: range.count + 1),
                                 "턱걸이":Array(repeating:0, count: range.count + 1)]
        var byDayOfMonthCal = ["스쿼트":Array(repeating:0.0, count: range.count + 1),
                               "푸쉬업":Array(repeating:0.0, count: range.count + 1),
                               "턱걸이":Array(repeating:0.0, count: range.count + 1)]
        recs.forEach {
            guard let t = $0["exerciseType"] as? String,
                  let r = $0["reps"] as? Int,
                  let d = $0["date"] as? Date else { return }
            let day = cal.component(.day, from: d)
            byDayOfMonthCount[t]![day] += r
            if let calVal = $0["calories"] as? Double { byDayOfMonthCal[t]![day] += calVal }
        }
        let labels = range.map { "\($0)" }
        // 일차트는 둥근 모서리 반경 2로 설정
        squatChart.renderer = RoundedBarChartRenderer(
            dataProvider: squatChart,
            animator: squatChart.chartAnimator,
            viewPortHandler: squatChart.viewPortHandler,
            cornerRadius: 2
        )
        pushUpChart.renderer = RoundedBarChartRenderer(
            dataProvider: pushUpChart,
            animator: pushUpChart.chartAnimator,
            viewPortHandler: pushUpChart.viewPortHandler,
            cornerRadius: 2
        )
        pullUpChart.renderer = RoundedBarChartRenderer(
            dataProvider: pullUpChart,
            animator: pullUpChart.chartAnimator,
            viewPortHandler: pullUpChart.viewPortHandler,
            cornerRadius: 2
        )
        applyMultiBar(to: squatChart,
                      values: showCalories ? range.map{ Double(byDayOfMonthCal["스쿼트"]![$0]) }
                                          : range.map{ Double(byDayOfMonthCount["스쿼트"]![$0]) },
                      labels: labels, color: .systemGreen)
        applyMultiBar(to: pushUpChart,
                      values: showCalories ? range.map{ Double(byDayOfMonthCal["푸쉬업"]![$0]) }
                                          : range.map{ Double(byDayOfMonthCount["푸쉬업"]![$0]) },
                      labels: labels, color: .systemBlue)
        applyMultiBar(to: pullUpChart,
                      values: showCalories ? range.map{ Double(byDayOfMonthCal["턱걸이"]![$0]) }
                                          : range.map{ Double(byDayOfMonthCount["턱걸이"]![$0]) },
                      labels: labels, color: .systemPurple)
    }

    // MARK: - Actions
    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        updateAllCharts(for: sender.selectedSegmentIndex, baseDate: selectedDate)
    }

    @objc private func toggleUnit() {
        showCalories.toggle()
        if let button = navigationItem.rightBarButtonItem?.customView as? UIButton {
            button.setTitle(showCalories ? "칼로리" : "개수", for: .normal)
            // 제목 변경 후 버튼 크기 재조정
            button.sizeToFit()
        }
        updateAllCharts(for: segmentedControl.selectedSegmentIndex, baseDate: selectedDate)
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
 
