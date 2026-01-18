import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter/foundation.dart';
import '../constants.dart';
import 'pet_unboxing_screen.dart';

class NicknameSettingScreen extends StatefulWidget {
  final User user;

  const NicknameSettingScreen({super.key, required this.user});

  @override
  State<NicknameSettingScreen> createState() => _NicknameSettingScreenState();
}

class _NicknameSettingScreenState extends State<NicknameSettingScreen> {
  final TextEditingController _nicknameController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _completeSignup() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      setState(() => _errorText = "닉네임을 입력해주세요.");
      return;
    }
    
    if (nickname.length < 2 || nickname.length > 10) {
      setState(() => _errorText = "닉네임은 2자 이상 10자 이하로 설정해주세요.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    Map<String, String>? assignedPet;

    try {
      // ID 생성 (이메일 앞부분)
      String myId = widget.user.email?.split('@')[0] ?? '';
      myId = myId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      if (myId.isEmpty) {
        myId = widget.user.uid.substring(0, 8);
      }
      
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(myId).get();
      if (userDoc.exists) {
        if (userDoc.data()?['uid'] != widget.user.uid) {
           myId = "${myId}_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}";
        }
      }

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // 닉네임 중복 체크
        final nicknameRef = FirebaseFirestore.instance.collection('nicknames').doc(nickname);
        final nicknameDoc = await transaction.get(nicknameRef);

        if (nicknameDoc.exists) {
          throw Exception("이미 존재하는 닉네임입니다. 다른 닉네임을 사용해주세요.");
        }

        // 닉네임 등록
        transaction.set(nicknameRef, {'userId': myId});

        // 펫 랜덤 배정
        final random = Random();
        assignedPet = petList[random.nextInt(petList.length)];

        // 유저 정보 저장
        final userRef = FirebaseFirestore.instance.collection('users').doc(myId);
        final userData = {
          'nickname': nickname,
          'uid': widget.user.uid,
          'email': widget.user.email,
          'createdAt': FieldValue.serverTimestamp(),
          'my_pets': [assignedPet!['value']], // 랜덤 펫 추가
          'partner_pet': assignedPet!['value'], // 파트너 펫 설정
        };

        transaction.set(userRef, userData, SetOptions(merge: true));
      });

      // 로컬 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('my_id', myId);
      await prefs.setString('my_nickname', nickname);

      // 백그라운드 작업 등록
      if (!kIsWeb) {
        Workmanager().registerPeriodicTask(
          "pet_check_task",
          "checkFirebaseForPets",
          frequency: const Duration(minutes: 15),
          constraints: Constraints(networkType: NetworkType.connected),
        );
      }

      if (mounted) {
        // 펫 언박싱 화면으로 이동
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => PetUnboxingScreen(assignedPet: assignedPet!),
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = e.toString().replaceAll("Exception: ", "");
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: const Text("닉네임 설정"),
        backgroundColor: Colors.blue[50],
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "환영합니다!",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "사용하실 닉네임을 입력해주세요.",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _nicknameController,
              decoration: InputDecoration(
                labelText: "닉네임",
                hintText: "2~10자 이내",
                errorText: _errorText,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              maxLength: 10,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _completeSignup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("시작하기", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
