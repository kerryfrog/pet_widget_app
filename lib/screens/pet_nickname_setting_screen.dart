import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class PetNicknameSettingScreen extends StatefulWidget {
  final Map<String, String> assignedPet;

  const PetNicknameSettingScreen({super.key, required this.assignedPet});

  @override
  State<PetNicknameSettingScreen> createState() => _PetNicknameSettingScreenState();
}

class _PetNicknameSettingScreenState extends State<PetNicknameSettingScreen> {
  final TextEditingController _nicknameController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _savePetNickname() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      setState(() => _errorText = "펫 닉네임을 입력해주세요.");
      return;
    }
    
    if (nickname.length < 1 || nickname.length > 10) {
      setState(() => _errorText = "펫 닉네임은 1자 이상 10자 이하로 설정해주세요.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final myId = prefs.getString('my_id');

      if (myId == null || myId.isEmpty) {
        throw Exception("사용자 정보를 찾을 수 없습니다.");
      }

      // Firestore에서 사용자 문서 가져오기
      final userRef = FirebaseFirestore.instance.collection('users').doc(myId);
      final userDoc = await userRef.get();
      
      if (!userDoc.exists) {
        throw Exception("사용자 정보를 찾을 수 없습니다.");
      }

      // 기존 pet_nicknames 가져오기 (없으면 빈 Map)
      final userData = userDoc.data() as Map<String, dynamic>;
      final Map<String, String> petNicknames = 
          (userData['pet_nicknames'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, value.toString())
          ) ?? {};

      // 현재 펫의 닉네임 설정
      petNicknames[widget.assignedPet['value']!] = nickname;

      // Firestore에 저장
      await userRef.update({
        'pet_nicknames': petNicknames,
      });

      if (mounted) {
        // 홈 화면으로 이동
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
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
      backgroundColor: Colors.pink[50],
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text("펫 닉네임 설정"),
        backgroundColor: Colors.pink[50],
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // 펫 이미지
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/${widget.assignedPet['value']}.png',
                  width: 120,
                  height: 120,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.assignedPet['name']!,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                "펫의 닉네임을 설정해주세요!",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "1~10자 이내로 입력해주세요.",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _nicknameController,
                decoration: InputDecoration(
                  labelText: "펫 닉네임",
                  hintText: "예: 뽀삐, 멍멍이",
                  errorText: _errorText,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                maxLength: 10,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _savePetNickname(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _savePetNickname,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("완료", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              // 키보드 공간 확보를 위한 여백
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ],
          ),
        ),
      ),
    );
  }
}
