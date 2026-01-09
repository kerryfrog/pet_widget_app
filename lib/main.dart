import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:home_widget/home_widget.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

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
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.pink),
      home: const PetSelectScreen(),
    );
  }
}

class PetSelectScreen extends StatefulWidget {
  const PetSelectScreen({super.key});

  @override
  State<PetSelectScreen> createState() => _PetSelectScreenState();
}

class _PetSelectScreenState extends State<PetSelectScreen> {
  final List<Map<String, String>> petList = [
    {'id': 'dog_01', 'name': '강아지', 'emoji': '🐶'},
    {'id': 'cat_01', 'name': '고양이', 'emoji': '🐱'},
    {'id': 'frog', 'name': '개구리', 'emoji': '🐸'},
    {'id': 'hamster_01', 'name': '햄스터', 'emoji': '🐹'},
  ];

  String? selectedPetId;
  final TextEditingController _friendIdController = TextEditingController();
  final TextEditingController _myIdController = TextEditingController();
  StreamSubscription<DocumentSnapshot>? _petSubscription;

  @override
  void initState() {
    super.initState();
    _loadMyId();
  }

  Future<void> _loadMyId() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('my_id');
    if (savedId != null) {
      setState(() {
        _myIdController.text = savedId;
      });
      _startListening();
      _registerBackgroundTask();
    }
  }

  Future<void> _saveMyId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('my_id', id);
    _registerBackgroundTask();
  }

  void _registerBackgroundTask() {
    Workmanager().registerPeriodicTask(
      "pet_check_task",
      "checkFirebaseForPets",
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  @override
  void dispose() {
    _petSubscription?.cancel();
    _friendIdController.dispose();
    _myIdController.dispose();
    super.dispose();
  }

  void _startListening() {
    if (_myIdController.text.isEmpty) return;
    
    _saveMyId(_myIdController.text);

    _petSubscription?.cancel();
    _petSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(_myIdController.text)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data() as Map<String, dynamic>;
        final receivedPet = data['current_pet'];

        if (receivedPet != null) {
          setState(() {
            selectedPetId = receivedPet;
          });
          await HomeWidget.saveWidgetData<String>('pet_emoji', receivedPet);
          await HomeWidget.updateWidget(
            name: 'PetWidgetProvider',
            androidName: 'PetWidgetProvider',
          );
        }
      }
    });
  }

  Future<void> sendPet() async {
    if (selectedPetId == null || _friendIdController.text.isEmpty) return;

    // 1. 선택된 ID에 해당하는 이모지 찾기
    final selectedPet = petList.firstWhere((p) => p['id'] == selectedPetId);
    final emoji = selectedPet['emoji']!;

    try {
      // 2. 친구의 Firebase 문서 업데이트 (이게 핵심!)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_friendIdController.text)
          .set({
        'current_pet': emoji, // 이모지를 보냅니다.
        'last_update': FieldValue.serverTimestamp(),
        'sender': _myIdController.text,
      }, SetOptions(merge: true));

      // 3. (선택사항) 내 위젯도 내가 보낸 걸로 즉시 업데이트
      await HomeWidget.saveWidgetData<String>('pet_emoji', emoji);
      await HomeWidget.updateWidget(
        name: 'PetWidgetProvider',
        androidName: 'PetWidgetProvider',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('친구에게 펫을 보냈어요!')),
      );
    } catch (e) {
      print("전송 실패: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('펫 위젯 공유')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              color: Colors.pink[50],
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _myIdController,
                      decoration: const InputDecoration(
                        labelText: '내 ID (이걸로 펫을 받아요)',
                        icon: Icon(Icons.person),
                        border: InputBorder.none,
                      ),
                      onEditingComplete: () {
                        _startListening();
                        FocusScope.of(context).unfocus();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _friendIdController,
              decoration: const InputDecoration(
                labelText: '친구 ID (여기로 펫을 보내요)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.send),
              ),
            ),
            const SizedBox(height: 20),
            const Text("보낼 펫을 선택하세요", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
                itemCount: petList.length,
                itemBuilder: (context, index) {
                  final pet = petList[index];
                  final isSelected = selectedPetId == pet['id'];
                  return GestureDetector(
                    onTap: () => setState(() => selectedPetId = pet['id']),
                    child: Card(
                      color: isSelected ? Colors.pink[100] : Colors.white,
                      elevation: isSelected ? 4 : 1,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(pet['emoji']!, style: const TextStyle(fontSize: 50)),
                          Text(pet['name']!),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: sendPet,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: const Text('선택한 펫 전송하기'),
            ),
          ],
        ),
      ),
    );
  }
}
