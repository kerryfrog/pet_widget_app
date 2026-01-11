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

// --- 백그라운드 작업 (우편 배달부) ---
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

      final prefs = await SharedPreferences.getInstance();
      final myId = prefs.getString('my_id');

      if (myId == null) return Future.value(true);

      final doc = await FirebaseFirestore.instance.collection('users').doc(myId).get();
      final data = doc.data();

      if (data != null && data['current_pet'] != null) {
        final String receivedPet = data['current_pet'];
        final String senderName = data['sender_nickname'] ?? data['sender'] ?? '친구';

        await HomeWidget.saveWidgetData<String>('pet_emoji', receivedPet);
        await HomeWidget.saveWidgetData<String>('sender_name', senderName);
        
        await HomeWidget.updateWidget(
          name: 'PetWidgetProvider',
          androidName: 'PetWidgetProvider',
        );
      }
    } catch (e) {
      debugPrint("백그라운드 작업 실패: $e");
    }
    return Future.value(true);
  });
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
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.pink),
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