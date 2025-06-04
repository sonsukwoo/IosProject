
import UIKit
import AVKit
import Photos
import AVFoundation

// MARK: - Helpers
private extension URL {
    /// 파일명에서 운동 종류(스쿼트, 푸쉬업, 턱걸이 등)를 추출
    var exerciseType: String {
        let name = deletingPathExtension().lastPathComponent
        return name.components(separatedBy: "_").first ?? "알 수 없음"
    }
}

class VideoGalleryViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    let tableView = UITableView()
    var videoURLs: [URL] = []
    var thumbnails: [URL: UIImage] = [:]
    
    // MARK: - Search Bar
    private var navSearchBar: UISearchBar?
    private var filteredVideoURLs: [URL] = []
    private var isFiltering: Bool {
        return navSearchBar?.isFirstResponder == true && !(navSearchBar?.text?.isEmpty ?? true)
    }
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd HH:mm"
        return f
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupTableView()
        loadVideoURLs()
        setupNavigationBar()
        
        // export 완료 시 갤러리 갱신을 위한 Notification 등록
        NotificationCenter.default.addObserver(self, selector: #selector(handleVideoExportCompleted), name: NSNotification.Name("VideoExportCompleted"), object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func setupNavigationBar() {
        // Left title label
        let leftSpacer = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        leftSpacer.width = 20
        let leftLabel = UILabel()
        leftLabel.text = "비디오"
        leftLabel.font = UIFont.systemFont(ofSize: 25, weight: .bold)
        leftLabel.textColor = .white
        let leftItem = UIBarButtonItem(customView: leftLabel)
        navigationItem.leftBarButtonItems = [leftSpacer, leftItem]

        // Right search button
        let searchButton = UIButton(type: .system)
        let image = UIImage(systemName: "magnifyingglass", withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .regular))
        searchButton.setImage(image, for: .normal)
        searchButton.tintColor = .systemBlue
        searchButton.addTarget(self, action: #selector(searchButtonTapped), for: .touchUpInside)
        let searchItem = UIBarButtonItem(customView: searchButton)
        navigationItem.rightBarButtonItems = [searchItem]
    }
    
    @objc func searchButtonTapped() {
        if navSearchBar == nil {
            navSearchBar = UISearchBar(frame: CGRect(x: 0, y: 0, width: view.frame.width - 40, height: 44))
            navSearchBar?.delegate = self
            navSearchBar?.placeholder = "비디오 검색"
            navSearchBar?.showsCancelButton = true
        }
        navigationItem.leftBarButtonItems = nil
        navigationItem.rightBarButtonItems = nil
        navigationItem.titleView = navSearchBar
        navSearchBar?.becomeFirstResponder()
    }
    
    func setupTableView() {
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(VideoCell.self, forCellReuseIdentifier: "VideoCell")
        tableView.backgroundColor = .black
        tableView.separatorColor = .darkGray
        // 스와이프 삭제를 위한 편집 모드 지원
        tableView.allowsMultipleSelectionDuringEditing = false
    }
    
    func loadVideoURLs() {
        let fm = FileManager.default
        guard let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let videosDir = docsURL.appendingPathComponent("Videos")
        
        if !fm.fileExists(atPath: videosDir.path) {
            try? fm.createDirectory(at: videosDir, withIntermediateDirectories: true, attributes: nil)
        }
        
        do {
            let files = try fm.contentsOfDirectory(at: videosDir, includingPropertiesForKeys: [.creationDateKey], options: [])
            videoURLs = files.filter {
                let ext = $0.pathExtension.lowercased()
                return ext == "mp4" || ext == "mov"
            }.sorted {
                let date1 = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 > date2
            }
            generateThumbnails()
            tableView.reloadData()
            updateEmptyMessage()
        } catch {
            print("영상 파일 로딩 오류: \(error)")
        }
    }
    
    func generateThumbnails() {
        thumbnails.removeAll()
        for url in videoURLs {
            let asset = AVAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            do {
                let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
                thumbnails[url] = UIImage(cgImage: cgImage)
            } catch {
                print("썸네일 생성 오류 for \(url): \(error)")
            }
        }
    }
    
    func updateEmptyMessage() {
        if videoURLs.isEmpty {
            let emptyLabel = UILabel()
            emptyLabel.text = "동영상 파일이 없습니다."
            emptyLabel.textColor = .white
            emptyLabel.textAlignment = .center
            emptyLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
            tableView.backgroundView = emptyLabel
        } else {
            tableView.backgroundView = nil
        }
    }

    // MARK: - Search
    private func applySearchFiltering(with rawQuery: String?) {
        let query = (rawQuery ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            filteredVideoURLs = videoURLs
            tableView.reloadData()
            return
        }
        filteredVideoURLs = videoURLs.filter { $0.exerciseType.lowercased().contains(query) }
        tableView.reloadData()
    }
    
    // MARK: - UITableViewDataSource & Delegate
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isFiltering ? filteredVideoURLs.count : videoURLs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "VideoCell", for: indexPath) as! VideoCell
        let currentList = isFiltering ? filteredVideoURLs : videoURLs
        let url = currentList[indexPath.row]
        let creationDate = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
        let dateString = dateFormatter.string(from: creationDate)
        let exerciseType = url.exerciseType
        cell.titleLabel.text = "\(exerciseType) (\(dateString))"
        cell.thumbnailImageView.image = thumbnails[url] ?? UIImage(systemName: "video")
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // 동영상 재생 기능
        tableView.deselectRow(at: indexPath, animated: true)
        let currentList = isFiltering ? filteredVideoURLs : videoURLs
        let videoURL = currentList[indexPath.row]
        let player = AVPlayer(url: videoURL)
        let playerVC = AVPlayerViewController()
        playerVC.player = player
        present(playerVC, animated: true) {
            player.play()
        }
    }
    
    // MARK: - 삭제 관련 기능
    
    // 스와이프 삭제 시 "삭제" 라고 표시하도록 버튼 타이틀 변경
    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        return "삭제"
    }
    
    // 스와이프 삭제 액션: 삭제하기 전 확인 팝업을 띄워 진짜 삭제할건지 물어봄
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle,
                   forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // 삭제 전 확인 Alert 표시
            let alert = UIAlertController(title: "삭제 확인", message: "삭제하시겠습니까?", preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: "취소", style: .cancel, handler: nil)
            let deleteAction = UIAlertAction(title: "삭제", style: .destructive) { _ in
                let urlToDelete = self.videoURLs[indexPath.row]
                do {
                    try FileManager.default.removeItem(at: urlToDelete)
                    self.videoURLs.remove(at: indexPath.row)
                    tableView.deleteRows(at: [indexPath], with: .automatic)
                    self.updateEmptyMessage()
                } catch {
                    print("개별 영상 삭제 오류: \(error)")
                }
            }
            alert.addAction(cancelAction)
            alert.addAction(deleteAction)
            present(alert, animated: true, completion: nil)
        }
    }
    
    // 선택 삭제 (버튼으로 호출)
    @objc func deleteSelectedVideo() {
        guard let indexPath = tableView.indexPathForSelectedRow else { return }
        let alert = UIAlertController(title: "삭제 확인", message: "정말 이 동영상을 삭제하시겠습니까?", preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "취소", style: .cancel, handler: nil)
        let deleteAction = UIAlertAction(title: "삭제", style: .destructive) { _ in
            let urlToDelete = self.videoURLs[indexPath.row]
            do {
                try FileManager.default.removeItem(at: urlToDelete)
                self.videoURLs.remove(at: indexPath.row)
                self.tableView.deleteRows(at: [indexPath], with: .automatic)
                self.updateEmptyMessage()
            } catch {
                print("영상 삭제 오류: \(error)")
            }
        }
        alert.addAction(cancelAction)
        alert.addAction(deleteAction)
        present(alert, animated: true, completion: nil)
    }
    
    // 전체 삭제 (앱 내 모든 동영상 삭제)
    @objc func deleteAllVideos() {
        let alert = UIAlertController(title: "전체 삭제 확인", message: "모든 동영상을 삭제하시겠습니까?", preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "취소", style: .cancel, handler: nil)
        let deleteAction = UIAlertAction(title: "삭제", style: .destructive) { _ in
            let fm = FileManager.default
            guard let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            let videosDir = docsURL.appendingPathComponent("Videos")
            do {
                let files = try fm.contentsOfDirectory(at: videosDir, includingPropertiesForKeys: nil, options: [])
                for file in files {
                    try fm.removeItem(at: file)
                }
                self.videoURLs.removeAll()
                self.tableView.reloadData()
                self.updateEmptyMessage()
            } catch {
                print("전체 삭제 오류: \(error)")
            }
        }
        alert.addAction(cancelAction)
        alert.addAction(deleteAction)
        present(alert, animated: true, completion: nil)
    }
    
    @objc func handleVideoExportCompleted() {
        loadVideoURLs()
    }
}

// MARK: - UISearchBarDelegate
extension VideoGalleryViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        applySearchFiltering(with: searchText)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        applySearchFiltering(with: searchBar.text)
        searchBar.resignFirstResponder()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        navigationItem.titleView = nil
        setupNavigationBar()
        filteredVideoURLs = videoURLs
        tableView.reloadData()
    }
}

// MARK: - VideoCell
class VideoCell: UITableViewCell {
    let thumbnailImageView = UIImageView()
    let titleLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .black
        
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        // 변경: scaleAspectFit 로 설정하여 썸네일 이미지가 전체 보여지도록 함.
        thumbnailImageView.contentMode = .scaleAspectFit
        thumbnailImageView.clipsToBounds = true
        thumbnailImageView.layer.cornerRadius = 6
        contentView.addSubview(thumbnailImageView)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        contentView.addSubview(titleLabel)
        
        // 썸네일 이미지 크기를 약간 조정하여 셀 안에 온전히 들어가도록 함.
        NSLayoutConstraint.activate([
            thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            thumbnailImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 60),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 45),
            
            titleLabel.leadingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
