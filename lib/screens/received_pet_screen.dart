import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
    // This function is no longer needed.
    // The auto-return logic is now handled by the StreamBuilder.
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.myId)
            .collection('visitors')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('오류 발생: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final receivedPets = snapshot.data!.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();

          final now = DateTime.now();
          final List<QueryDocumentSnapshot> expiredPets = [];
          for (final petDoc in snapshot.data!.docs) {
            final petData = petDoc.data() as Map<String, dynamic>;
            final returnTime = petData['return_time'] as Timestamp?;
            if (returnTime != null && returnTime.toDate().isBefore(now)) {
              expiredPets.add(petDoc);
            }
          }

          if (expiredPets.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              for (var petDoc in expiredPets) {
                petDoc.reference.delete();
              }
            });
            return _buildEmptyScreen('우리집');
          }

          if (!kIsWeb) {
            final firstPet = receivedPets.isNotEmpty ? receivedPets.first : null;
            if (firstPet != null) {
              HomeWidget.saveWidgetData<String>('pet_emoji', firstPet['value']);
              HomeWidget.saveWidgetData<String>('sender_name', firstPet['sender_nickname']);
              HomeWidget.saveWidgetData<String>('pet_message', firstPet['message']);
            } else {
              HomeWidget.saveWidgetData<String>('pet_emoji', null);
              HomeWidget.saveWidgetData<String>('sender_name', null);
              HomeWidget.saveWidgetData<String>('pet_message', null);
            }
            HomeWidget.updateWidget(
              name: 'PetWidgetProvider',
              androidName: 'PetWidgetProvider',
            );
          }

          return _buildPetScreen('우리집', receivedPets);
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

  String _getDialogTitle(String? petNickname) {
    String petName = petNickname ?? '이름 없는 펫';

    // Check for final consonant (Jongseong) in Hangul
    if (petName.isNotEmpty) {
      final lastChar = petName.codeUnitAt(petName.length - 1);
      if (lastChar >= 0xAC00 && lastChar <= 0xD7A3) { // Hangul Syllables range
        final hasJongseong = (lastChar - 0xAC00) % 28 != 0;
        final particle = hasJongseong ? '이' : '가';
        return '$petName$particle 찾아왔어요';
      }
    }
    // Default for non-Hangul names or empty string
    return '$petName' + '가 찾아왔어요';
  }

  void _showPetInfoDialog(Map<String, dynamic> petData) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(_getDialogTitle(petData['pet_nickname'])),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${petData['sender_nickname'] ?? '알 수 없는'}님이 보냈습니다!'),
              Text('${petData['pet_nickname'] ?? '이름 없음'}'),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('닫기'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
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
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: receivedPets.map((petData) {
                        final petValue = petData['value'] as String;
                        final petMessage = petData['message'] as String?;
                        return Flexible( // Wrap with Flexible
                          child: GestureDetector(
                            onTap: () => _showPetInfoDialog(petData),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0), // Reduced padding
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  if (petMessage != null && petMessage.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 10.0),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          SvgPicture.asset(
                                            'assets/images/pixel_message.svg',
                                            width: 120,
                                            height: 60,
                                            fit: BoxFit.contain,
                                          ),
                                          Transform.translate(
                                            offset: const Offset(0, -5),
                                            child: Text(
                                              petMessage,
                                              style: const TextStyle(color: Colors.black),
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
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
                            ),
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