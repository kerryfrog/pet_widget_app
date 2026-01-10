import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import '../constants.dart';

class ReceivedPetScreen extends StatefulWidget {
  final String? myId;

  const ReceivedPetScreen({super.key, required this.myId});

  @override
  State<ReceivedPetScreen> createState() => _ReceivedPetScreenState();
}

class _ReceivedPetScreenState extends State<ReceivedPetScreen> {
  @override
  Widget build(BuildContext context) {
    if (widget.myId == null || widget.myId!.isEmpty) {
      return const Center(
        child: Text('마이페이지에서 내 ID를 설정해주세요.'),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('받은 펫')),
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

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                '아직 받은 펫이 없어요.\n친구에게 ID를 알려주세요!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final receivedPetValue = data['current_pet'] as String?;
          final sender = data['sender'] as String?;
          final senderNickname = data['sender_nickname'] as String?;

          if (receivedPetValue == null) {
             return const Center(
              child: Text(
                '아직 받은 펫이 없어요.\n친구에게 ID를 알려주세요!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          // 위젯 업데이트 (앱이 켜져있을 때 실시간 반영을 위해 여기서도 수행)
          HomeWidget.saveWidgetData<String>('pet_emoji', receivedPetValue);
          HomeWidget.updateWidget(
            name: 'PetWidgetProvider',
            androidName: 'PetWidgetProvider',
          );

          // 펫 이름 찾기
          String petName = '알 수 없는 펫';
          try {
            final petInfo = petList.firstWhere(
              (p) => p['value'] == receivedPetValue, 
              orElse: () => {'name': '알 수 없는 펫'}
            );
            petName = petInfo['name']!;
          } catch (_) {}

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '지금 내 위젯에 살고 있는 친구',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.pink[50],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 5,
                        blurRadius: 7,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/$receivedPetValue.png',
                    width: 150,
                    height: 150,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.help_outline, size: 100, color: Colors.grey);
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  petName,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                if (sender != null)
                  Chip(
                    avatar: const Icon(Icons.person),
                    label: Text('${senderNickname ?? sender} 님이 보냄'),
                    backgroundColor: Colors.pink[100],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
