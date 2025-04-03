import UIKit
import AVKit
import Photos

class VideoGalleryViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let tableView = UITableView()
    var videoAssets: [PHAsset] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black
        setupTableView()
        loadVideoAssets()
        setupNavigationBar()
    }
    
    func setupNavigationBar() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "삭제", style: .plain, target: self, action: #selector(deleteSelectedVideo))
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
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
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "VideoCell")
        
        tableView.backgroundColor = .black
        tableView.separatorColor = .darkGray
    }
    
    func loadVideoAssets() {
        // 포토 라이브러리 접근 권한 요청
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized || status == .limited {
                let fetchOptions = PHFetchOptions()
                // 생성일 순으로 내림차순 정렬
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                let videoResults = PHAsset.fetchAssets(with: .video, options: fetchOptions)
                videoResults.enumerateObjects { (asset, index, stop) in
                    self.videoAssets.append(asset)
                }
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                    self.updateEmptyMessage()
                }
            } else {
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "접근 불가", message: "사진 라이브러리 접근이 허용되지 않았습니다.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "확인", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }
    
    func updateEmptyMessage() {
        if videoAssets.isEmpty {
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
         return videoAssets.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
         let cell = tableView.dequeueReusableCell(withIdentifier: "VideoCell", for: indexPath)
         let asset = videoAssets[indexPath.row]
         
         // 생성일을 표시하거나, 없으면 기본 텍스트 사용
         if let creationDate = asset.creationDate {
             let formatter = DateFormatter()
             formatter.dateStyle = .medium
             cell.textLabel?.text = formatter.string(from: creationDate)
         } else {
             cell.textLabel?.text = "비디오 \(indexPath.row + 1)"
         }
         cell.textLabel?.textColor = .white
         cell.backgroundColor = .black
         return cell
    }
    
    // MARK: - UITableViewDelegate Methods
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
         tableView.deselectRow(at: indexPath, animated: true)
         let asset = videoAssets[indexPath.row]
         let options = PHVideoRequestOptions()
         options.deliveryMode = .automatic
         options.isNetworkAccessAllowed = true
         PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { playerItem, info in
              guard let playerItem = playerItem else { return }
              DispatchQueue.main.async {
                   let player = AVPlayer(playerItem: playerItem)
                   let playerVC = AVPlayerViewController()
                   playerVC.player = player
                   self.present(playerVC, animated: true) {
                        player.play()
                   }
              }
         }
    }
    
    // MARK: - 삭제 기능 (선택된 동영상 삭제)
    @objc func deleteSelectedVideo() {
         guard let indexPath = tableView.indexPathForSelectedRow else { return }
         let asset = videoAssets[indexPath.row]
         PHPhotoLibrary.shared().performChanges({
              PHAssetChangeRequest.deleteAssets([asset] as NSArray)
         }) { success, error in
              if success {
                   DispatchQueue.main.async {
                        self.videoAssets.remove(at: indexPath.row)
                        self.tableView.deleteRows(at: [indexPath], with: .automatic)
                        self.updateEmptyMessage()
                   }
              } else {
                   print("영상 삭제 오류: \(String(describing: error))")
              }
         }
    }
}
