import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';

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

  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  // 실제 출시 전에는 반드시 '테스트 ID'를 사용하세요!
  final String adUnitId = 'ca-app-pub-3940256099942544/6300978111'; // Google Mobile Ads 테스트 광고 ID

  @override
  void initState() {
    super.initState();
    _loadMyId();
    _setupHomeWidget();
    _loadAd(); // 광고 로드
  }

  /// 광고를 불러오는 함수
  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        // 광고 로드 성공 시
        onAdLoaded: (ad) {
          debugPrint('$ad loaded.');
          setState(() {
            _isAdLoaded = true;
          });
        },
        // 광고 로드 실패 시
        onAdFailedToLoad: (ad, err) {
          debugPrint('BannerAd failed to load: $err');
          ad.dispose(); // 실패한 광고는 메모리에서 해제
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _widgetClickSubscription?.cancel();
    _bannerAd?.dispose(); // 메모리 누수 방지를 위해 해제 필수
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
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BottomNavigationBar(
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
          if (_bannerAd != null && _isAdLoaded)
            SizedBox(
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),
    );
  }
}
