import UIKit
import FSCalendar

// MARK: - DatePickerModalViewControllerDelegate
protocol DatePickerModalViewControllerDelegate: AnyObject {
    func datePickerModalViewController(_ controller: DatePickerModalViewController, didSelect date: Date)
}

// MARK: - DatePickerModalViewController (모달 피커뷰)
class DatePickerModalViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
    
    weak var delegate: DatePickerModalViewControllerDelegate?
    
    let containerView = UIView()
    let pickerView = UIPickerView()
    let confirmButton = UIButton(type: .system)
    
    var years: [Int] = Array(1900...2100)
    let months: [Int] = Array(1...12)
    var days: [Int] = Array(1...31)
    
    var selectedYear: Int = Calendar.current.component(.year, from: Date())
    var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    var selectedDay: Int = Calendar.current.component(.day, from: Date())
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 항상 다크 모드 유지 (iOS 13 이상)
        if #available(iOS 13.0, *) {
            overrideUserInterfaceStyle = .dark
        }
        
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        containerView.backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        containerView.layer.cornerRadius = 12
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.9),
            containerView.heightAnchor.constraint(equalToConstant: 250)
        ])
        
        pickerView.delegate = self
        pickerView.dataSource = self
        pickerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(pickerView)
        
        confirmButton.setTitle("확인", for: .normal)
        confirmButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(confirmButton)
        
        NSLayoutConstraint.activate([
            pickerView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            pickerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            pickerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            pickerView.heightAnchor.constraint(equalToConstant: 180),
            
            confirmButton.topAnchor.constraint(equalTo: pickerView.bottomAnchor, constant: 10),
            confirmButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            confirmButton.heightAnchor.constraint(equalToConstant: 40),
            confirmButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -10)
        ])
        
        // 초기 선택값 설정
        if let yearIndex = years.firstIndex(of: selectedYear) {
            pickerView.selectRow(yearIndex, inComponent: 0, animated: false)
        }
        pickerView.selectRow(selectedMonth - 1, inComponent: 1, animated: false)
        pickerView.selectRow(selectedDay - 1, inComponent: 2, animated: false)
    }
    
    @objc func confirmTapped() {
        var comps = DateComponents()
        comps.year = selectedYear
        comps.month = selectedMonth
        comps.day = selectedDay
        if let date = Calendar.current.date(from: comps) {
            delegate?.datePickerModalViewController(self, didSelect: date)
        }
        dismiss(animated: true, completion: nil)
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int { return 3 }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if component == 0 {
            return years.count
        } else if component == 1 {
            return months.count
        } else {
            let dateComponents = DateComponents(year: selectedYear, month: selectedMonth)
            let calendar = Calendar.current
            if let date = calendar.date(from: dateComponents),
               let range = calendar.range(of: .day, in: .month, for: date) {
                return range.count
            }
            return 31
        }
    }
    
    func pickerView(_ pickerView: UIPickerView,
                    titleForRow row: Int,
                    forComponent component: Int) -> String? {
        if component == 0 {
            return "\(years[row])년"
        } else if component == 1 {
            return "\(months[row])월"
        } else {
            return "\(days[row])일"
        }
    }
    
    func pickerView(_ pickerView: UIPickerView,
                    didSelectRow row: Int,
                    inComponent component: Int) {
        if component == 0 {
            selectedYear = years[row]
            pickerView.reloadComponent(2)
        } else if component == 1 {
            selectedMonth = months[row]
            pickerView.reloadComponent(2)
        } else if component == 2 {
            if row < days.count {
                selectedDay = days[row]
            }
        }
    }
}
// MARK: - 헬퍼 메소드 전역 영역(클래스 바깥)에 선언
extension DateFormatter {
    private static var cachedFormatters: [String: DateFormatter] = [:]
    
    static func cachedFormatter(format: String, localeIdentifier: String = "ko_KR") -> DateFormatter {
        let key = "\(localeIdentifier)_\(format)"
        if let formatter = cachedFormatters[key] {
            return formatter
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: localeIdentifier)
            formatter.dateFormat = format
            cachedFormatters[key] = formatter
            return formatter
        }
    }
}

// MARK: - StatisticsViewController
class StatisticsViewController: UIViewController,
                                UITableViewDataSource,
                                UITableViewDelegate,
                                FSCalendarDataSource,
                                FSCalendarDelegate,
                                FSCalendarDelegateAppearance {
    
    // MARK: Properties & UI Components
    var navSearchBar: UISearchBar?
    
    let scrollView = UIScrollView()
    let contentView = UIView()
    
    let calendarContainer = UIView()
    var calendar: FSCalendar!
    
    let prevMonthButton = UIButton(type: .system)
    let nextMonthButton = UIButton(type: .system)
    let monthLabelButton = UIButton(type: .system)
    
    private let statsScrollView = UIScrollView()
    private let statsPageControl = UIPageControl()
    
    private let dailyStatsButton = UIButton(type: .system)
    private let monthlyStatsButton = UIButton(type: .system)
    
    private let kStatsPageIndexKey = "statsPageIndex"
    
    // 일별 통계 라벨들
    let dailyTotalRepsLabel = UILabel()
    let dailyExerciseTimeLabel = UILabel()
    let dailyCaloriesLabel = UILabel()
    let dailySquatLabel = UILabel()
    let dailyPushUpLabel = UILabel()
    let dailyPullUpLabel = UILabel()
    
    // 한달 통계 라벨들
    let exerciseDaysLabel = UILabel()
    let exerciseTimeLabel = UILabel()
    let caloriesLabel = UILabel()
    let squatLabel = UILabel()
    let pushUpLabel = UILabel()
    let pullUpLabel = UILabel()
    
    let tableViewContainer = UIView()
    let tableView = UITableView()
    
    let tableViewHeaderView = UIView()
    let recordLabel = UILabel()
    let sortButton = UIButton(type: .system)
    let sortSeparatorView = UIView()
    
    var allExerciseRecords: [[String: Any]] = []
    var filteredRecords: [[String: Any]] = []
    
    var isDescendingOrder = true

    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 다크 모드 설정
        if #available(iOS 13.0, *) {
            overrideUserInterfaceStyle = .dark
            navigationController?.overrideUserInterfaceStyle = .dark
            tabBarController?.overrideUserInterfaceStyle = .dark
        }
        view.backgroundColor = .black
        self.definesPresentationContext = true
        
        setupNavigationBar()
        setupScrollView()
        setupCalendarContainer()
        
        // 앱 실행 시 오늘 날짜 선택
        calendar.select(Date())
        
        setupStatsPagingView()
        setupTableViewContainer()
        
        loadExerciseRecords()
        updateMonthlyStatistics(for: Date())
        updateCalendarHeaderTitle(for: Date())
        
        setupTapGesture()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if #available(iOS 15.0, *) {
            guard let tabBar = self.tabBarController?.tabBar else { return }
            let appearance = tabBar.standardAppearance
            tabBar.scrollEdgeAppearance = appearance
        }
        
        loadExerciseRecords()
        filterRecords(by: calendar.selectedDate ?? Date())
        calendar.reloadData()
        updateMonthlyStatistics(for: calendar.currentPage)
        updateDailyStatistics(for: calendar.selectedDate ?? Date())
        
        let savedPageIndex = UserDefaults.standard.integer(forKey: kStatsPageIndexKey)
        DispatchQueue.main.async {
            let offsetX = CGFloat(savedPageIndex) * self.statsScrollView.bounds.width
            self.statsScrollView.contentOffset = CGPoint(x: offsetX, y: 0)
            self.statsPageControl.currentPage = savedPageIndex
            self.statsPageControl.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        }
    }
    
    // MARK: - Navigation Bar Setup
    func setupNavigationBar() {
        let leftSpacer = UIBarButtonItem(barButtonSystemItem: .fixedSpace,
                                         target: nil,
                                         action: nil)
        leftSpacer.width = 20

        let leftLabel = UILabel()
        leftLabel.text = "기록"
        leftLabel.font = UIFont.systemFont(ofSize: 25, weight: .bold)
        leftLabel.textColor = .white
        let leftItem = UIBarButtonItem(customView: leftLabel)

        navigationItem.leftBarButtonItems = [leftSpacer, leftItem]

        let searchButton = UIButton(type: .system)
        let magnifyingImage = UIImage(systemName: "magnifyingglass",
                                      withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .regular))
        searchButton.setImage(magnifyingImage, for: .normal)
        searchButton.tintColor = .systemBlue
        searchButton.addTarget(self, action: #selector(searchButtonTapped), for: .touchUpInside)
        let searchItem = UIBarButtonItem(customView: searchButton)

        // 오른쪽 바 버튼 항목에 searchItem만 추가합니다.
        navigationItem.rightBarButtonItems = [searchItem]
    }
    
    @objc func searchButtonTapped() {
        if navSearchBar == nil {
            navSearchBar = UISearchBar(frame: CGRect(x: 0, y: 0, width: view.frame.width - 40, height: 44))
            navSearchBar?.delegate = self
            navSearchBar?.placeholder = "ex) 스쿼트, 푸쉬업, 턱걸이"
            navSearchBar?.showsCancelButton = true
        }
        navigationItem.leftBarButtonItems = nil
        navigationItem.rightBarButtonItems = nil
        navigationItem.titleView = navSearchBar
        navSearchBar?.becomeFirstResponder()
    }
    
    // MARK: - ScrollView Setup
    func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .black
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }
    
    // MARK: - Calendar Setup
    func setupCalendarContainer() {
        calendarContainer.translatesAutoresizingMaskIntoConstraints = false
        calendarContainer.backgroundColor = UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1)
        calendarContainer.layer.cornerRadius = 20
        calendarContainer.layer.masksToBounds = true
        contentView.addSubview(calendarContainer)
        
        NSLayoutConstraint.activate([
            calendarContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            calendarContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            calendarContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            calendarContainer.heightAnchor.constraint(equalToConstant: 280)
        ])
        
        // FSCalendar 생성 및 설정
        calendar = FSCalendar()
        calendar.headerHeight = 0
        calendar.dataSource = self
        calendar.delegate = self
        calendar.translatesAutoresizingMaskIntoConstraints = false
        calendar.backgroundColor = .clear
        calendar.locale = Locale(identifier: "ko_KR")
        calendar.appearance.weekdayTextColor = .lightGray
        calendar.appearance.weekdayFont = UIFont.systemFont(ofSize: 12, weight: .medium)
        calendar.appearance.titleFont = UIFont.systemFont(ofSize: 18, weight: .regular)
        calendar.appearance.titleDefaultColor = .white
        calendar.appearance.todayColor = .clear
        calendar.appearance.selectionColor = .clear
        calendar.appearance.borderRadius = 1.0
        calendar.rowHeight = 30
        calendar.placeholderType = .none
        calendar.appearance.eventOffset = CGPoint(x: 0, y: 0)
        
        // MARK: Calendar Navigation Buttons & Header
        // 이전 달 버튼
        prevMonthButton.translatesAutoresizingMaskIntoConstraints = false
        prevMonthButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        prevMonthButton.tintColor = .systemBlue
        prevMonthButton.addTarget(self, action: #selector(prevMonthTapped), for: .touchUpInside)
        
        // 다음 달 버튼
        nextMonthButton.translatesAutoresizingMaskIntoConstraints = false
        nextMonthButton.setImage(UIImage(systemName: "chevron.right"), for: .normal)
        nextMonthButton.tintColor = .systemBlue
        nextMonthButton.addTarget(self, action: #selector(nextMonthTapped), for: .touchUpInside)
        
        // 가운데 월 표시 버튼 (밑줄 효과)
        monthLabelButton.translatesAutoresizingMaskIntoConstraints = false
        monthLabelButton.setTitleColor(.white, for: .normal)
        monthLabelButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        monthLabelButton.contentHorizontalAlignment = .center
        monthLabelButton.addTarget(self, action: #selector(monthLabelButtonTapped), for: .touchUpInside)
        
        // 서브뷰 추가
        calendarContainer.addSubview(prevMonthButton)
        calendarContainer.addSubview(nextMonthButton)
        calendarContainer.addSubview(monthLabelButton)
        calendarContainer.addSubview(calendar)
        
        // 오토레이아웃
        NSLayoutConstraint.activate([
            // 이전 달 버튼
            prevMonthButton.topAnchor.constraint(equalTo: calendarContainer.topAnchor, constant: 10),
            prevMonthButton.leadingAnchor.constraint(equalTo: calendarContainer.leadingAnchor, constant: 10),
            prevMonthButton.widthAnchor.constraint(equalToConstant: 30),
            prevMonthButton.heightAnchor.constraint(equalToConstant: 30),
            
            // 다음 달 버튼
            nextMonthButton.topAnchor.constraint(equalTo: calendarContainer.topAnchor, constant: 10),
            nextMonthButton.trailingAnchor.constraint(equalTo: calendarContainer.trailingAnchor, constant: -10),
            nextMonthButton.widthAnchor.constraint(equalToConstant: 30),
            nextMonthButton.heightAnchor.constraint(equalToConstant: 30),
            
            // 가운데 월 버튼
            monthLabelButton.centerYAnchor.constraint(equalTo: prevMonthButton.centerYAnchor),
            monthLabelButton.centerXAnchor.constraint(equalTo: calendarContainer.centerXAnchor),
            
            // 달력
            calendar.topAnchor.constraint(equalTo: prevMonthButton.bottomAnchor, constant: 5),
            calendar.bottomAnchor.constraint(equalTo: calendarContainer.bottomAnchor, constant: -10),
            calendar.leadingAnchor.constraint(equalTo: calendarContainer.leadingAnchor, constant: 10),
            calendar.trailingAnchor.constraint(equalTo: calendarContainer.trailingAnchor, constant: -10)
        ])
    }
    
    @objc func prevMonthTapped() {
        let currentPage = calendar.currentPage
        if let prevMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentPage) {
            calendar.setCurrentPage(prevMonth, animated: true)
            updateCalendarHeaderTitle(for: prevMonth)
        }
    }
    
    @objc func nextMonthTapped() {
        let currentPage = calendar.currentPage
        if let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentPage) {
            calendar.setCurrentPage(nextMonth, animated: true)
            updateCalendarHeaderTitle(for: nextMonth)
        }
    }
    
    @objc func monthLabelButtonTapped() {
        let datePickerVC = DatePickerModalViewController()
        datePickerVC.delegate = self
        datePickerVC.modalPresentationStyle = .overCurrentContext
        datePickerVC.modalTransitionStyle = .crossDissolve
        present(datePickerVC, animated: true, completion: nil)
    }
    
    func updateCalendarHeaderTitle(for date: Date) {
        let currentYear = Calendar.current.component(.year, from: Date())
        let calendarYear = Calendar.current.component(.year, from: date)
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = (currentYear == calendarYear) ? "M월" : "yyyy년 M월"
        
        let titleString = formatter.string(from: date)
        let underlineAttr: [NSAttributedString.Key: Any] = [
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .underlineColor: UIColor.white,
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 20, weight: .bold)
        ]
        let underlineText = NSAttributedString(string: titleString, attributes: underlineAttr)
        monthLabelButton.setAttributedTitle(underlineText, for: .normal)
    }
    
    // MARK: - Stats Paging (통계 카드)
    func setupStatsPagingView() {
        let statsContainer = UIView()
        statsContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statsContainer)
        
        NSLayoutConstraint.activate([
            statsContainer.topAnchor.constraint(equalTo: calendarContainer.bottomAnchor, constant: 15),
            statsContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            statsContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            statsContainer.heightAnchor.constraint(equalToConstant: 190)
        ])
        
        statsScrollView.translatesAutoresizingMaskIntoConstraints = false
        statsScrollView.showsHorizontalScrollIndicator = false
        statsScrollView.delegate = self
        statsScrollView.alwaysBounceHorizontal = true
        statsScrollView.decelerationRate = .fast
        statsScrollView.isPagingEnabled = false
        statsContainer.addSubview(statsScrollView)
        
        statsPageControl.numberOfPages = 2
        statsPageControl.currentPage = 0
        statsPageControl.pageIndicatorTintColor = .lightGray
        statsPageControl.currentPageIndicatorTintColor = .white
        statsPageControl.translatesAutoresizingMaskIntoConstraints = false
        statsPageControl.addTarget(self, action: #selector(pageControlChanged(_:)), for: .valueChanged)
        statsContainer.addSubview(statsPageControl)
        
        NSLayoutConstraint.activate([
            statsScrollView.topAnchor.constraint(equalTo: statsContainer.topAnchor),
            statsScrollView.leadingAnchor.constraint(equalTo: statsContainer.leadingAnchor),
            statsScrollView.trailingAnchor.constraint(equalTo: statsContainer.trailingAnchor),
            statsScrollView.heightAnchor.constraint(equalToConstant: 170),
            
            statsPageControl.topAnchor.constraint(equalTo: statsScrollView.bottomAnchor, constant: -4),
            statsPageControl.centerXAnchor.constraint(equalTo: statsContainer.centerXAnchor),
            statsPageControl.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        let stackView = UIStackView(arrangedSubviews: [dailyStatsButton, monthlyStatsButton])
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        statsScrollView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: statsScrollView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: statsScrollView.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: statsScrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: statsScrollView.trailingAnchor),
            stackView.widthAnchor.constraint(equalTo: statsScrollView.widthAnchor, multiplier: 2),
            stackView.heightAnchor.constraint(equalTo: statsScrollView.heightAnchor)
        ])
        
        dailyStatsButton.subviews.forEach { $0.isUserInteractionEnabled = false }
        monthlyStatsButton.subviews.forEach { $0.isUserInteractionEnabled = false }
        
        setupDailyStatsUI(in: dailyStatsButton)
        dailyStatsButton.addTarget(self, action: #selector(statisticsButtonTapped(_:)), for: .touchUpInside)
        
        setupMonthlyStatsUI(in: monthlyStatsButton)
        monthlyStatsButton.addTarget(self, action: #selector(statisticsButtonTapped(_:)), for: .touchUpInside)
    }
    
    @objc func pageControlChanged(_ sender: UIPageControl) {
        let pageIndex = sender.currentPage
        let offsetX = CGFloat(pageIndex) * statsScrollView.bounds.width
        statsScrollView.setContentOffset(CGPoint(x: offsetX, y: 0), animated: true)
    }
    
    // MARK: - Daily Statistics UI
    func setupDailyStatsUI(in container: UIButton) {
        container.backgroundColor = UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1)
        container.layer.cornerRadius = 20
        container.clipsToBounds = true
        
        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.distribution = .fill
        headerStack.spacing = 2
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.isUserInteractionEnabled = false
        
        let titleLabel = UILabel()
        titleLabel.text = "일별 통계"
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .white
        
        let chevronImageView = UIImageView()
        chevronImageView.image = UIImage(systemName: "chevron.right")
        chevronImageView.tintColor = .systemBlue
        chevronImageView.contentMode = .scaleAspectFit
        chevronImageView.setContentHuggingPriority(.required, for: .horizontal)
        chevronImageView.isUserInteractionEnabled = false
        
        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(chevronImageView)
        
        let separatorView = UIView()
        separatorView.backgroundColor = UIColor.lightGray.withAlphaComponent(0.3)
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        separatorView.heightAnchor.constraint(equalToConstant: 1).isActive = true
        separatorView.isUserInteractionEnabled = false
        
        let totalRepsTitle = UILabel()
        totalRepsTitle.text = "기록 개수"
        totalRepsTitle.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        totalRepsTitle.textColor = .lightGray
        totalRepsTitle.textAlignment = .center
        
        dailyTotalRepsLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        dailyTotalRepsLabel.textColor = .white
        dailyTotalRepsLabel.textAlignment = .center
        
        let totalRepsStack = UIStackView(arrangedSubviews: [totalRepsTitle, dailyTotalRepsLabel])
        totalRepsStack.axis = .vertical
        totalRepsStack.alignment = .center
        totalRepsStack.spacing = 4
        totalRepsStack.isUserInteractionEnabled = false
        
        let timeTitle = UILabel()
        timeTitle.text = "운동 시간"
        timeTitle.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        timeTitle.textColor = .lightGray
        timeTitle.textAlignment = .center
        
        dailyExerciseTimeLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        dailyExerciseTimeLabel.textColor = .white
        dailyExerciseTimeLabel.textAlignment = .center
        
        let timeStack = UIStackView(arrangedSubviews: [timeTitle, dailyExerciseTimeLabel])
        timeStack.axis = .vertical
        timeStack.alignment = .center
        timeStack.spacing = 4
        timeStack.isUserInteractionEnabled = false
        
        let calTitle = UILabel()
        calTitle.text = "칼로리"
        calTitle.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        calTitle.textColor = .lightGray
        calTitle.textAlignment = .center
        
        dailyCaloriesLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        dailyCaloriesLabel.textColor = .white
        dailyCaloriesLabel.textAlignment = .center
        
        let calStack = UIStackView(arrangedSubviews: [calTitle, dailyCaloriesLabel])
        calStack.axis = .vertical
        calStack.alignment = .center
        calStack.spacing = 4
        calStack.isUserInteractionEnabled = false
        
        let topStatsRow = UIStackView(arrangedSubviews: [totalRepsStack, timeStack, calStack])
        topStatsRow.axis = .horizontal
        topStatsRow.distribution = .fillEqually
        topStatsRow.alignment = .center
        topStatsRow.spacing = 20
        topStatsRow.isUserInteractionEnabled = false
        
        let squatTitle = UILabel()
        squatTitle.text = "스쿼트"
        squatTitle.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        squatTitle.textColor = .lightGray
        squatTitle.textAlignment = .center
        squatTitle.isUserInteractionEnabled = false
        
        dailySquatLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        dailySquatLabel.textColor = .white
        dailySquatLabel.textAlignment = .center
        
        let squatStack = UIStackView(arrangedSubviews: [squatTitle, dailySquatLabel])
        squatStack.axis = .vertical
        squatStack.alignment = .center
        squatStack.spacing = 4
        squatStack.translatesAutoresizingMaskIntoConstraints = false
        squatStack.isUserInteractionEnabled = false
        
        let pushUpTitle = UILabel()
        pushUpTitle.text = "푸쉬업"
        pushUpTitle.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        pushUpTitle.textColor = .lightGray
        pushUpTitle.textAlignment = .center
        pushUpTitle.isUserInteractionEnabled = false
        
        dailyPushUpLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        dailyPushUpLabel.textColor = .white
        dailyPushUpLabel.textAlignment = .center
        
        let pushUpStack = UIStackView(arrangedSubviews: [pushUpTitle, dailyPushUpLabel])
        pushUpStack.axis = .vertical
        pushUpStack.alignment = .center
        pushUpStack.spacing = 4
        pushUpStack.translatesAutoresizingMaskIntoConstraints = false
        pushUpStack.isUserInteractionEnabled = false
        
        let pullUpTitle = UILabel()
        pullUpTitle.text = "턱걸이"
        pullUpTitle.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        pullUpTitle.textColor = .lightGray
        pullUpTitle.textAlignment = .center
        pullUpTitle.isUserInteractionEnabled = false
        
        dailyPullUpLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        dailyPullUpLabel.textColor = .white
        dailyPullUpLabel.textAlignment = .center
        
        let pullUpStack = UIStackView(arrangedSubviews: [pullUpTitle, dailyPullUpLabel])
        pullUpStack.axis = .vertical
        pullUpStack.alignment = .center
        pullUpStack.spacing = 4
        pullUpStack.translatesAutoresizingMaskIntoConstraints = false
        pullUpStack.isUserInteractionEnabled = false
        
        let bottomStatsRow = UIStackView(arrangedSubviews: [squatStack, pushUpStack, pullUpStack])
        bottomStatsRow.axis = .horizontal
        bottomStatsRow.distribution = .fillEqually
        bottomStatsRow.spacing = 20
        bottomStatsRow.alignment = .center
        bottomStatsRow.translatesAutoresizingMaskIntoConstraints = false
        bottomStatsRow.isUserInteractionEnabled = false
        
        let mainStack = UIStackView(arrangedSubviews: [topStatsRow, bottomStatsRow])
        mainStack.axis = .vertical
        mainStack.spacing = 10
        mainStack.alignment = .fill
        mainStack.setCustomSpacing(20, after: topStatsRow)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.isUserInteractionEnabled = false
        
        container.addSubview(headerStack)
        container.addSubview(separatorView)
        container.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            headerStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            headerStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            headerStack.heightAnchor.constraint(equalToConstant: 20),
            
            separatorView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 4),
            separatorView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 1),
            
            mainStack.topAnchor.constraint(equalTo: separatorView.bottomAnchor, constant: 18),
            mainStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            mainStack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -10)
        ])
    }
    
    // MARK: - Monthly Statistics UI
    func setupMonthlyStatsUI(in container: UIButton) {
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1)
        container.layer.cornerRadius = 20
        container.clipsToBounds = true
        
        let chartViewLabel = UILabel()
        chartViewLabel.text = "월별 통계"
        chartViewLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        chartViewLabel.textColor = .white
        chartViewLabel.translatesAutoresizingMaskIntoConstraints = false
        chartViewLabel.isUserInteractionEnabled = false
        
        let chevronImageView = UIImageView()
        chevronImageView.image = UIImage(systemName: "chevron.right")
        chevronImageView.tintColor = .systemBlue
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        chevronImageView.contentMode = .scaleAspectFit
        chevronImageView.setContentHuggingPriority(.required, for: .horizontal)
        chevronImageView.isUserInteractionEnabled = false
        
        NSLayoutConstraint.activate([
            chevronImageView.widthAnchor.constraint(equalToConstant: 16),
            chevronImageView.heightAnchor.constraint(equalToConstant: 16)
        ])
        
        let headerStack = UIStackView(arrangedSubviews: [chartViewLabel, chevronImageView])
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.distribution = .fill
        headerStack.spacing = 2
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.isUserInteractionEnabled = false
        
        let separatorView = UIView()
        separatorView.backgroundColor = UIColor.lightGray.withAlphaComponent(0.3)
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        separatorView.heightAnchor.constraint(equalToConstant: 1).isActive = true
        separatorView.isUserInteractionEnabled = false
        
        let daysLabelTitle = UILabel()
        daysLabelTitle.text = "운동 일수"
        daysLabelTitle.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        daysLabelTitle.textColor = .lightGray
        daysLabelTitle.textAlignment = .center
        daysLabelTitle.translatesAutoresizingMaskIntoConstraints = false
        daysLabelTitle.isUserInteractionEnabled = false
        
        let daysLabelValue = exerciseDaysLabel
        daysLabelValue.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        daysLabelValue.textColor = .white
        daysLabelValue.textAlignment = .center
        daysLabelValue.isUserInteractionEnabled = false
        
        let daysStack = UIStackView(arrangedSubviews: [daysLabelTitle, daysLabelValue])
        daysStack.axis = .vertical
        daysStack.alignment = .center
        daysStack.spacing = 4
        daysStack.translatesAutoresizingMaskIntoConstraints = false
        daysStack.isUserInteractionEnabled = false
        
        let timeLabelTitle = UILabel()
        timeLabelTitle.text = "운동 시간"
        timeLabelTitle.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        timeLabelTitle.textColor = .lightGray
        timeLabelTitle.textAlignment = .center
        timeLabelTitle.translatesAutoresizingMaskIntoConstraints = false
        timeLabelTitle.isUserInteractionEnabled = false
        
        let timeLabelValue = exerciseTimeLabel
        timeLabelValue.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        timeLabelValue.textColor = .white
        timeLabelValue.textAlignment = .center
        timeLabelValue.isUserInteractionEnabled = false
        
        let timeStack = UIStackView(arrangedSubviews: [timeLabelTitle, timeLabelValue])
        timeStack.axis = .vertical
        timeStack.alignment = .center
        timeStack.spacing = 4
        timeStack.translatesAutoresizingMaskIntoConstraints = false
        timeStack.isUserInteractionEnabled = false
        
        let caloriesLabelTitle = UILabel()
        caloriesLabelTitle.text = "칼로리"
        caloriesLabelTitle.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        caloriesLabelTitle.textColor = .lightGray
        caloriesLabelTitle.textAlignment = .center
        caloriesLabelTitle.translatesAutoresizingMaskIntoConstraints = false
        caloriesLabelTitle.isUserInteractionEnabled = false
        
        let caloriesLabelValue = caloriesLabel
        caloriesLabelValue.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        caloriesLabelValue.textColor = .white
        caloriesLabelValue.textAlignment = .center
        caloriesLabelValue.isUserInteractionEnabled = false
        
        let caloriesStack = UIStackView(arrangedSubviews: [caloriesLabelTitle, caloriesLabelValue])
        caloriesStack.axis = .vertical
        caloriesStack.alignment = .center
        caloriesStack.spacing = 4
        caloriesStack.translatesAutoresizingMaskIntoConstraints = false
        caloriesStack.isUserInteractionEnabled = false
        
        let topStatsRow = UIStackView(arrangedSubviews: [daysStack, timeStack, caloriesStack])
        topStatsRow.axis = .horizontal
        topStatsRow.distribution = .fillEqually
        topStatsRow.spacing = 20
        topStatsRow.alignment = .center
        topStatsRow.translatesAutoresizingMaskIntoConstraints = false
        topStatsRow.isUserInteractionEnabled = false
        
        let squatLabelTitle = UILabel()
        squatLabelTitle.text = "스쿼트"
        squatLabelTitle.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        squatLabelTitle.textColor = .lightGray
        squatLabelTitle.textAlignment = .center
        squatLabelTitle.isUserInteractionEnabled = false
        
        let squatLabelValue = squatLabel
        squatLabelValue.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        squatLabelValue.textColor = .white
        squatLabelValue.textAlignment = .center
        squatLabelValue.isUserInteractionEnabled = false
        
        let squatStack = UIStackView(arrangedSubviews: [squatLabelTitle, squatLabelValue])
        squatStack.axis = .vertical
        squatStack.alignment = .center
        squatStack.spacing = 4
        squatStack.translatesAutoresizingMaskIntoConstraints = false
        squatStack.isUserInteractionEnabled = false
        
        let pushUpLabelTitle = UILabel()
        pushUpLabelTitle.text = "푸쉬업"
        pushUpLabelTitle.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        pushUpLabelTitle.textColor = .lightGray
        pushUpLabelTitle.textAlignment = .center
        pushUpLabelTitle.isUserInteractionEnabled = false
        
        let pushUpLabelValue = pushUpLabel
        pushUpLabelValue.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        pushUpLabelValue.textColor = .white
        pushUpLabelValue.textAlignment = .center
        pushUpLabelValue.isUserInteractionEnabled = false
        
        let pushUpStack = UIStackView(arrangedSubviews: [pushUpLabelTitle, pushUpLabelValue])
        pushUpStack.axis = .vertical
        pushUpStack.alignment = .center
        pushUpStack.spacing = 4
        pushUpStack.translatesAutoresizingMaskIntoConstraints = false
        pushUpStack.isUserInteractionEnabled = false
        
        let pullUpLabelTitle = UILabel()
        pullUpLabelTitle.text = "턱걸이"
        pullUpLabelTitle.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        pullUpLabelTitle.textColor = .lightGray
        pullUpLabelTitle.textAlignment = .center
        pullUpLabelTitle.isUserInteractionEnabled = false
        
        let pullUpLabelValue = pullUpLabel
        pullUpLabelValue.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        pullUpLabelValue.textColor = .white
        pullUpLabelValue.textAlignment = .center
        pullUpLabelValue.isUserInteractionEnabled = false
        
        let pullUpStack = UIStackView(arrangedSubviews: [pullUpLabelTitle, pullUpLabelValue])
        pullUpStack.axis = .vertical
        pullUpStack.alignment = .center
        pullUpStack.spacing = 4
        pullUpStack.translatesAutoresizingMaskIntoConstraints = false
        pullUpStack.isUserInteractionEnabled = false
        
        let bottomStatsRow = UIStackView(arrangedSubviews: [squatStack, pushUpStack, pullUpStack])
        bottomStatsRow.axis = .horizontal
        bottomStatsRow.distribution = .fillEqually
        bottomStatsRow.spacing = 20
        bottomStatsRow.alignment = .center
        bottomStatsRow.translatesAutoresizingMaskIntoConstraints = false
        bottomStatsRow.isUserInteractionEnabled = false
        
        let mainStack = UIStackView(arrangedSubviews: [topStatsRow, bottomStatsRow])
        mainStack.axis = .vertical
        mainStack.spacing = 10
        mainStack.alignment = .fill
        mainStack.setCustomSpacing(20, after: topStatsRow)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.isUserInteractionEnabled = false
        
        container.addSubview(headerStack)
        container.addSubview(separatorView)
        container.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            headerStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            headerStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            headerStack.heightAnchor.constraint(equalToConstant: 20),
            
            separatorView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 4),
            separatorView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 1),
            
            mainStack.topAnchor.constraint(equalTo: separatorView.bottomAnchor, constant: 18),
            mainStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            mainStack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -10)
        ])
    }
    
    // MARK: - TableView Setup & Header
    func setupTableViewContainer() {
        tableViewContainer.translatesAutoresizingMaskIntoConstraints = false
        tableViewContainer.backgroundColor = UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1)
        tableViewContainer.layer.cornerRadius = 20
        tableViewContainer.layer.masksToBounds = true
        contentView.addSubview(tableViewContainer)
        
        setupTableViewHeader()
        tableViewContainer.addSubview(tableViewHeaderView)
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ExerciseCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        
        NSLayoutConstraint.activate([
            tableViewContainer.topAnchor.constraint(equalTo: statsScrollView.bottomAnchor, constant: 15),
            tableViewContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            tableViewContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            tableViewContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            tableViewContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 300)
        ])
        
        tableViewContainer.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableViewHeaderView.topAnchor.constraint(equalTo: tableViewContainer.topAnchor),
            tableViewHeaderView.leadingAnchor.constraint(equalTo: tableViewContainer.leadingAnchor),
            tableViewHeaderView.trailingAnchor.constraint(equalTo: tableViewContainer.trailingAnchor),
            tableViewHeaderView.heightAnchor.constraint(equalToConstant: 50),
            
            tableView.topAnchor.constraint(equalTo: tableViewHeaderView.bottomAnchor, constant: -10),
            tableView.leadingAnchor.constraint(equalTo: tableViewContainer.leadingAnchor, constant: 10),
            tableView.trailingAnchor.constraint(equalTo: tableViewContainer.trailingAnchor, constant: -10),
            tableView.bottomAnchor.constraint(equalTo: tableViewContainer.bottomAnchor, constant: -10)
        ])
    }
    
    func setupTableViewHeader() {
        tableViewHeaderView.backgroundColor = UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1)
        tableViewHeaderView.translatesAutoresizingMaskIntoConstraints = false
        
        recordLabel.text = "기록"
        recordLabel.font = UIFont.systemFont(ofSize: 14)
        recordLabel.textColor = .white
        recordLabel.translatesAutoresizingMaskIntoConstraints = false
        
        sortButton.setTitle("시간 내림차순", for: .normal)
        sortButton.setImage(UIImage(systemName: "arrow.up.arrow.down"), for: .normal)
        sortButton.setTitleColor(.systemBlue, for: .normal)
        sortButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        sortButton.translatesAutoresizingMaskIntoConstraints = false
        sortButton.addTarget(self, action: #selector(toggleSortOrder), for: .touchUpInside)
        sortButton.tintColor = .systemBlue
        sortButton.semanticContentAttribute = .forceRightToLeft
        
        sortSeparatorView.backgroundColor = UIColor.lightGray.withAlphaComponent(0.3)
        sortSeparatorView.translatesAutoresizingMaskIntoConstraints = false
        sortSeparatorView.heightAnchor.constraint(equalToConstant: 1).isActive = true
        
        let headerStack = UIStackView(arrangedSubviews: [recordLabel, sortButton])
        headerStack.axis = .horizontal
        headerStack.distribution = .equalSpacing
        headerStack.alignment = .center
        headerStack.spacing = 10
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.isLayoutMarginsRelativeArrangement = true
        headerStack.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: -10)
        
        tableViewHeaderView.addSubview(headerStack)
        tableViewHeaderView.addSubview(sortSeparatorView)
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: tableViewHeaderView.topAnchor, constant: 10),
            headerStack.leadingAnchor.constraint(equalTo: tableViewHeaderView.leadingAnchor, constant: 20),
            headerStack.trailingAnchor.constraint(equalTo: tableViewHeaderView.trailingAnchor, constant: -20),
            
            sortSeparatorView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 5),
            sortSeparatorView.leadingAnchor.constraint(equalTo: tableViewHeaderView.leadingAnchor),
            sortSeparatorView.trailingAnchor.constraint(equalTo: tableViewHeaderView.trailingAnchor),
            sortSeparatorView.heightAnchor.constraint(equalToConstant: 1)
        ])
    }
    
    // MARK: - Data Processing & Statistics Updates
    func loadExerciseRecords() {
        allExerciseRecords = UserDefaults.standard.array(forKey: "exerciseSummaries") as? [[String: Any]] ?? []
    }
    
    // MARK: - Date Comparison Helper (Helper Methods 영역에 포함)
    func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        return Calendar.current.isDate(date1, inSameDayAs: date2)
    }

    // MARK: - Data Processing & Statistics Updates
    func filterRecords(by date: Date? = nil, exerciseType: String? = nil) {
        filteredRecords = allExerciseRecords.filter { record in
            var dateMatch = true
            var typeMatch = true
            
            if let date = date {
                guard let recDate = record["date"] as? Date else { return false }
                dateMatch = isSameDay(recDate, date)
            }
            if let type = exerciseType {
                typeMatch = ((record["exerciseType"] as? String)?.lowercased() == type.lowercased())
            }
            return dateMatch && typeMatch
        }
        
        filteredRecords.sort { record1, record2 in
            guard let d1 = record1["date"] as? Date, let d2 = record2["date"] as? Date else { return false }
            return isDescendingOrder ? (d1 > d2) : (d1 < d2)
        }
        
        if filteredRecords.isEmpty {
            let lbl = UILabel()
            lbl.text = "기록 없음"
            lbl.textColor = .lightGray
            lbl.textAlignment = .center
            lbl.font = UIFont.systemFont(ofSize: 18, weight: .medium)
            tableView.backgroundView = lbl
        } else {
            tableView.backgroundView = nil
        }
        recordLabel.text = "기록 (\(filteredRecords.count))"
        tableView.reloadData()
    }
    
    func updateDailyStatistics(for date: Date) {
        let today = Calendar.current.startOfDay(for: Date())
        let targetDay = Calendar.current.startOfDay(for: date)
        
        if targetDay > today {
            dailyTotalRepsLabel.text = "N/A"
            dailyExerciseTimeLabel.text = "N/A"
            dailyCaloriesLabel.text = "N/A"
            dailySquatLabel.text = "N/A"
            dailyPushUpLabel.text = "N/A"
            dailyPullUpLabel.text = "N/A"
            return
        }
        
        let dailyRecords = allExerciseRecords.filter { record in
            guard let recDate = record["date"] as? Date else { return false }
            return Calendar.current.isDate(recDate, inSameDayAs: date)
        }
        
        if dailyRecords.isEmpty {
            dailyTotalRepsLabel.text = "0"
            dailyExerciseTimeLabel.text = "0:00:00"
            dailyCaloriesLabel.text = "0.00 kcal"
            dailySquatLabel.text = "0회"
            dailyPushUpLabel.text = "0회"
            dailyPullUpLabel.text = "0회"
            return
        }
        
        let totalReps = dailyRecords.reduce(0) { $0 + (( $1["reps"] as? Int) ?? 0) }
        dailyTotalRepsLabel.text = "\(totalReps)"
        
        let totalDurationSeconds = dailyRecords.reduce(0.0) { $0 + (( $1["duration"] as? Double) ?? 0.0) }
        dailyExerciseTimeLabel.text = formatDuration(totalDurationSeconds)
        
        let totalCalories = dailyRecords.reduce(0.0) { $0 + (( $1["calories"] as? Double) ?? 0.0) }
        dailyCaloriesLabel.text = String(format: "%.2f kcal", totalCalories)
        
        let squatReps = dailyRecords.filter { $0["exerciseType"] as? String == "스쿼트" }
            .reduce(0) { $0 + (( $1["reps"] as? Int) ?? 0) }
        let pushUpReps = dailyRecords.filter { $0["exerciseType"] as? String == "푸쉬업" }
            .reduce(0) { $0 + (( $1["reps"] as? Int) ?? 0) }
        let pullUpReps = dailyRecords.filter { $0["exerciseType"] as? String == "턱걸이" }
            .reduce(0) { $0 + (( $1["reps"] as? Int) ?? 0) }
        
        dailySquatLabel.text = "\(squatReps)회"
        dailyPushUpLabel.text = "\(pushUpReps)회"
        dailyPullUpLabel.text = "\(pullUpReps)회"
    }
    
    func updateMonthlyStatistics(for date: Date) {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: date)
        
        guard let year = comps.year, let month = comps.month else {
            setStatisticsToN_A()
            return
        }
        
        var startComps = DateComponents()
        startComps.year = year
        startComps.month = month
        startComps.day = 1
        
        guard let firstDay = cal.date(from: startComps),
              let lastDay = cal.date(byAdding: DateComponents(month: 1, day: -1), to: firstDay) else {
            setStatisticsToN_A()
            return
        }
        
        let monthlyRecords = allExerciseRecords.filter { record in
            guard let recDate = record["date"] as? Date else { return false }
            return (recDate >= firstDay && recDate <= lastDay)
        }
        
        if monthlyRecords.isEmpty {
            setStatisticsToN_A()
            return
        }
        
        let exerciseDays = Set(monthlyRecords.compactMap { record -> Date? in
            guard let recDate = record["date"] as? Date else { return nil }
            return cal.startOfDay(for: recDate)
        }).count
        
        let totalDurationSeconds = monthlyRecords.reduce(0.0) { $0 + (( $1["duration"] as? Double) ?? 0.0) }
        let formattedDuration = formatDuration(totalDurationSeconds)
        
        let totalCalories = monthlyRecords.reduce(0.0) { $0 + (( $1["calories"] as? Double) ?? 0.0) }
        
        let squatTotalReps = monthlyRecords.filter { $0["exerciseType"] as? String == "스쿼트" }
            .reduce(0) { $0 + (( $1["reps"] as? Int) ?? 0) }
        let pushUpTotalReps = monthlyRecords.filter { $0["exerciseType"] as? String == "푸쉬업" }
            .reduce(0) { $0 + (( $1["reps"] as? Int) ?? 0) }
        let pullUpTotalReps = monthlyRecords.filter { $0["exerciseType"] as? String == "턱걸이" }
            .reduce(0) { $0 + (( $1["reps"] as? Int) ?? 0) }
        
        exerciseDaysLabel.text = "\(exerciseDays)일"
        exerciseTimeLabel.text = formattedDuration
        caloriesLabel.text = String(format: "%.2f kcal", totalCalories)
        
        squatLabel.text = "\(squatTotalReps)회"
        pushUpLabel.text = "\(pushUpTotalReps)회"
        pullUpLabel.text = "\(pullUpTotalReps)회"
    }
    
    func setStatisticsToN_A() {
        exerciseDaysLabel.text = "N/A"
        exerciseTimeLabel.text = "N/A"
        caloriesLabel.text = "N/A"
        squatLabel.text = "N/A"
        pushUpLabel.text = "N/A"
        pullUpLabel.text = "N/A"
    }
    
    // MARK: - Helper Methods

    func formatDateForTableView(_ date: Date) -> String {
        let formatter = DateFormatter.cachedFormatter(format: "HH:mm")
        return formatter.string(from: date)
    }

    func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter.cachedFormatter(format: "yyyy년 M월 d일 HH:mm")
        return formatter.string(from: date)
    }

    func formatDuration(_ durationSeconds: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: durationSeconds) ?? "0:00:00"
    }
    
    // MARK: - User Interaction (Gesture & Alerts)
    func setupTapGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    func showAlert(title: String, message: String) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "확인", style: .default))
        present(ac, animated: true)
    }
    
    func animateSortButton() {
        UIView.animate(withDuration: 0.15,
                       delay: 0,
                       usingSpringWithDamping: 0.3,
                       initialSpringVelocity: 5,
                       options: [],
                       animations: {
            self.sortButton.imageView?.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { _ in
            UIView.animate(withDuration: 0.15,
                           delay: 0,
                           usingSpringWithDamping: 0.5,
                           initialSpringVelocity: 5,
                           options: [],
                           animations: {
                self.sortButton.imageView?.transform = .identity
            }, completion: nil)
        }
    }

    @objc func toggleSortOrder() {
        isDescendingOrder.toggle()
        let title = isDescendingOrder ? "시간 내림차순" : "시간 오름차순"
        sortButton.setTitle(title, for: .normal)
        
        animateSortButton()  // 별도 함수 호출
        
        filteredRecords.sort {
            guard let d1 = $0["date"] as? Date, let d2 = $1["date"] as? Date else { return false }
            return isDescendingOrder ? (d1 > d2) : (d1 < d2)
        }
        tableView.reloadData()
    }
    
    @objc func statisticsButtonTapped(_ sender: UIButton) {
        // 상세 통계 화면으로 전달할 스토리보드 VC 가져오기
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let detailVC = storyboard
                .instantiateViewController(withIdentifier: "MonthlyDetailViewController")
                    as? MonthlyDetailViewController else {
            showAlert(title: "오류", message: "통계 상세 화면을 불러올 수 없습니다.")
            return
        }

        // 선택된 날짜가 없으면 default = 오늘
        detailVC.selectedDate = calendar.selectedDate ?? Date()
        // 월간 차트에 쓰일 현재 달 정보도 전달
        detailVC.currentMonth = calendar.currentPage

        // 일별 버튼(좌측) → 일차트(0), 월별 버튼(우측) → 월차트(3)
        detailVC.initialSegmentIndex = (sender === dailyStatsButton) ? 0 : 2

        // 네비게이션 컨트롤러에 통계 VC를 담아 모달로 표시 → 뒤로 버튼 활성
        let nav = UINavigationController(rootViewController: detailVC)
        nav.isNavigationBarHidden = false
        nav.modalPresentationStyle = .custom
        nav.transitioningDelegate  = self
        present(nav, animated: true, completion: nil)
    }
    
    // MARK: - FSCalendarDataSource & Delegate Methods
    func calendar(_ calendar: FSCalendar, numberOfEventsFor date: Date) -> Int {
        let matching = allExerciseRecords.filter {
            guard let recDate = $0["date"] as? Date else { return false }
            return Calendar.current.isDate(recDate, inSameDayAs: date)
        }.compactMap { $0["exerciseType"] as? String }
        
        return Set(matching).count
    }
    
    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        if monthPosition != .current {
            calendar.setCurrentPage(date, animated: true)
        }
        filterRecords(by: date)
        updateMonthlyStatistics(for: calendar.currentPage)
        updateDailyStatistics(for: date)
        updateCalendarHeaderTitle(for: calendar.currentPage)
    }
    
    func calendar(_ calendar: FSCalendar,
                  appearance: FSCalendarAppearance,
                  fillDefaultColorFor date: Date) -> UIColor? {
        return Calendar.current.isDateInToday(date) ? .systemBlue : nil
    }
    
    func calendar(_ calendar: FSCalendar,
                  appearance: FSCalendarAppearance,
                  titleTodayColorFor date: Date) -> UIColor? {
        return .white
    }
    
    func calendar(_ calendar: FSCalendar,
                  appearance: FSCalendarAppearance,
                  fillSelectionColorFor date: Date) -> UIColor? {
        return Calendar.current.isDateInToday(date) ? .systemBlue : .white
    }
    
    func calendar(_ calendar: FSCalendar,
                  appearance: FSCalendarAppearance,
                  titleSelectionColorFor date: Date) -> UIColor? {
        return Calendar.current.isDateInToday(date) ? .white : .black
    }
    
    func calendar(_ calendar: FSCalendar,
                  appearance: FSCalendarAppearance,
                  eventDefaultColorsFor date: Date) -> [UIColor]? {
        return getEventColors(for: date)
    }
    
    func calendar(_ calendar: FSCalendar,
                  appearance: FSCalendarAppearance,
                  eventSelectionColorsFor date: Date) -> [UIColor]? {
        return getEventColors(for: date)
    }
    
    func calendarCurrentPageDidChange(_ calendar: FSCalendar) {
        updateMonthlyStatistics(for: calendar.currentPage)
        updateCalendarHeaderTitle(for: calendar.currentPage)
        calendar.reloadData()
    }
    
    func getEventColors(for date: Date) -> [UIColor]? {
        let records = allExerciseRecords.filter {
            guard let recDate = $0["date"] as? Date else { return false }
            return Calendar.current.isDate(recDate, inSameDayAs: date)
        }
        var colors: [UIColor] = []
        if records.contains(where: { $0["exerciseType"] as? String == "스쿼트" }) {
            colors.append(.systemGreen)
        }
        if records.contains(where: { $0["exerciseType"] as? String == "푸쉬업" }) {
            colors.append(.systemBlue)
        }
        if records.contains(where: { $0["exerciseType"] as? String == "턱걸이" }) {
            colors.append(.systemPurple)
        }
        return colors.isEmpty ? nil : colors
    }
    
    // MARK: - TableView DataSource & Delegate Methods
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredRecords.count
    }
    
    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ExerciseCell", for: indexPath)
        let record = filteredRecords[indexPath.row]
        
        let exerciseType = record["exerciseType"] as? String ?? "알 수 없음"
        let reps = record["reps"] as? Int ?? 0
        let sets = record["sets"] as? Int ?? 0
        let exerciseEndDate = record["date"] as? Date ?? Date()
        let formattedDateTime = formatDateForTableView(exerciseEndDate)
        
        cell.textLabel?.text = "\(exerciseType): \(reps)회 / \(sets)세트 / \(formattedDateTime)"
        cell.textLabel?.textColor = .white
        cell.backgroundColor = .clear
        cell.accessoryType = .disclosureIndicator
        
        var iconName = "figure.walk"
        var tintCol = UIColor.systemGreen
        switch exerciseType {
        case "스쿼트":
            iconName = "figure.cross.training"
            tintCol = .systemGreen
        case "푸쉬업":
            iconName = "figure.wrestling"
            tintCol = .systemBlue
        case "턱걸이":
            iconName = "figure.play"
            tintCol = .systemPurple
        default:
            iconName = "figure.walk"
            tintCol = .systemGreen
        }
        
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        cell.imageView?.image = UIImage(systemName: iconName, withConfiguration: symbolConfig)
        cell.imageView?.tintColor = tintCol
        
        let bg = UIView()
        bg.backgroundColor = UIColor.darkGray.withAlphaComponent(0.5)
        cell.selectedBackgroundView = bg
        return cell
    }
    
    func tableView(_ tableView: UITableView,
                   didSelectRowAt indexPath: IndexPath) {
        let record = filteredRecords[indexPath.row]
        showExerciseSummaryModal(record: record)
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
      -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive,
                                              title: "삭제") { _, _, completion in
            self.deleteExerciseRecord(at: indexPath)
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
    
    func deleteExerciseRecord(at indexPath: IndexPath) {
        let recordToDelete = filteredRecords[indexPath.row]
        
        if let idx = allExerciseRecords.firstIndex(where: {
            guard let d1 = $0["date"] as? Date,
                  let d2 = recordToDelete["date"] as? Date,
                  let t1 = $0["exerciseType"] as? String,
                  let t2 = recordToDelete["exerciseType"] as? String else { return false }
            return (d1 == d2 && t1 == t2)
        }) {
            allExerciseRecords.remove(at: idx)
        }
        filteredRecords.remove(at: indexPath.row)
        UserDefaults.standard.set(allExerciseRecords, forKey: "exerciseSummaries")
        
        tableView.deleteRows(at: [indexPath], with: .automatic)
        
        if filteredRecords.isEmpty {
            let lbl = UILabel()
            lbl.text = "기록 없음"
            lbl.textColor = .lightGray
            lbl.textAlignment = .center
            lbl.font = UIFont.systemFont(ofSize: 18, weight: .medium)
            tableView.backgroundView = lbl
        } else {
            tableView.backgroundView = nil
        }
        
        // 여기서 기록 개수 업데이트
        recordLabel.text = "기록 (\(filteredRecords.count))"
        tableView.reloadData()
        
        calendar.reloadData()
        updateMonthlyStatistics(for: calendar.currentPage)
    }
    
    func showExerciseSummaryModal(record: [String: Any]) {
        let summaryVC = ExerciseRecordSummaryViewController()
        summaryVC.record = record
        present(summaryVC, animated: true)
    }
}

// MARK: - UISearchBarDelegate
extension StatisticsViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let searchText = searchBar.text else { return }
        parseAndSearch(query: searchText)
        searchBar.resignFirstResponder()
        navigationItem.titleView = nil
        setupNavigationBar()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        navigationItem.titleView = nil
        setupNavigationBar()
    }
    
    func parseAndSearch(query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            calendar.selectedDates.forEach { calendar.deselect($0) }
            filterRecords(by: nil, exerciseType: trimmedQuery)
            updateMonthlyStatistics(for: calendar.currentPage)
        }
    }
}

// MARK: - DatePickerModalViewControllerDelegate
extension StatisticsViewController: DatePickerModalViewControllerDelegate {
    func datePickerModalViewController(_ controller: DatePickerModalViewController, didSelect date: Date) {
        calendar.select(date)
        calendar.setCurrentPage(date, animated: true)
        updateMonthlyStatistics(for: date)
        filterRecords(by: date)
        updateDailyStatistics(for: date)
        updateCalendarHeaderTitle(for: date)
    }
}

// MARK: - UIViewControllerTransitioningDelegate
extension StatisticsViewController: UIViewControllerTransitioningDelegate {
    func animationController(forPresented presented: UIViewController,
                             presenting: UIViewController,
                             source: UIViewController)
      -> UIViewControllerAnimatedTransitioning? {
        return SlideInTransitionAnimator()
    }
    
    func animationController(forDismissed dismissed: UIViewController)
      -> UIViewControllerAnimatedTransitioning? {
        return SlideOutTransitionAnimator()
    }
}

// MARK: - Transition Animators
class SlideInTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    let duration = 0.3
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return duration
    }
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let toView = transitionContext.view(forKey: .to),
              let toVC = transitionContext.viewController(forKey: .to) else { return }
        let container = transitionContext.containerView
        let finalFrame = transitionContext.finalFrame(for: toVC)
        
        toView.frame = finalFrame.offsetBy(dx: finalFrame.width, dy: 0)
        container.addSubview(toView)
        
        UIView.animate(withDuration: duration, animations: {
            toView.frame = finalFrame
        }, completion: { finished in
            transitionContext.completeTransition(finished)
        })
    }
}

class SlideOutTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    let duration = 0.3
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return duration
    }
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let fromView = transitionContext.view(forKey: .from) else { return }
        
        let initialFrame = fromView.frame
        let finalFrame = initialFrame.offsetBy(dx: initialFrame.width, dy: 0)
        
        UIView.animate(withDuration: duration, animations: {
            fromView.frame = finalFrame
        }, completion: { finished in
            transitionContext.completeTransition(finished)
        })
    }
}

// MARK: - UIScrollViewDelegate
extension StatisticsViewController: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // statsScrollView일 때만 실행
        guard scrollView == statsScrollView else { return }
        
        let pageWidth = scrollView.bounds.width
        let centerOffsetX = scrollView.contentOffset.x + pageWidth / 2
        
        let dailyCenterX = pageWidth * 0.5
        let dailyDistance = abs(centerOffsetX - dailyCenterX)
        let dailyRatio = dailyDistance / pageWidth
        let dailyScale = 1.0 - min(dailyRatio, 1.0) * 0.2
        dailyStatsButton.transform = CGAffineTransform(scaleX: dailyScale, y: dailyScale)
        
        let monthlyCenterX = pageWidth * 1.5
        let monthlyDistance = abs(centerOffsetX - monthlyCenterX)
        let monthlyRatio = monthlyDistance / pageWidth
        let monthlyScale = 1.0 - min(monthlyRatio, 1.0) * 0.2
        monthlyStatsButton.transform = CGAffineTransform(scaleX: monthlyScale, y: monthlyScale)
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView,
                                   withVelocity velocity: CGPoint,
                                   targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        let pageWidth = scrollView.bounds.width
        let pageIndex = round(targetContentOffset.pointee.x / pageWidth)
        targetContentOffset.pointee.x = pageIndex * pageWidth
        
        statsPageControl.currentPage = Int(pageIndex)
        UserDefaults.standard.set(Int(pageIndex), forKey: kStatsPageIndexKey)
    }
}
