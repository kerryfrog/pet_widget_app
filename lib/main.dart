import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:home_widget/home_widget.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

// --- 백그라운드 작업 (우편 배달부 + 자동 회수) ---
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

      // 1. 자동 회수 체크: return_time이 지난 펫들을 회수
      await _checkAndReturnPets();

      // 2. 위젯 업데이트
      final prefs = await SharedPreferences.getInstance();
      final myId = prefs.getString('my_id');

      if (myId != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(myId).get();
        final data = doc.data();

        if (data != null) {
            final receivedPetsData = data['current_pets'] as List<dynamic>?;
            final List<Map<String, dynamic>> receivedPets = receivedPetsData?.map((e) => e as Map<String, dynamic>).toList() ?? [];

            final petsToShow = receivedPets.take(3).map((e) => e['value'] as String).toList();
            final String? petData = petsToShow.isEmpty ? null : petsToShow.join(',');

            await HomeWidget.saveWidgetData<String>('pet_list', petData);
            await HomeWidget.updateWidget(
                name: 'PetWidgetProvider',
                androidName: 'PetWidgetProvider',
            );
        }
      }
    } catch (e) {
      debugPrint("백그라운드 작업 실패: $e");
    }
    return Future.value(true);
  });
}

// 자동 회수 함수
Future<void> _checkAndReturnPets() async {
  try {
    final now = DateTime.now();
    final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();

    for (var userDoc in usersSnapshot.docs) {
      final userData = userDoc.data();
      final currentPets = userData['current_pets'] as List<dynamic>?;

      if (currentPets != null && currentPets.isNotEmpty) {
        final List<dynamic> expiredPets = [];
        for (final petData in currentPets) {
          final returnTime = petData['return_time'] as Timestamp?;
          if (returnTime != null && returnTime.toDate().isBefore(now)) {
            expiredPets.add(petData);
          }
        }

        if (expiredPets.isNotEmpty) {
          await userDoc.reference.update({
            'current_pets': FieldValue.arrayRemove(expiredPets),
            'last_update': FieldValue.serverTimestamp(),
          });
          debugPrint("펫 자동 회수 완료 for user: ${userDoc.id}");
        }
      }
    }
  } catch (e) {
    debugPrint("자동 회수 체크 실패: $e");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  if (!kIsWeb) {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
  }

  runApp(const PetWidgetApp());
}

class PetWidgetApp extends StatelessWidget {
  const PetWidgetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pet Widget App',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const AuthCheckScreen(),
    );
  }
}

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final myId = prefs.getString('my_id');
    final myNickname = prefs.getString('my_nickname');

    // 약간의 딜레이를 주어 스플래시 효과 (선택 사항)
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      if (myId != null && myId.isNotEmpty && myNickname != null && myNickname.isNotEmpty) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}