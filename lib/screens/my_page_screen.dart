import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../auth_service.dart';
import '../constants.dart';
import 'login_screen.dart';

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
  final TextEditingController _nicknameController = TextEditingController();
  String? _oldNickname;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadNickname();
    _currentUser = AuthService().currentUser;
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
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _saveInfo() async {
    final myId = widget.currentId;
    final newNickname = _nicknameController.text.trim();

    if (myId == null || myId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사용자 ID 정보가 없습니다.')),
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
        // 1. 닉네임 중복 체크
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
          transaction.set(nicknameRef, {'userId': myId});
        } else {
          // 닉네임은 그대로지만 'nicknames' 컬렉션에 없을 경우
          if (!nicknameDoc.exists) {
            transaction.set(nicknameRef, {'userId': myId});
          }
        }

        // 2. User 정보 업데이트
        final userRef = FirebaseFirestore.instance.collection('users').doc(myId);
        transaction.set(
            userRef, {'nickname': newNickname}, SetOptions(merge: true));
      });

      // 3. 로컬 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('my_nickname', newNickname);

      setState(() {
        _oldNickname = newNickname;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('닉네임이 저장되었습니다.')),
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

  Future<void> _logout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠습니까?\n로그아웃 시 내 정보가 초기화됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('로그아웃')),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService().signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('my_id');
      await prefs.remove('my_nickname');
      
      Workmanager().cancelByTag("pet_check_task");

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('마이페이지'),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '내 정보',
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
                      // 로그인 정보 표시
                      ListTile(
                        leading: const Icon(Icons.email),
                        title: const Text('로그인 계정'),
                        subtitle: Text(_currentUser?.email ?? '게스트 로그인'),
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
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
                        child: const Text('닉네임 저장하기'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    TextButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout, color: Colors.grey),
                      label: const Text('계정 로그아웃', style: TextStyle(color: Colors.grey)),
                    ),
                    TextButton(
                      onPressed: _deleteAccount,
                      child: Text(
                        '회원 탈퇴',
                        style: TextStyle(color: Colors.red[300], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('회원 탈퇴'),
        content: const Text('정말 탈퇴하시겠습니까?\n모든 데이터가 삭제되며 복구할 수 없습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('탈퇴', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final myId = widget.currentId;
      final myNickname = _oldNickname; // 현재 저장된 닉네임 사용

      if (myId != null) {
        final firestore = FirebaseFirestore.instance;
        final batch = firestore.batch();

        // 1. 내 친구 목록 가져오기
        final friendsSnapshot = await firestore
            .collection('users')
            .doc(myId)
            .collection('friends')
            .get();

        // 2. 친구들의 친구 목록에서 나를 삭제
        for (var doc in friendsSnapshot.docs) {
          final friendId = doc.id;
          final friendRef = firestore
              .collection('users')
              .doc(friendId)
              .collection('friends')
              .doc(myId);
          batch.delete(friendRef);
        }

        // 3. 닉네임 삭제
        if (myNickname != null && myNickname.isNotEmpty) {
          final nicknameRef = firestore.collection('nicknames').doc(myNickname);
          batch.delete(nicknameRef);
        }

        // 4. 유저 데이터 삭제
        final userRef = firestore.collection('users').doc(myId);
        batch.delete(userRef);

        // 일괄 처리 실행
        await batch.commit();
      }

      // Firebase Auth 삭제
      await AuthService().currentUser?.delete();
      await AuthService().signOut(); // 확실하게 로그아웃 처리

      // 로컬 데이터 삭제
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      Workmanager().cancelByTag("pet_check_task");
      widget.onIdChanged('');

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원 탈퇴가 완료되었습니다.')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('보안을 위해 다시 로그인 후 시도해주세요.')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('탈퇴 실패: ${e.message}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류 발생: $e')),
        );
      }
    }
  }
}

