import UIKit
import AVKit
import Photos

class VideoGalleryViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let tableView = UITableView()
    var videoURLs: [URL] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 전체 배경색을 검은색으로 설정
        view.backgroundColor = .black
      
        
        setupTableView()
        loadVideoURLs()
        setupNavigationBar()
    }
    
    func setupNavigationBar() {
        // 오른쪽 바 버튼을 통해 삭제 기능 등을 추가할 수 있음
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "삭제", style: .plain, target: self, action: #selector(deleteSelectedVideo))
        // 네비게이션 바 텍스트 및 버튼 색상을 흰색으로 설정
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
    }
    
    func setupTableView() {
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        // 오토레이아웃 제약조건으로 전체 화면 채우기
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "VideoCell")
        
        // 테이블 뷰 배경색과 구분선 색상 설정
        tableView.backgroundColor = .black
        tableView.separatorColor = .darkGray
    }
    
    func loadVideoURLs() {
        let fm = FileManager.default
        guard let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let videosDir = docsURL.appendingPathComponent("Videos")
        
        // "Videos" 폴더가 없으면 생성
        if !fm.fileExists(atPath: videosDir.path) {
            do {
                try fm.createDirectory(at: videosDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Videos 폴더 생성 오류: \(error)")
            }
        }
        
        do {
            let files = try fm.contentsOfDirectory(at: videosDir, includingPropertiesForKeys: nil, options: [])
            // .mp4 확장자만 필터링 (소문자로 비교)
            videoURLs = files.filter { $0.pathExtension.lowercased() == "mp4" }
            tableView.reloadData()
            updateEmptyMessage()
        } catch {
            print("영상 파일 로딩 오류: \(error)")
        }
    }
    
    // 동영상 파일이 없을 경우 메시지 라벨을 표시
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
    
    // MARK: - UITableViewDataSource Methods
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
         return videoURLs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
         let cell = tableView.dequeueReusableCell(withIdentifier: "VideoCell", for: indexPath)
         cell.textLabel?.text = videoURLs[indexPath.row].lastPathComponent
         cell.textLabel?.textColor = .white   // 셀 텍스트 색상을 흰색으로 설정
         cell.backgroundColor = .black
         return cell
    }
    
    // MARK: - UITableViewDelegate Methods
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
         tableView.deselectRow(at: indexPath, animated: true)
         let videoURL = videoURLs[indexPath.row]
         let player = AVPlayer(url: videoURL)
         let playerVC = AVPlayerViewController()
         playerVC.player = player
         present(playerVC, animated: true) {
              player.play()
         }
    }
    
    // MARK: - 삭제 기능 (선택된 동영상 삭제)
    @objc func deleteSelectedVideo() {
         guard let indexPath = tableView.indexPathForSelectedRow else { return }
         let urlToDelete = videoURLs[indexPath.row]
         do {
              try FileManager.default.removeItem(at: urlToDelete)
              videoURLs.remove(at: indexPath.row)
              tableView.deleteRows(at: [indexPath], with: .automatic)
              updateEmptyMessage()  // 삭제 후 파일이 없으면 빈 메시지 업데이트
         } catch {
              print("영상 삭제 오류: \(error)")
         }
    }
}
