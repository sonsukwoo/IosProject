# 🏋️‍♂️ Exercise - iOS 피트니스 트래킹 앱

---

## 👨‍🏫 프로젝트 소개

기존의 직접 기록형이나 단순 카운트 기반의 운동 앱과 달리, 이 앱은 운동 수행 중 실시간으로 간단한 자세 피드백을 제공합니다.
잘못된 자세를 감지해 올바른 자세로 유도하며, 이를 통해 부상 방지와 운동 효율 향상을 도모합니다.
또한 반복 횟수, 평균 속도, 소모 칼로리 등의 기록을 날짜별로 저장하고, 차트와 통계를 통해 시각적으로 분석할 수 있는 UX를 설계했습니다.
하루마다 바뀌는 도전 과제와 사용자 지정 리마인더 기능은 꾸준한 참여와 습관화를 유도하며, 운동 영상을 함께 녹화하여(선택적) 당시의 자세 피드백까지 함께 확인할 수 있도록 구성했습니다.

---

## 🧑‍🤝‍🧑 개발자 소개

* 손석우 : iOS 개발, 전체 앱 기획 및 구현, UX 설계

---

## 💻 개발 환경

* Xcode 15
* Swift 5.9
* iOS 18.5 시뮬레이터 / 실기기
* Git, GitHub 사용

---

## 💠 기술 스택

| 분류        | 사용 기술                                                                 |
|-------------|---------------------------------------------------------------------------|
| 언어         | `Swift`                                                                  |
| 프레임워크   | `UIKit`, `AVKit`, `UserNotifications`, `Vision`                          |
| 데이터       | `UserDefaults`, `Codable`, `FileManager`                                  |
| 영상 관리    | `Documents` 저장소 사용, 영상 리스트 & 재생 (`ReplayKit`, `Photos`)        |
| 푸시 알림    | `UNUserNotificationCenter`                                                |
| 음성 안내    | `AVSpeechSynthesizer`를 활용한 운동 중 실시간 한국어 음성 피드백            |
| 자세 분석    | `VNDetectHumanBodyPoseRequest`, `VNImageRequestHandler`, `VNHumanBodyPoseObservation` |

---

## 📌 주요 기능

### 📍 Vision 기반 실시간 자세 분석 및 피드백

* Apple Vision 프레임워크를 활용해 사용자의 자세를 실시간으로 추적하고 분석.
* 조건부 로직 기반으로 잘못된 자세를 감지하면 시각적, 텍스트, 음성 피드백을 즉시 제공.
* 기본적인 카운팅 기능 외에도, 올바른 자세로 수행 시에만 반복 횟수가 인정되도록 설계.
* 사용자 스스로 자세를 교정하고 정확한 운동을 반복하도록 유도함.

### 📍 운동 종류별 목표 설정 기능

* 사용자는 스쿼트, 푸쉬업, 턱걸이에 대해 각각 반복 수, 세트 수, 휴식 시간을 개별적으로 설정할 수 있음.
* 각 버튼의 서브타이틀을 통해 설정한 값 확인 가능.
* 설정값은 UserDefaults에 저장되어 앱 재실행 시에도 유지됨.
* UI는 피커뷰(PickerView)로 구성되어 사용자에게 직관적 조작 제공.

### 📍 도전 과제 시스템 (Daily Challenge)

* 매일 자정마다 자동으로 갱신되는 운동 도전 과제 제공.(재갱신 가능)
* 지난 7일간 일일 평균 횟수의 ±10% 범위로 오늘의 도전 과제가 생성. (기록이 없을경우 적절한 값으로 랜덤)
* 도전 과제 완료 시 "도전 과제 완료!" 알림과 체크리스트 체크

### 📍 운동 리마인더 기능

* 원하는 시각에 운동 알림을 받을 수 있도록 설정 가능.
* 알림은 UNUserNotificationCenter를 통해 로컬 푸시로 구현됨.
* 설정된 알림 개수는 하위 텍스트(서브타이틀)로 버튼에 표시됨.
* ReminderListViewController에서 설정된 알림 목록을 수정하거나 삭제할 수 있음.

### 📍 운동 기록 기능

* 사용자의 운동 이력을 기록 및 통계화하여 추적 가능.
* 기록은 일간 / 주간 / 월간 / 년간 단위로 요약 가능.
* 별도 뷰컨트롤러(예: StatisticsViewController(숫자 통계), MonthlyDetailViewController(차트 제공))를 통해 시각화 제공.

### 📍 운동 영상 갤러리

* 녹화 기능을 통한 운동 영상을 Documents 디렉토리에 저장하고 관리.
* VideoGalleryViewController에서 파일 목록 및 미리보기, 삭제 가능.

---

## ✒️ 향후 확장 방향

* 향후 ML 모델을 통한 더 정확한 실시간 자세 분석 기능 적용 예정
* HealthKit 연동 및 심박수 기반 피드백 시스템 계획 중
* 클라우드 백업, 동기화 기능  검토
* 보다 더 직관적인 UI로 개선

---

## 🎥 시연 영상

* 유저플로우: https://youtube.com/shorts/xQUCJsBSqcY?si=opeLLatADycHhrSe
* 스쿼트: https://youtube.com/shorts/t_YfBJu8PDM?si=uqwxJemRUCMEOrh2
* 푸쉬업: https://youtube.com/shorts/l1ThC9osUPc?si=fB5prTsr2Y6HTZ-q
* 턱걸이: https://youtube.com/shorts/evTHiwJTA_Y?si=IuFRJBSsBcG_viS2

* 타사 스쿼트 어플: https://youtube.com/shorts/0RAFuhwY5no?si=FgCt66kjBhqcuG2g








