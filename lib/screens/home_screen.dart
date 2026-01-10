import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'received_pet_screen.dart';
import 'send_pet_screen.dart';
import 'my_page_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String? _myId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMyId();
  }

  Future<void> _loadMyId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _myId = prefs.getString('my_id');
      _isLoading = false;
    });

    if (_myId != null) {
      _registerBackgroundTask();
    }
  }

  void _registerBackgroundTask() {
    Workmanager().registerPeriodicTask(
      "pet_check_task",
      "checkFirebaseForPets",
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _updateMyId(String newId) {
    setState(() {
      _myId = newId;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final List<Widget> widgetOptions = <Widget>[
      ReceivedPetScreen(myId: _myId),
      SendPetScreen(myId: _myId),
      MyPageScreen(
        currentId: _myId,
        onIdChanged: _updateMyId,
      ),
    ];

    return Scaffold(
      body: widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '받은 펫',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.send),
            label: '보내기',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '마이페이지',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.pink,
        onTap: _onItemTapped,
      ),
    );
  }
}
