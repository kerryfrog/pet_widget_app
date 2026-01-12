import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:flutter/foundation.dart';

class ReceivedPetScreen extends StatefulWidget {
  final String? myId;

  const ReceivedPetScreen({super.key, required this.myId});

  @override
  State<ReceivedPetScreen> createState() => _ReceivedPetScreenState();
}

class _ReceivedPetScreenState extends State<ReceivedPetScreen> {
  @override
  void initState() {
    super.initState();
    // 앱 실행 중 주기적으로 자동 회수 체크
    _checkAutoReturn();
  }

  Future<void> _checkAutoReturn() async {
    if (widget.myId == null || widget.myId!.isEmpty) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.myId)
          .get();

      if (!doc.exists) return;

      final data = doc.data();
      final returnTime = data?['return_time'] as Timestamp?;
      final currentPet = data?['current_pet'];

      // return_time이 있고, 현재 시간보다 이전이면 자동 회수
      if (returnTime != null && currentPet != null) {
        final now = DateTime.now();
        if (returnTime.toDate().isBefore(now)) {
          await doc.reference.update({
            'current_pet': FieldValue.delete(),
            'sender': FieldValue.delete(),
            'sender_nickname': FieldValue.delete(),
            'return_time': FieldValue.delete(),
            'last_update': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      debugPrint("자동 회수 체크 실패: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.myId == null || widget.myId!.isEmpty) {
      return const Center(
        child: Text('마이페이지에서 내 정보를 설정해주세요.'),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('마당')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.myId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('오류 발생: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 데이터 준비
          final data = snapshot.hasData && snapshot.data!.exists
              ? snapshot.data!.data() as Map<String, dynamic>
              : null;

          final nickname = data?['nickname'] as String? ?? '우리집';
          final receivedPetValue = data?['current_pet'] as String?;
          final sender = data?['sender'] as String?;
          final senderNickname = data?['sender_nickname'] as String?;
          final returnTime = data?['return_time'] as Timestamp?;

          // return_time이 지났으면 자동 회수
          if (returnTime != null && receivedPetValue != null) {
            final now = DateTime.now();
            if (returnTime.toDate().isBefore(now)) {
              // 비동기로 회수 처리 (위젯 빌드 중에는 직접 업데이트하지 않음)
              WidgetsBinding.instance.addPostFrameCallback((_) {
                snapshot.data!.reference.update({
                  'current_pet': FieldValue.delete(),
                  'sender': FieldValue.delete(),
                  'sender_nickname': FieldValue.delete(),
                  'return_time': FieldValue.delete(),
                  'last_update': FieldValue.serverTimestamp(),
                });
              });
              // 즉시 빈 화면 표시
              return _buildEmptyScreen(nickname);
            }
          }

          // 위젯 업데이트 (펫이 왔거나, 돌아갔을 때 모두 반영)
          if (!kIsWeb) {
            if (receivedPetValue != null) {
              HomeWidget.saveWidgetData<String>('pet_emoji', receivedPetValue);
              HomeWidget.saveWidgetData<String>('sender_name', senderNickname ?? sender ?? '친구');
            } else {
              // 펫이 없으면 위젯 데이터 초기화
              HomeWidget.saveWidgetData<String>('pet_emoji', null);
              HomeWidget.saveWidgetData<String>('sender_name', null);
            }
            HomeWidget.updateWidget(
              name: 'PetWidgetProvider',
              androidName: 'PetWidgetProvider',
            );
          }

          return _buildPetScreen(nickname, receivedPetValue, sender, senderNickname);
        },
      ),
    );
  }

  Widget _buildEmptyScreen(String nickname) {
    return Stack(
      children: [
        // 1. 하늘 배경
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue[200]!, Colors.blue[50]!],
            ),
          ),
        ),
        // 2. 구름 (장식)
        Positioned(
          top: 80,
          left: 50,
          child: Icon(Icons.cloud, size: 60, color: Colors.white.withOpacity(0.8)),
        ),
        Positioned(
          top: 60,
          right: 50,
          child: Icon(Icons.cloud, size: 40, color: Colors.white.withOpacity(0.6)),
        ),
        // 3. 잔디 땅
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 200,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.green[400],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(40),
                topRight: Radius.circular(40),
              ),
            ),
          ),
        ),
        // 4. 상단 타이틀
        Positioned(
          top: 50,
          left: 0,
          right: 0,
          child: Center(
            child: Column(
              children: [
                Text(
                  '$nickname 마당',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[800],
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Text(
                    "아직 놀러온 친구가 없어요",
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        ),
        // 5. 빈 펫 아이콘
        Positioned(
          bottom: 150,
          left: 0,
          right: 0,
          child: Center(
            child: Opacity(
              opacity: 0.3,
              child: Icon(Icons.pets, size: 80, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPetScreen(String nickname, String? receivedPetValue, String? sender, String? senderNickname) {
    return Stack(
      children: [
              // 1. 하늘 배경
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.blue[200]!, Colors.blue[50]!],
                  ),
                ),
              ),

              // 2. 구름 (장식)
              Positioned(
                top: 80,
                left: 50,
                child: Icon(Icons.cloud, size: 60, color: Colors.white.withOpacity(0.8)),
              ),
              Positioned(
                top: 60,
                right: 50,
                child: Icon(Icons.cloud, size: 40, color: Colors.white.withOpacity(0.6)),
              ),

              // 3. 잔디 땅 (평지)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 200, // 화면 하단부 차지
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.green[400],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 잔디 패턴 (텍스트로 간단히 표현하거나 생략 가능)
                    ],
                  ),
                ),
              ),

              // 4. 상단 타이틀
              Positioned(
                top: 50,
                left: 0,
                right: 0,
                child: Center(
                  child: Column(
                    children: [
                      Text(
                        '$nickname 마당', 
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey[800],
                        ),
                      ),
                      const SizedBox(height: 5),
                      if (receivedPetValue == null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Text(
                            "아직 놀러온 친구가 없어요",
                            style: TextStyle(color: Colors.black54),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // 5. 펫 (있을 경우에만 표시)
              if (receivedPetValue != null)
                Positioned(
                  bottom: 120, // 잔디 위에 배치
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Column(
                      children: [
                        // 말풍선
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '${senderNickname ?? sender ?? '누군가'} 님이 보냄',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        // 펫 이미지
                        Image.asset(
                          receivedPetValue.contains('/') 
                              ? 'assets/images/$receivedPetValue.png'
                              : 'assets/images/pets/$receivedPetValue.png',
                          width: 140,
                          height: 140,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.help_outline, size: 100, color: Colors.white);
                          },
                        ),
                      ],
                    ),
                  ),
                )
              else
                // 펫이 없을 때 표시할 빈 이미지나 아이콘 (선택 사항)
                Positioned(
                  bottom: 150,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Opacity(
                      opacity: 0.3,
                      child: Icon(Icons.pets, size: 80, color: Colors.white),
                    ),
                  ),
                ),
      ],
    );
  }
}