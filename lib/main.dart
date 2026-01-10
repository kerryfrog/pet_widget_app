import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:home_widget/home_widget.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';

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
        await HomeWidget.saveWidgetData<String>('pet_emoji', receivedPet);
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
  
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);

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
      home: const HomeScreen(),
    );
  }
}