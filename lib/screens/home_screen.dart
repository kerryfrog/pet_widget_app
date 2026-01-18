import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'dart:async';

import 'received_pet_screen.dart';
import 'send_pet_screen.dart';
import 'my_page_screen.dart';
import 'friend_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String? _myId;
  bool _isLoading = true;
  StreamSubscription? _widgetClickSubscription;

  @override
  void initState() {
    super.initState();
    _loadMyId();
    _setupHomeWidget();
  }

  @override
  void dispose() {
    _widgetClickSubscription?.cancel();
    super.dispose();
  }

  void _setupHomeWidget() {
    // 위젯 클릭 리스너 (앱이 실행 중일 때)
    _widgetClickSubscription = HomeWidget.widgetClicked.listen((Uri? uri) {
      _handleWidgetClick(uri);
    });

    // 위젯 클릭으로 앱이 처음 실행될 때
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetClick);
  }

  void _handleWidgetClick(Uri? uri) {
    if (uri?.scheme == 'petwidget' && uri?.host == 'yard') {
      setState(() {
        _selectedIndex = 0;
      });
    } else if (uri != null) {
      // 그 외 위젯 클릭 시에도 기본적으로 마당으로 이동
      setState(() {
        _selectedIndex = 0;
      });
    }
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
    if (kIsWeb) return;
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
      FriendListScreen(myId: _myId),
      MyPageScreen(
        currentId: _myId,
        onIdChanged: _updateMyId,
      ),
    ];

    return Scaffold(
      body: widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '마당',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pets),
            label: '내 펫',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: '친구',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '마이페이지',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}
