import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

class MyPageScreen extends StatefulWidget {
  final String? currentId;
  final Function(String) onIdChanged;

  const MyPageScreen({
    super.key,
    required this.currentId,
    required this.onIdChanged,
  });

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  late TextEditingController _idController;
  final TextEditingController _nicknameController = TextEditingController();
  String? _oldNickname;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(text: widget.currentId);
    _loadNickname();
  }

  Future<void> _loadNickname() async {
    final prefs = await SharedPreferences.getInstance();
    final nickname = prefs.getString('my_nickname') ?? '';
    setState(() {
      _nicknameController.text = nickname;
      _oldNickname = nickname;
    });
  }

  @override
  void didUpdateWidget(covariant MyPageScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentId != oldWidget.currentId) {
      _idController.text = widget.currentId ?? '';
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _saveInfo() async {
    final newId = _idController.text.trim();
    final newNickname = _nicknameController.text.trim();

    if (newId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID를 입력해주세요.')),
      );
      return;
    }

    if (newNickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임을 입력해주세요.')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // 1. 닉네임 중복 체크 (닉네임이 변경되었거나, 기존 닉네임이 등록 안 된 경우 대비)
        final nicknameRef =
            FirebaseFirestore.instance.collection('nicknames').doc(newNickname);
        final nicknameDoc = await transaction.get(nicknameRef);

        if (newNickname != _oldNickname) {
          if (nicknameDoc.exists) {
            throw Exception("이미 사용 중인 닉네임입니다.");
          }

          // 이전 닉네임 삭제
          if (_oldNickname != null && _oldNickname!.isNotEmpty) {
            final oldNicknameRef = FirebaseFirestore.instance
                .collection('nicknames')
                .doc(_oldNickname);
            transaction.delete(oldNicknameRef);
          }

          // 새 닉네임 등록
          transaction.set(nicknameRef, {'userId': newId});
        } else {
          // 닉네임은 그대로지만 'nicknames' 컬렉션에 없을 경우 (최초 마이그레이션 등)
          if (!nicknameDoc.exists) {
            transaction.set(nicknameRef, {'userId': newId});
          }
        }

        // 2. User 정보 업데이트
        final userRef = FirebaseFirestore.instance.collection('users').doc(newId);
        transaction.set(
            userRef, {'nickname': newNickname}, SetOptions(merge: true));
      });

      // 3. 로컬 저장 (트랜잭션 성공 시에만 수행)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('my_id', newId);
      await prefs.setString('my_nickname', newNickname);

      setState(() {
        _oldNickname = newNickname;
      });

      // 백그라운드 작업 재등록
      Workmanager().registerPeriodicTask(
        "pet_check_task",
        "checkFirebaseForPets",
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
      );

      widget.onIdChanged(newId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('정보가 저장되었습니다.')),
        );
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      String errorMessage = "저장 실패";
      if (e.toString().contains("이미 사용 중인 닉네임")) {
        errorMessage = "이미 사용 중인 닉네임입니다.";
      } else {
        errorMessage = "저장 중 오류가 발생했습니다: $e";
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('마이페이지')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '내 정보 설정',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Icon(Icons.person_pin, size: 60, color: Colors.pink),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _idController,
                        decoration: const InputDecoration(
                          labelText: '내 ID',
                          helperText: '이 ID로 친구들이 펫을 보내줄 수 있어요.',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.tag),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nicknameController,
                        decoration: const InputDecoration(
                          labelText: '내 닉네임',
                          helperText: '친구에게 이 이름으로 표시돼요.',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.face),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _saveInfo,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text('저장하기'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
