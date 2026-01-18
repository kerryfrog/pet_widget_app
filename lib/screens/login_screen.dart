import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../auth_service.dart';
import 'home_screen.dart';
import 'nickname_setting_screen.dart';
import 'package:flutter_svg/flutter_svg.dart'; // Added this import back

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    try {
      final userCredential = await AuthService().signInWithGoogle();
      if (userCredential != null && userCredential.user != null) {
        final user = userCredential.user!;
        
        // Firestore에서 해당 uid를 가진 유저가 있는지 확인
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('uid', isEqualTo: user.uid)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          // 1. 이미 가입된 유저 -> 홈 화면으로 이동
          final userDoc = querySnapshot.docs.first;
          final userData = userDoc.data();
          final myId = userDoc.id; // 문서 ID가 myId
          final myNickname = userData['nickname'] ?? '';

          // 로컬 저장
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('my_id', myId);
          await prefs.setString('my_nickname', myNickname);

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
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          }
        } else {
          // 2. 신규 유저 -> 닉네임 설정 화면으로 이동
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => NicknameSettingScreen(user: user),
              ),
            );
          }
        }
      } else {
         if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google 로그인이 취소되었습니다.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google 로그인 오류: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/pets/dog_1.png', width: 120, height: 120),
              const SizedBox(height: 30),
              const Text(
                '놀러와 펫!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '친구와 펫을 주고받으며 위젯을 꾸며보세요!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.blueGrey),
              ),
              const SizedBox(height: 60),
              
              if (_isLoading)
                const CircularProgressIndicator(color: Colors.blue)
              else
                SizedBox(
                  width: 200,
                  height: 50,
                  child: GestureDetector(
                    onTap: _handleGoogleLogin,
                    child: SvgPicture.asset(
                      'assets/images/login/android_light_sq_SU.svg',
                      width: 200,
                      height: 50,
                      fit: BoxFit.contain,
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