# IosProject
ios 운동 측정 어플

프로젝트 소개
이 프로젝트는 스쿼트, 푸쉬업, 턱걸이와 같은 맨몸 운동 동작을 애플의 비전 프레임워크를 활용하여 실시간으로 분석하고 측정하는 iOS 어플입니다. 사용자의 관절 움직임을 인식하여 정확한 자세에서만 카운트되도록 설계되어 정확한 운동을 할 수 있게 하여 운동의 질을 올려주게 도와줍니다.
핵심 기능으로 비전 프레임 워크를 사용하여 신체 관절의 위치를 실시간으로 감지하여 선택한 운동이 정확한 자세로 수행되고 있는지 시각적인 오버레이로 보여주고 정확한 자세가 나와야 카운트를 함으로서 운동의 효율을 올려줍니다. 사용자는 각 운동별로 운동 목표(횟수, 세트수, 쉬는시간)를 설정할수 있고 운동 종료 후에는 요약 화면에서 총 반복 횟수, 세트 수, 운동 시간, 소모 칼로리 등을 확인하여 얼마나 운동했는지 칼로리 소모 등 정보를 직관적으로 알 수 있습니다.
칼로리 소모는 사용자의 신체스펙을 미리 입력하여 저장된 정보로 계산므로 정확하게 어느정도의 정확성을 보장합니다.


개발 환경
- 개발 도구: xcode
- 언어: 스위프트
- ios 버전: 18.2


UserFlow

<img width="709" alt="스크린샷 2024-12-18 오후 11 58 02 1" src="https://github.com/user-attachments/assets/997dc3a2-0a0b-4c7b-b1cb-b900ca45d456" />

0. 신체 스펙 입력
- 어플 하단의 탭바를 통해 가장 우측의 설정 버튼으로 이동
- 성별과 나이, 키, 몸무게 와 같은 신체스펙을 입력하고 저장
- 해당 정보로 운동 완료시 조금 더 정확한 칼로리 측정 가능
  
1.메인 화면
- 사용자가 어플을 실행후 화면에 3가지 운동 모드 버튼 표시
- 각 버튼 운동 이름 아래 현재 설정된 목표 횟수, 세트수, 쉬는시간 표시
- 버튼안의 가장 우측의 (슬라이드 아이콘)버튼으로 운동 목표 수정 가능

2. 운동 목표 설정

- 사용자는 각 운동 모드 버튼 안의 가장 우측의 (슬라이드 아이콘)버튼을 클릭
- UIPickerView를 통해 반복횟수, 세트 수, 쉬는시간 설정
- 저장 버튼을 누르면 목표값이 저장되고 운동 모드 버튼의 운동이름 바로 아래 설정한 운동 목표 값 표시
- 변경된 값은 UserDefaults에 저장

3. 운동 모드 진입
- 운동 모드를 선택하면 카메라가실행되고 비전 프레임 워크를 통해 실시간으로 사용자의 관절 움직임을 감지
- 각 운동에 대한 분석 ex) 스쿼트: 무릎 각도가 특정 기준 이하로 내려가고 특정 기준 이상 올라올경우 카운트
- 실시간으로 반복 횟수, 현재 세트 수, 각 횟수당 평균속도, 실시간 소모 칼로리 정보가 화면에 표시

  
4. 운동 종료후 요약
- 운동 요약 화면이 아래에서 위로 모달로 올라옴
- 표시 정보 현재 수행한 운동 종류, 반복 횟수, 세트수, 지속시간, 회당 평균 속도, 총 소모 칼로리
- 확인 버튼을 눌러 다시 홈화면으로 돌아감

5. 운동 기록
- 사용자는 아래의 탭바 버튼을 통해 가운데에 기록이라고 적혀져 있는 운동 기록들을 모아둔 화면으로 이동 가능
- 달력과 테이블 뷰가 표시되고 달력의 날짜를 클릭해서 해당 날짜에 무슨 운동을 했는지 표시
- 테이블 뷰의 셀을 클릭하여 해당 운동의 기록을 더 자세히 확인
- 내림차순과 오름차순으로 순서 변경 가능



기능 명세서 
- 운동 모드 선택: 스쿼트, 푸쉬업, 턱걸이 운동 모드 선택
- 운동 목표 설정: 피커뷰를 통해 횟수, 세트수, 휴식 시간 설정
- 설정 저장 및 불러오기: UserDefaults를 사용해 설정값을 저장하고 앱 실행시 불러옴
- 실시간 자세 분석: 비전 프레임 워크로 신체 관절 위치를 분석하여 정확한 자세 감지
- 실시간 정보 표시: 현재 반복 횟수, 세트수, 실시간 운동 평균 속도, 실시간 칼로리 소모량 정보 표시
- 정확한 자세 카운트: 비전 프레임 워크로 포즈를 감지하고 기준 자세에 도달시에만 카운트, 음성기능도 지원하여 화면을 보지 않아도 카운트 됨을 알수 있음
- 카메라 회전 및 음성기능 on/off: 후면카메라로 변경 가능, 음성 기능 비활성화 가능
- 시각적 및 청각적 피드백: 시각적인 오버레이와 카운트를 읽어줌으로서 피드백
- 세트 및 휴식시간 관리: 세트 사이에 휴식시간 관리. 원형 프로그레스 바로 직관적으로 확인 가능
- 운동 요약 제공: 운동 종료후 최종 칼로리 및 개수당 평균속도 같은 중요 정보를 요약하여 표시
- 사용자 신체 정보 저장: 신체정보를 UserDefaults에 저장하고 보다 정확한 칼로리 계산에 활용
- 날짜별 운동 기록: 날짜별로 진행했던 운동 목록들을 시간순으로 오름/내림 차순으로 나열. 각 셀 클릭시 자세한 정보


어플 사진 이미지
- [어플 사진.pdf](https://github.com/user-attachments/files/18184811/default.pdf)


테스트 영상: https://youtube.com/shorts/0HO_RmDRxOE?si=OXRAgKZOz8KNViny






















