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
      final docRef = FirebaseFirestore.instance.collection('users').doc(widget.myId);
      final doc = await docRef.get();

      if (!doc.exists) return;

      final data = doc.data();
      final currentPets = data?['current_pets'] as List<dynamic>?;

      if (currentPets != null && currentPets.isNotEmpty) {
        final now = DateTime.now();
        final List<dynamic> expiredPets = [];
        for (final petData in currentPets) {
          final returnTime = petData['return_time'] as Timestamp?;
          if (returnTime != null && returnTime.toDate().isBefore(now)) {
            expiredPets.add(petData);
          }
        }

        if (expiredPets.isNotEmpty) {
          await docRef.update({
            'current_pets': FieldValue.arrayRemove(expiredPets),
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
          
          final receivedPetsData = data?['current_pets'] as List<dynamic>?;
          final List<Map<String, dynamic>> receivedPets = receivedPetsData?.map((e) => e as Map<String, dynamic>).toList() ?? [];

          // Backward compatibility for old data structure
          final receivedPetValue = data?['current_pet'] as String?;
          if (receivedPetValue != null) {
            final sender = data!['sender'] as String?;
            final senderNickname = data!['sender_nickname'] as String?;
            receivedPets.add({
              'value': receivedPetValue,
              'sender': sender,
              'sender_nickname': senderNickname,
              'message': '안녕!', // Default message
            });
          }

          // Auto-return logic inside StreamBuilder
          final now = DateTime.now();
          final List<dynamic> expiredPets = [];
          for (final petData in receivedPets) {
            final returnTime = petData['return_time'] as Timestamp?;
            if (returnTime != null && returnTime.toDate().isBefore(now)) {
              expiredPets.add(petData);
            }
          }
          if (expiredPets.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              snapshot.data!.reference.update({
                'current_pets': FieldValue.arrayRemove(expiredPets),
                'last_update': FieldValue.serverTimestamp(),
              });
            });
            // Return empty screen immediately
            return _buildEmptyScreen(nickname);
          }


          // 위젯 업데이트 (펫이 왔거나, 돌아갔을 때 모두 반영)
          if (!kIsWeb) {
            // 최대 3마리까지 위젯에 표시
            final petsToShow = receivedPets.take(3).map((e) => e['value'] as String).toList();
            final String? petData = petsToShow.isEmpty ? null : petsToShow.join(',');

            HomeWidget.saveWidgetData<String>('pet_list', petData);
            HomeWidget.updateWidget(
              name: 'PetWidgetProvider',
              androidName: 'PetWidgetProvider',
            );
          }

          return _buildPetScreen(nickname, receivedPets);
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

  Widget _buildPetScreen(String nickname, List<Map<String, dynamic>> receivedPets) {
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
                      if (receivedPets.isEmpty)
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
              if (receivedPets.isNotEmpty)
                Positioned(
                  bottom: 80, // 잔디 위에 배치
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: receivedPets.map((petData) {
                        final petValue = petData['value'] as String;
                        final petMessage = petData['message'] as String?;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Column(
                            children: [
                              if (petMessage != null && petMessage.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(petMessage),
                                ),
                              Image.asset(
                                petValue.contains('/')
                                    ? 'assets/images/$petValue.png'
                                    : 'assets/images/pets/$petValue.png',
                                width: 100,
                                height: 100,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.help_outline, size: 80, color: Colors.white);
                                },
                              ),
                            ],
                          ),
                        );
                      }).toList(),
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