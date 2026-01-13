import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

// 펫 닉네임 수정 다이얼로그 위젯
class _NicknameEditDialog extends StatefulWidget {
  final Map<String, String> pet;
  final String currentNickname;
  final VoidCallback onSaved;

  const _NicknameEditDialog({
    required this.pet,
    required this.currentNickname,
    required this.onSaved,
  });

  @override
  State<_NicknameEditDialog> createState() => _NicknameEditDialogState();
}

class _NicknameEditDialogState extends State<_NicknameEditDialog> {
  late TextEditingController _nicknameController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(text: widget.currentNickname);
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _saveNickname() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      setState(() {
        _errorText = '닉네임을 입력해주세요.';
      });
      return;
    }
    if (nickname.length < 1 || nickname.length > 10) {
      setState(() {
        _errorText = '닉네임은 1자 이상 10자 이하로 입력해주세요.';
      });
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final myId = prefs.getString('my_id');

      if (myId == null || myId.isEmpty) {
        setState(() {
          _errorText = '사용자 정보를 찾을 수 없습니다.';
        });
        return;
      }

      // Firestore에서 사용자 문서 가져오기
      final userRef = FirebaseFirestore.instance.collection('users').doc(myId);
      final userDoc = await userRef.get();

      if (!userDoc.exists) {
        setState(() {
          _errorText = '사용자 정보를 찾을 수 없습니다.';
        });
        return;
      }

      // 기존 pet_nicknames 가져오기
      final userData = userDoc.data() as Map<String, dynamic>;
      final Map<String, String> updatedPetNicknames =
          (userData['pet_nicknames'] as Map<String, dynamic>?)?.map(
                (key, value) => MapEntry(key, value.toString()),
              ) ??
              {};

      // 닉네임 업데이트
      updatedPetNicknames[widget.pet['value']!] = nickname;

      // Firestore에 저장
      await userRef.update({
        'pet_nicknames': updatedPetNicknames,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("'$nickname'으로 변경되었습니다!"),
            backgroundColor: Colors.pink,
          ),
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('펫 닉네임 수정'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 펫 이미지
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.pink[50],
              shape: BoxShape.circle,
            ),
            child: Image.asset(
              'assets/images/${widget.pet['value']}.png',
              width: 80,
              height: 80,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nicknameController,
            decoration: InputDecoration(
              labelText: '닉네임',
              hintText: '1~10자 이내',
              errorText: _errorText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            maxLength: 10,
            onChanged: (value) {
              setState(() {
                _errorText = null;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _saveNickname,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.pink,
            foregroundColor: Colors.white,
          ),
          child: const Text('저장'),
        ),
      ],
    );
  }
}

// 펫 대사 입력 다이얼로그
class _SendMessageDialog extends StatefulWidget {
  final String friendNickname;
  final Function(String message) onSend;

  const _SendMessageDialog({required this.friendNickname, required this.onSend});

  @override
  State<_SendMessageDialog> createState() => _SendMessageDialogState();
}

class _SendMessageDialogState extends State<_SendMessageDialog> {
  late TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    widget.onSend(message);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.friendNickname}에게 보낼 대사'),
      content: TextField(
        controller: _messageController,
        decoration: const InputDecoration(
          hintText: '2글자 이하 입력 (선택)',
        ),
        maxLength: 2,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _sendMessage,
          child: const Text('보내기'),
        ),
      ],
    );
  }
}

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

  // --- 0. 펫 닉네임 수정 다이얼로그 ---
  void _showNicknameEditDialog(Map<String, String> pet, Map<String, String> petNicknames) {
    showDialog(
      context: context,
      builder: (context) => _NicknameEditDialog(
        pet: pet,
        currentNickname: petNicknames[pet['value']] ?? pet['name']!,
        onSaved: () {
          // 저장 후 화면 새로고침을 위해 아무것도 하지 않음 (StreamBuilder가 자동 업데이트)
        },
      ),
    );
  }

  // --- 1. 펫 상세 정보 (상태창) 보여주기 ---
  void _showPetDetail(Map<String, String> pet, Map<String, String> petNicknames) {
    // 설정된 닉네임이 있으면 사용, 없으면 기본 이름 사용
    final displayName = petNicknames[pet['value']] ?? pet['name']!;
    
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 펫 이름과 편집 버튼
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () {
                        Navigator.pop(context); // 현재 다이얼로그 닫기
                        _showNicknameEditDialog(pet, petNicknames);
                      },
                      tooltip: '닉네임 수정',
                    ),
                  ],
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
                
                // 상태 확인 및 버튼 (FutureBuilder)
                FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }

                    if (snapshot.hasError) {
                      return const Text('상태를 확인할 수 없습니다.', style: TextStyle(color: Colors.grey));
                    }

                    final users = snapshot.data?.docs ?? [];
                    QueryDocumentSnapshot? friendDoc;
                    Map<String, dynamic>? petData;

                    for (final doc in users) {
                      final data = doc.data() as Map<String, dynamic>;
                      final currentPets = data['current_pets'] as List<dynamic>?;
                      if (currentPets != null) {
                        final foundPet = currentPets.firstWhere(
                          (p) => p['sender'] == widget.myId && p['value'] == pet['value'],
                          orElse: () => null,
                        );
                        if (foundPet != null) {
                          friendDoc = doc;
                          petData = foundPet;
                          break;
                        }
                      }
                    }
                    
                    if (friendDoc != null && petData != null) {
                      // 이미 친구에게 가있는 경우
                      final friendData = friendDoc.data() as Map<String, dynamic>;
                      final friendNickname = friendData['nickname'] ?? '친구';
                      final returnTime = petData['return_time'] as Timestamp?;
                      
                      // 돌아오는 시간 계산
                      String returnTimeText = '';
                      if (returnTime != null) {
                        final returnDateTime = returnTime.toDate();
                        final now = DateTime.now();
                        if (returnDateTime.isAfter(now)) {
                          final difference = returnDateTime.difference(now);
                          final hours = difference.inHours;
                          final minutes = difference.inMinutes % 60;
                          if (hours > 0) {
                            returnTimeText = '약 ${hours}시간 ${minutes}분 후 돌아옵니다';
                          } else {
                            returnTimeText = '약 ${minutes}분 후 돌아옵니다';
                          }
                        } else {
                          returnTimeText = '곧 돌아옵니다';
                        }
                      }

                      return Column(
                        children: [
                          Text(
                            "'$friendNickname' 님에게 가있습니다.",
                            style: const TextStyle(fontSize: 16, color: Colors.blueGrey),
                          ),
                          if (returnTimeText.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange[200]!),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.access_time, size: 16, color: Colors.orange[700]),
                                  const SizedBox(width: 6),
                                  Text(
                                    returnTimeText,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.orange[900],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 15),
                          ElevatedButton.icon(
                            onPressed: () async {
                              // 펫 회수 로직
                              try {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(friendDoc!.id)
                                    .update({
                                  'current_pets': FieldValue.arrayRemove([petData]),
                                  'last_update': FieldValue.serverTimestamp(),
                                });

                                if (mounted) {
                                  Navigator.pop(context); // 다이얼로그 닫기
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("'$displayName'이(가) 돌아왔습니다!")),
                                  );
                                }
                              } catch (e) {
                                debugPrint("회수 실패: $e");
                              }
                            },
                            icon: const Icon(Icons.undo),
                            label: const Text('돌아오기'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      );
                    } else {
                      // 집에 있는 경우 (보내기 가능)
                      return Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.home, size: 16, color: Colors.green[700]),
                                const SizedBox(width: 6),
                                Text(
                                  '집에 있습니다',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.green[900],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 15),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context); // 상세창 닫기
                              _showFriendSelection(pet, petNicknames); // 친구 선택창 열기
                            },
                            icon: const Icon(Icons.send),
                            label: const Text('친구에게 보내기'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              backgroundColor: Colors.pink,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      );
                    }
                  },
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

  void _showMessageDialog(String friendId, String friendNickname, Map<String, String> pet, Map<String, String> petNicknames) {
    showDialog(
      context: context,
      builder: (context) => _SendMessageDialog(
        friendNickname: friendNickname,
        onSend: (message) {
          Navigator.pop(context); // 메시지 다이얼로그 닫기
          _sendPetToFriend(friendId, friendNickname, pet, petNicknames, message);
        },
      ),
    );
  }

  // --- 2. 보낼 친구 선택하기 (친구 목록 불러오기) ---
  void _showFriendSelection(Map<String, String> pet, Map<String, String> petNicknames) {
    // 설정된 닉네임이 있으면 사용, 없으면 기본 이름 사용
    final displayName = petNicknames[pet['value']] ?? pet['name']!;
    
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
                '$displayName을(를) 누구에게 보낼까요?',
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
                          onTap: () async {
                            // 친구의 마당(current_pets) 상태 확인
                            try {
                              final friendDoc = await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(friendId)
                                  .get();
                              
                              if (friendDoc.exists) {
                                final friendData = friendDoc.data() as Map<String, dynamic>;
                                final currentPets = friendData['current_pets'] as List<dynamic>? ?? [];
                                
                                if (currentPets.length >= 3) {
                                  if (context.mounted) {
                                    Navigator.pop(context); // 친구 선택창 닫기
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("'$friendNickname' 님의 마당이 꽉 찼어요! (3마리)"),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  }
                                  return;
                                }
                              }
                            } catch (e) {
                              debugPrint('친구 상태 확인 실패: $e');
                            }

                            if (context.mounted) {
                              Navigator.pop(context); // 친구 선택창 닫기
                              _showMessageDialog(friendId, friendNickname, pet, petNicknames);
                            }
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
      String friendId, String friendNickname, Map<String, String> pet, Map<String, String> petNicknames, String message) async {
    try {
      final myId = widget.myId;
      final myNickname = _myNickname ?? myId;
      final petValue = pet['value']!;
      // 설정된 닉네임이 있으면 사용, 없으면 기본 이름 사용
      final petName = petNicknames[petValue] ?? pet['name']!;

      final friendRef = FirebaseFirestore.instance.collection('users').doc(friendId);
      
      final newPetData = {
        'value': petValue,
        'sender': myId,
        'sender_nickname': myNickname,
        'message': message,
        'return_time': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 1))),
      };

      await friendRef.update({
        'current_pets': FieldValue.arrayUnion([newPetData]),
        'last_update': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$friendNickname 님에게 $petName을(를) 보냈어요!'),
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

                  // 펫 닉네임 가져오기
                  final petNicknames = (data?['pet_nicknames'] as Map<String, dynamic>?)?.map(
                    (key, value) => MapEntry(key, value.toString())
                  ) ?? <String, String>{};

                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: myPetList.length,
                    itemBuilder: (context, index) {
                      final pet = myPetList[index];
                      // 설정된 닉네임이 있으면 사용, 없으면 기본 이름 사용
                      final displayName = petNicknames[pet['value']] ?? pet['name']!;
                      return GestureDetector(
                        onTap: () => _showPetDetail(pet, petNicknames),
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
                              Text(displayName,
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