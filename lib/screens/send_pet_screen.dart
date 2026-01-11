import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

class SendPetScreen extends StatefulWidget {
  final String? myId;

  const SendPetScreen({super.key, required this.myId});

  @override
  State<SendPetScreen> createState() => _SendPetScreenState();
}

class _SendPetScreenState extends State<SendPetScreen> {
  String? _myNickname;

  @override
  void initState() {
    super.initState();
    _loadMyNickname();
  }

  Future<void> _loadMyNickname() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _myNickname = prefs.getString('my_nickname');
    });
  }

  // --- 1. 펫 상세 정보 (상태창) 보여주기 ---
  void _showPetDetail(Map<String, String> pet) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 펫 이름
                Text(
                  pet['name']!,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                // 펫 이미지 (크게)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.pink[50],
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(
                    'assets/images/${pet['value']}.png',
                    width: 120,
                    height: 120,
                  ),
                ),
                const SizedBox(height: 30),
                // 친구에게 보내기 버튼
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // 상세창 닫기
                    _showFriendSelection(pet); // 친구 선택창 열기
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('친구에게 보내기'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('닫기', style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- 2. 보낼 친구 선택하기 (친구 목록 불러오기) ---
  void _showFriendSelection(Map<String, String> pet) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 400, // 적당한 높이
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${pet['name']}을(를) 누구에게 보낼까요?',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.myId)
                      .collection('friends')
                      .where('status', isEqualTo: 'accepted') // 수락된 친구만
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return const Center(child: Text('오류 발생'));
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text('보낼 친구가 없어요.\n먼저 친구를 추가해주세요!'),
                      );
                    }

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final friendId = data['id'];
                        final friendNickname = data['nickname'] ?? friendId;

                        return ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(friendNickname),
                          subtitle: Text(friendId),
                          trailing: const Icon(Icons.send, color: Colors.pink),
                          onTap: () {
                            Navigator.pop(context); // 친구 선택창 닫기
                            _sendPetToFriend(friendId, friendNickname, pet);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- 3. 실제로 펫 전송하기 ---
  Future<void> _sendPetToFriend(
      String friendId, String friendNickname, Map<String, String> pet) async {
    try {
      final myId = widget.myId;
      final myNickname = _myNickname ?? myId;

      await FirebaseFirestore.instance.collection('users').doc(friendId).set({
        'current_pet': pet['value'],
        'sender': myId,
        'sender_nickname': myNickname,
        'last_update': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$friendNickname 님에게 ${pet['name']}을(를) 보냈어요!'),
            backgroundColor: Colors.pink,
          ),
        );
      }
    } catch (e) {
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
      appBar: AppBar(title: const Text('내 펫')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "친구에게 보낼 펫을 선택하세요.",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.myId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return const Center(child: Text('오류 발생'));
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final data = snapshot.data?.data() as Map<String, dynamic>?;
                  final List<dynamic> myPets = data?['my_pets'] ?? [];

                  if (myPets.isEmpty) {
                    return const Center(
                      child: Text('보유한 펫이 없습니다.', style: TextStyle(color: Colors.grey)),
                    );
                  }

                  // 내 펫 필터링
                  final myPetList = petList.where((p) => myPets.contains(p['value'])).toList();

                  if (myPetList.isEmpty) {
                     return const Center(
                      child: Text('보유한 펫 정보를 불러올 수 없습니다.', style: TextStyle(color: Colors.grey)),
                    );
                  }

                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: myPetList.length,
                    itemBuilder: (context, index) {
                      final pet = myPetList[index];
                      return GestureDetector(
                        onTap: () => _showPetDetail(pet),
                        child: Card(
                          color: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset('assets/images/${pet['value']}.png',
                                  width: 80, height: 80),
                              const SizedBox(height: 10),
                              Text(pet['name']!,
                                  style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}