import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../auth_service.dart';
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
  User? _currentUser;
  String? _userPetEmoji;
  String? _userEmailFromFirestore;

  String? _resolvePetImageAssetPath() {
    final petValue = _userPetEmoji;
    if (petValue == null || petValue.isEmpty) return null;

    if (petValue.contains('/')) {
      return 'assets/images/$petValue.png';
    }
    return 'assets/images/pets/$petValue.png';
  }

  @override
  void initState() {
    super.initState();
    _loadNickname();
    _currentUser = AuthService().currentUser;
    _loadUserPet();
  }

  Future<void> _loadNickname() async {
    final prefs = await SharedPreferences.getInstance();
    final nickname = prefs.getString('my_nickname') ?? '';
    setState(() {
      _nicknameController.text = nickname;
    });
  }

  Future<void> _loadUserPet() async {
    if (widget.currentId != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentId)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        final myPets = data.containsKey('my_pets')
            ? List<String>.from(data['my_pets'])
            : <String>[];
        setState(() {
          _userPetEmoji = myPets.isNotEmpty ? myPets.first : null;
          _userEmailFromFirestore = data['email'] as String?;
        });
        return;
      }
    }

    final uid = _currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    // Fallback: if users/{my_id} doc is missing or mismatched, find by uid.
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      final data = querySnapshot.docs.first.data();
      final myPets = data.containsKey('my_pets')
          ? List<String>.from(data['my_pets'])
          : <String>[];
      setState(() {
        _userPetEmoji = myPets.isNotEmpty ? myPets.first : _userPetEmoji;
        _userEmailFromFirestore = data['email'] as String?;
      });
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  String _getLoginInfo() {
    if (_currentUser == null) {
      return '게스트 로그인';
    }
    final providerId = _getLoginProviderId();
    final authEmail = _currentUser!.email;
    if (authEmail != null && authEmail.isNotEmpty) {
      return authEmail;
    }

    for (final provider in _currentUser!.providerData) {
      final providerEmail = provider.email;
      if (providerEmail != null && providerEmail.isNotEmpty) {
        return providerEmail;
      }
    }

    final firestoreEmail = _userEmailFromFirestore;
    if (firestoreEmail != null && firestoreEmail.isNotEmpty) {
      return firestoreEmail;
    }

    if (providerId == 'apple.com') {
      return '이메일 비공개';
    }

    return '이메일 정보 없음';
  }

  String _getLoginProviderId() {
    if (_currentUser == null) return 'guest';

    for (final provider in _currentUser!.providerData) {
      if (provider.providerId == 'google.com') return 'google.com';
      if (provider.providerId == 'apple.com') return 'apple.com';
    }

    return 'unknown';
  }

  Widget _buildLoginProviderIcon() {
    final providerId = _getLoginProviderId();

    if (providerId == 'google.com') {
      return SvgPicture.asset(
        'assets/images/login/google_logo.svg',
        width: 22,
        height: 22,
      );
    }

    if (providerId == 'apple.com') {
      return SvgPicture.asset(
        'assets/images/login/apple_logo.svg',
        width: 22,
        height: 22,
      );
    }

    return const Icon(Icons.email);
  }

  Future<void> _showNicknameEditDialog() async {
    final currentNickname = _nicknameController.text.trim();
    var draftNickname = currentNickname;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('닉네임 변경'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => TextFormField(
            initialValue: currentNickname,
            autofocus: true,
            maxLength: 20,
            onChanged: (value) {
              setDialogState(() {
                draftNickname = value;
              });
            },
            decoration: const InputDecoration(
              hintText: '새 닉네임을 입력하세요',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, draftNickname.trim()),
            child: const Text('변경'),
          ),
        ],
      ),
    );

    if (result == null) return;
    await _changeNickname(result);
  }

  Future<void> _changeNickname(String newNickname) async {
    final myId = widget.currentId;
    if (myId == null || myId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사용자 정보가 없어 닉네임을 변경할 수 없습니다.')),
      );
      return;
    }

    if (newNickname.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임을 입력해주세요.')),
      );
      return;
    }

    final currentNickname = _nicknameController.text.trim();
    if (newNickname == currentNickname) return;

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final nicknames = FirebaseFirestore.instance.collection('nicknames');
        final newNicknameRef = nicknames.doc(newNickname);
        final newNicknameDoc = await transaction.get(newNicknameRef);

        if (newNicknameDoc.exists) {
          final ownerId = newNicknameDoc.data()?['userId'] as String?;
          if (ownerId != myId) {
            throw Exception('nickname_taken');
          }
        }

        final userRef = FirebaseFirestore.instance.collection('users').doc(myId);
        transaction.set(userRef, {'nickname': newNickname}, SetOptions(merge: true));
        transaction.set(newNicknameRef, {'userId': myId});

        if (currentNickname.isNotEmpty && currentNickname != newNickname) {
          final oldNicknameRef = nicknames.doc(currentNickname);
          transaction.delete(oldNicknameRef);
        }
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('my_nickname', newNickname);

      if (!mounted) return;
      setState(() {
        _nicknameController.text = newNickname;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임이 변경되었습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().contains('nickname_taken')
          ? '이미 사용 중인 닉네임이라 변경할 수 없습니다.'
          : '닉네임 변경 중 오류가 발생했습니다.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
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
                      Row(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.blue.shade100),
                            ),
                            alignment: Alignment.center,
                            child: _resolvePetImageAssetPath() != null
                                ? ClipOval(
                                    child: Image.asset(
                                      _resolvePetImageAssetPath()!,
                                      width: 58,
                                      height: 58,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) => const Icon(
                                        Icons.pets,
                                        size: 34,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.pets,
                                    size: 34,
                                    color: Colors.blue,
                                  ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _nicknameController.text.trim().isNotEmpty
                                        ? _nicknameController.text.trim()
                                        : '닉네임 미설정',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  onPressed: _showNicknameEditDialog,
                                  icon: const Icon(Icons.edit, size: 20),
                                  tooltip: '닉네임 변경',
                                  color: Colors.blueGrey,
                                  splashRadius: 20,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // 로그인 정보 표시
                      ListTile(
                        leading: _buildLoginProviderIcon(),
                        title: Text(_getLoginInfo()),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout),
                        label: const Text('로그아웃'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _deleteAccount,
                        icon: const Icon(Icons.person_remove_alt_1),
                        label: const Text('회원 탈퇴'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
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
      final myNickname = _nicknameController.text.trim();

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
        if (myNickname.isNotEmpty) {
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
