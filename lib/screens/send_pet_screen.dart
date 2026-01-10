import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

class SendPetScreen extends StatefulWidget {
  final String? myId;

  const SendPetScreen({super.key, required this.myId});

  @override
  State<SendPetScreen> createState() => _SendPetScreenState();
}

class _SendPetScreenState extends State<SendPetScreen> {
  String? selectedPetId;
  final TextEditingController _friendIdController = TextEditingController();

  @override
  void dispose() {
    _friendIdController.dispose();
    super.dispose();
  }

  Future<void> sendPet() async {
    if (widget.myId == null || widget.myId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('마이페이지에서 내 ID를 먼저 설정해주세요!')),
      );
      return;
    }

    if (selectedPetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('보낼 펫을 선택해주세요!')),
      );
      return;
    }

    if (_friendIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('친구 ID를 입력해주세요!')),
      );
      return;
    }

    final selectedPet = petList.firstWhere((p) => p['id'] == selectedPetId);
    final value = selectedPet['value']!;

    try {
      final prefs = await SharedPreferences.getInstance();
      final myNickname = prefs.getString('my_nickname') ?? widget.myId;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_friendIdController.text)
          .set({
        'current_pet': value,
        'last_update': FieldValue.serverTimestamp(),
        'sender': widget.myId,
        'sender_nickname': myNickname,
      }, SetOptions(merge: true));

      // 내 위젯도 업데이트 (선택 사항: 보낸 펫을 내 위젯에도 띄울지 여부.
      // 보통은 받은 펫을 띄우지만, 여기서는 전송 확인 차원에서 띄울 수도 있음.
      // 하지만 요구사항은 "상대가 보낸 펫을 볼 수 있는 공간"이 따로 있으므로,
      // 여기서는 전송만 하고 내 위젯은 건드리지 않거나,
      // 혹은 "내가 보낸 펫"으로 업데이트 할 수도 있음.
      // 기존 로직은 'sendPet' 함수 내에서 내 위젯도 업데이트 하고 있었음.
      // -> await HomeWidget.saveWidgetData<String>('pet_emoji', value);
      // 일단 기존 로직을 따라 내 위젯도 업데이트 하도록 유지함.
      
      await HomeWidget.saveWidgetData<String>('pet_emoji', value);
      await HomeWidget.updateWidget(
        name: 'PetWidgetProvider',
        androidName: 'PetWidgetProvider',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('친구에게 펫을 보냈어요!')),
        );
      }
    } catch (e) {
      debugPrint("전송 실패: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('전송 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('펫 보내기')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
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
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: petList.length,
                itemBuilder: (context, index) {
                  final pet = petList[index];
                  final isSelected = selectedPetId == pet['id'];
                  return GestureDetector(
                    onTap: () => setState(() => selectedPetId = pet['id']),
                    child: Card(
                      color: isSelected ? Colors.pink[100] : Colors.white,
                      elevation: isSelected ? 4 : 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isSelected ? const BorderSide(color: Colors.pink, width: 2) : BorderSide.none,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/images/${pet['value']}.png', width: 80, height: 80),
                          const SizedBox(height: 8),
                          Text(pet['name']!, style: const TextStyle(fontSize: 16)),
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
