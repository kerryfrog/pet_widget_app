import 'dart:math';
import 'package:flutter/material.dart';
import 'pet_nickname_setting_screen.dart';

class PetUnboxingScreen extends StatefulWidget {
  final Map<String, String> assignedPet;

  const PetUnboxingScreen({super.key, required this.assignedPet});

  @override
  State<PetUnboxingScreen> createState() => _PetUnboxingScreenState();
}

class _PetUnboxingScreenState extends State<PetUnboxingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  bool _isBoxVisible = true;
  bool _showPet = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _handleTapBox() async {
    // 1. 박스 흔들기
    await _shakeController.forward();
    _shakeController.reset();
    await _shakeController.forward();
    _shakeController.reset();

    // 2. 박스 사라지고 펫 등장
    setState(() {
      _isBoxVisible = false;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    setState(() {
      _showPet = true;
    });
  }

  void _goToPetNicknameSetting() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => PetNicknameSettingScreen(assignedPet: widget.assignedPet),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.pink[50],
      body: Stack(
        alignment: Alignment.center,
        children: [
          // 배경 장식 (선택 사항)
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.pink[100]!.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          
          // 박스 (오픈 전)
          Center(
            child: AnimatedOpacity(
              opacity: _isBoxVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: GestureDetector(
                onTap: _isBoxVisible ? _handleTapBox : null,
                child: AnimatedBuilder(
                  animation: _shakeController,
                  builder: (context, child) {
                    final sineValue = sin(4 * pi * _shakeController.value);
                    return Transform.translate(
                      offset: Offset(sineValue * 10, 0),
                      child: child,
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/present.png',
                        width: 200,
                        height: 200,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "상자를 터치해보세요!",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 펫 (오픈 후)
          if (!_isBoxVisible)
            Center(
              child: AnimatedScale(
                scale: _showPet ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "축하합니다!",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.pink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "나만의 펫을 만났어요!",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 30),
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
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: _goToPetNicknameSetting,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        "닉네임 설정하기",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
