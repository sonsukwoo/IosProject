import UIKit
import UserNotifications

private let defaultReminderMessage = "오늘 목표를 완료해보세요 💪"

// MARK: - Reminder 모델
struct Reminder: Codable {
    var hour: Int
    var minute: Int
    var enabled: Bool
    var message: String
}

// MARK: - ReminderListViewController
class ReminderListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private var tableView: UITableView!
    private var reminders: [Reminder] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.title = "리마인더 관리"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add,
                                                            target: self,
                                                            action: #selector(addReminder))

        tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        loadReminders()
    }

    // MARK: - Data Persistence
    private func loadReminders() {
        if let data = UserDefaults.standard.data(forKey: "reminders"),
           let saved = try? JSONDecoder().decode([Reminder].self, from: data) {
            reminders = saved
        }
    }
    private func saveReminders() {
        if let data = try? JSONEncoder().encode(reminders) {
            UserDefaults.standard.set(data, forKey: "reminders")
        }
    }

    // MARK: - Add Reminder
    @objc private func addReminder() {
        let alert = UIAlertController(title: "새 알람 추가", message: nil, preferredStyle: .alert)
        let picker = UIDatePicker()
        picker.datePickerMode = .time
        picker.preferredDatePickerStyle = .wheels
        configurePickerAlert(alert, with: picker)

        alert.addTextField { tf in
            tf.placeholder = "알림 문구"
            tf.text = defaultReminderMessage
        }

        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "저장", style: .default) { _ in
            let comps = Calendar.current.dateComponents([.hour, .minute], from: picker.date)
            guard let hour = comps.hour, let minute = comps.minute else { return }
            let text = alert.textFields?.first?.text ?? ""
            let msg = text.isEmpty ? defaultReminderMessage : text
            let new = Reminder(hour: hour, minute: minute, enabled: true, message: msg)
            self.reminders.append(new)
            self.schedule(new)
            self.saveReminders()
            self.tableView.reloadData()
        })
        present(alert, animated: true)
    }

    // MARK: - Notification Scheduling
    private func schedule(_ reminder: Reminder) {
        let content = UNMutableNotificationContent()
        content.title = "운동 시간입니다!"
        content.body = reminder.message
        content.sound = UNNotificationSound.default

        var comps = DateComponents()
        comps.hour   = reminder.hour
        comps.minute = reminder.minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)

        let id = "reminder_\(reminder.hour)_\(reminder.minute)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    private func cancel(_ reminder: Reminder) {
        let id = "reminder_\(reminder.hour)_\(reminder.minute)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    // MARK: - TableView DataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        reminders.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let r = reminders[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = String(format: "%02d:%02d", r.hour, r.minute)
        let sw = UISwitch()
        sw.isOn = r.enabled
        sw.tag = indexPath.row
        sw.addTarget(self, action: #selector(switchChanged(_:)), for: .valueChanged)
        cell.accessoryView = sw
        return cell
    }

    @objc private func switchChanged(_ sender: UISwitch) {
        var r = reminders[sender.tag]
        r.enabled = sender.isOn
        reminders[sender.tag] = r
        if sender.isOn { schedule(r) } else { cancel(r) }
        saveReminders()
    }

    // MARK: - Deletion
    func tableView(_ tableView: UITableView,
                   commit editingStyle: UITableViewCell.EditingStyle,
                   forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let r = reminders.remove(at: indexPath.row)
            cancel(r)
            saveReminders()
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }

    // MARK: - Edit existing reminder
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let r = reminders[indexPath.row]
        let alert = UIAlertController(title: "알람 수정", message: nil, preferredStyle: .alert)
        // Time picker
        let picker = UIDatePicker()
        picker.datePickerMode = .time
        picker.preferredDatePickerStyle = .wheels
        // Set existing time
        if let date = Calendar.current.date(from: DateComponents(hour: r.hour, minute: r.minute)) {
            picker.date = date
        }
        configurePickerAlert(alert, with: picker)
        // Text field
        alert.addTextField { tf in
            tf.placeholder = "알림 문구"
            tf.text = r.message
        }
        alert.addAction(UIAlertAction(title: "취소", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "저장", style: .default) { _ in
            let comps = Calendar.current.dateComponents([.hour, .minute], from: picker.date)
            guard let h = comps.hour, let m = comps.minute else { return }
            let text = alert.textFields?.first?.text ?? ""
            let msg = text.isEmpty ? defaultReminderMessage : text
            // Cancel old, update model, schedule new
            self.cancel(r)
            let updated = Reminder(hour: h, minute: m, enabled: r.enabled, message: msg)
            self.reminders[indexPath.row] = updated
            if updated.enabled { self.schedule(updated) }
            self.saveReminders()
            self.tableView.reloadRows(at: [indexPath], with: .automatic)
        })
        present(alert, animated: true)
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    /// Configures the alert controller by adding the date picker with constraints and setting a fixed height
    private func configurePickerAlert(_ alert: UIAlertController, with picker: UIDatePicker) {
        picker.datePickerMode = .time
        picker.preferredDatePickerStyle = .wheels
        picker.translatesAutoresizingMaskIntoConstraints = false
        alert.view.addSubview(picker)
        NSLayoutConstraint.activate([
            picker.topAnchor.constraint(equalTo: alert.view.topAnchor, constant: 95),
            picker.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            picker.widthAnchor.constraint(equalToConstant: 250),
            picker.heightAnchor.constraint(equalToConstant: 150)
        ])
        alert.view.heightAnchor.constraint(equalToConstant: 290).isActive = true
    }
}
