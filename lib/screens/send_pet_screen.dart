import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import 'dart:math';
import 'dart:io';

// 펫 닉네임 수정 다이얼로그 위젯
class _NicknameEditDialog extends StatefulWidget {
  final Map<String, dynamic> pet;
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

      final userRef = FirebaseFirestore.instance.collection('users').doc(myId);
      final userDoc = await userRef.get();

      if (!userDoc.exists) {
        setState(() {
          _errorText = '사용자 정보를 찾을 수 없습니다.';
        });
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final Map<String, String> updatedPetNicknames =
          (userData['pet_nicknames'] as Map<String, dynamic>?)?.map(
                (key, value) => MapEntry(key, value.toString()),
              ) ??
              {};

      updatedPetNicknames[widget.pet['value']!] = nickname;

      await userRef.update({
        'pet_nicknames': updatedPetNicknames,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("'$nickname'으로 변경되었습니다!"),
            backgroundColor: Colors.blue,
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
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
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: const Text('저장'),
        ),
      ],
    );
  }
}

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
  RewardedAd? _rewardedAd;

  @override
  void initState() {
    super.initState();
    _loadMyNickname();
    _loadRewardedAd();
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    super.dispose();
  }

  String _getAdUnitId() {
    // Use test IDs for development. Replace with your own IDs for production.
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313';
    } else {
      return '';
    }
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: _getAdUnitId(),
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          setState(() {
            _rewardedAd = ad;
          });
        },
        onAdFailedToLoad: (error) {
          debugPrint('RewardedAd failed to load: $error');
        },
      ),
    );
  }

  void _showRewardedAd() {
    if (_rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadRewardedAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _loadRewardedAd();
        },
      );
      _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
        _grantDisposablePet();
      });
      // Nullify the ad after showing it to prevent reuse
      setState(() {
        _rewardedAd = null;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아직 광고가 준비되지 않았어요. 잠시 후 다시 시도해주세요.')),
      );
      // Try to load an ad again in case it failed before
      _loadRewardedAd();
    }
  }
  
  void _grantDisposablePet() {
    if (widget.myId != null) {
      final randomPet = petList[Random().nextInt(petList.length)];
      FirebaseFirestore.instance.collection('users').doc(widget.myId).update({
        'my_disposable_pets': FieldValue.arrayUnion([randomPet['value']])
      });
    }
  }

  Future<void> _loadMyNickname() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _myNickname = prefs.getString('my_nickname');
    });
  }

  void _getDisposablePet() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일회용 펫 얻기'),
        content: const Text('광고를 보고 일회용 펫을 얻으시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('확인')),
        ],
      ),
    );

    if (confirm == true) {
      _showRewardedAd();
    }
  }

  void _showNicknameEditDialog(Map<String, dynamic> pet, Map<String, String> petNicknames) {
    final petInfoForDialog = petList.firstWhere((p) => p['value'] == pet['value'], orElse: () => {'value': pet['value']!, 'name': 'Unknown Pet'});
    showDialog(
      context: context,
      builder: (context) => _NicknameEditDialog(
        pet: petInfoForDialog,
        currentNickname: petNicknames[pet['value']] ?? petInfoForDialog['name']!,
        onSaved: () {
          setState(() {});
        },
      ),
    );
  }

  void _showPetDetail(Map<String, dynamic> pet, Map<String, String> petNicknames) {
    final petInfo = petList.firstWhere((p) => p['value'] == pet['value'], orElse: () => {'value': pet['value']!, 'name': 'Unknown Pet'});
    final displayName = petNicknames[pet['value']] ?? petInfo['name']!;
    final bool isDisposable = pet['isDisposable'];
    final bool isSent = pet['isSent'];

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
                    if (!isDisposable)
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () {
                        Navigator.pop(context);
                        _showNicknameEditDialog(pet, petNicknames);
                      },
                      tooltip: '닉네임 수정',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(
                    'assets/images/${pet['value']}.png',
                    width: 120,
                    height: 120,
                  ),
                ),
                const SizedBox(height: 30),
                FutureBuilder<Map<String, dynamic>?>(
                  future: (() async {
                    if (widget.myId == null) return null;
                    final users = await FirebaseFirestore.instance.collection('users').get();
                    for (final doc in users.docs) {
                      final visitorsSnapshot = await doc.reference.collection('visitors').get();
                      for (var visitorDoc in visitorsSnapshot.docs) {
                        final visitorData = visitorDoc.data();
                        if (visitorData['sender'] == widget.myId && visitorData['value'] == pet['value']) {
                          return {'friendDoc': doc, 'petData': visitorData, 'visitorDocId': visitorDoc.id};
                        }
                      }
                    }
                    return null;
                  })(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }
                    if (snapshot.hasError) {
                      return const Text('상태를 확인할 수 없습니다.');
                    }
                    if (snapshot.data != null) {
                      final friendDoc = snapshot.data!['friendDoc'] as DocumentSnapshot;
                      final petData = snapshot.data!['petData'] as Map<String, dynamic>;
                      final visitorDocId = snapshot.data!['visitorDocId'] as String;
                      final friendData = friendDoc.data() as Map<String, dynamic>;
                      final friendNickname = friendData['nickname'] ?? '친구';
                      final returnTime = petData['return_time'] as Timestamp?;
                      String returnTimeText = '곧 돌아옵니다';
                      if (returnTime != null && returnTime.toDate().isAfter(DateTime.now())) {
                        final difference = returnTime.toDate().difference(DateTime.now());
                        final hours = difference.inHours;
                        final minutes = difference.inMinutes % 60;
                        if (hours > 0) {
                          returnTimeText = '약 ${hours}시간 ${minutes}분 후 돌아옵니다';
                        } else {
                          returnTimeText = '약 ${minutes}분 후 돌아옵니다';
                        }
                      }
                      return Column(
                        children: [
                          Text("'$friendNickname' 님에게 가있습니다."),
                          const SizedBox(height: 8),
                          Text(returnTimeText),
                          const SizedBox(height: 15),
                          ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                await FirebaseFirestore.instance.collection('users').doc(friendDoc.id).collection('visitors').doc(visitorDocId).delete();
                                if (mounted) {
                                  Navigator.pop(context);
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
                      if (isDisposable && isSent) {
                        WidgetsBinding.instance.addPostFrameCallback((_) async {
                           if (widget.myId != null) {
                              await FirebaseFirestore.instance.collection('users').doc(widget.myId).update({
                                'sent_disposable_pets': FieldValue.arrayRemove([pet['value']])
                              });
                           }
                           Navigator.pop(context);
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('일회용 펫이 사라졌습니다.')));
                        });
                        return const Text('펫이 돌아와 사라졌습니다.');
                      }

                      return Column(
                        children: [
                          const Text('집에 있습니다'),
                          const SizedBox(height: 15),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showFriendSelection(pet, petNicknames);
                            },
                            icon: const Icon(Icons.send),
                            label: const Text('친구에게 보내기'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              backgroundColor: Colors.blue,
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
                  child: const Text('닫기'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMessageDialog(String friendId, String friendNickname, Map<String, dynamic> pet, Map<String, String> petNicknames) {
    showDialog(
      context: context,
      builder: (context) => _SendMessageDialog(
        friendNickname: friendNickname,
        onSend: (message) {
          Navigator.pop(context);
          _sendPetToFriend(friendId, friendNickname, pet, petNicknames, message);
        },
      ),
    );
  }

  void _showFriendSelection(Map<String, dynamic> pet, Map<String, String> petNicknames) {
    final petInfo = petList.firstWhere((p) => p['value'] == pet['value'], orElse: () => {'value': pet['value']!, 'name': 'Unknown Pet'});
    final displayName = petNicknames[pet['value']] ?? petInfo['name']!;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$displayName을(를) 누구에게 보낼까요?'),
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(widget.myId).collection('friends').where('status', isEqualTo: 'accepted').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) return const Center(child: Text('보낼 친구가 없어요.'));
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final friendId = data['id'];
                        final storedNickname = data['nickname'] ?? friendId;

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(friendId).get(),
                          builder: (context, userSnapshot) {
                            String displayName = storedNickname;
                            if (userSnapshot.hasData && userSnapshot.data!.exists) {
                               final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                               displayName = userData['nickname'] ?? storedNickname;
                            }
                            return ListTile(
                              leading: const CircleAvatar(child: Icon(Icons.person)),
                              title: Text(displayName),
                              trailing: const Icon(Icons.send, color: Colors.blue),
                              onTap: () {
                                Navigator.pop(context);
                                _showMessageDialog(friendId, displayName, pet, petNicknames);
                              },
                            );
                          }
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

  Future<void> _sendPetToFriend(String friendId, String friendNickname, Map<String, dynamic> pet, Map<String, String> petNicknames, String message) async {
    final myId = widget.myId;
    if (myId == null) return;

    final petValue = pet['value']!;
    final isDisposable = pet['isDisposable'] as bool;
    final isSent = pet['isSent'] as bool;
    final petName = petNicknames[petValue] ?? petList.firstWhere((p) => p['value'] == petValue)['name']!;

    final friendRef = FirebaseFirestore.instance.collection('users').doc(friendId);
    final myRef = FirebaseFirestore.instance.collection('users').doc(myId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final newPetData = {
          'value': petValue,
          'sender': myId,
          'sender_nickname': _myNickname,
          'message': message,
          'return_time': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 1))),
        };
        transaction.set(friendRef.collection('visitors').doc(), newPetData);

        if (isDisposable && !isSent) {
          transaction.update(myRef, {
            'my_disposable_pets': FieldValue.arrayRemove([petValue]),
            'sent_disposable_pets': FieldValue.arrayUnion([petValue]),
          });
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$friendNickname 님에게 $petName을(를) 보냈어요!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('전송 실패: $e')));
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
            const Text("친구에게 보낼 펫을 선택하세요."),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(widget.myId).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final data = snapshot.data?.data() as Map<String, dynamic>?;
                  
                  final List<dynamic> myPets = data?['my_pets'] ?? [];
                  final List<dynamic> myDisposablePets = data?['my_disposable_pets'] ?? [];
                  final List<dynamic> sentDisposablePets = data?['sent_disposable_pets'] ?? [];
                  
                  final List<Map<String, dynamic>> allMyPetObjects = [
                    ...myPets.map((p) => {'value': p, 'isDisposable': false, 'isSent': false}),
                    ...myDisposablePets.map((p) => {'value': p, 'isDisposable': true, 'isSent': false}),
                    ...sentDisposablePets.map((p) => {'value': p, 'isDisposable': true, 'isSent': true}),
                  ];

                  final petNicknames = (data?['pet_nicknames'] as Map<String, dynamic>?)?.map(
                    (key, value) => MapEntry(key, value.toString())
                  ) ?? <String, String>{};

                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: allMyPetObjects.length + 1,
                    itemBuilder: (context, index) {
                      if (index == allMyPetObjects.length) {
                        return GestureDetector(
                          onTap: _getDisposablePet,
                          child: Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.add, size: 40, color: Colors.grey),
                          ),
                        );
                      }

                      final pet = allMyPetObjects[index];
                      final petInfo = petList.firstWhere((p) => p['value'] == pet['value'], orElse: () => {'value': pet['value']!, 'name': 'Unknown'});
                      final displayName = petNicknames[pet['value']] ?? petInfo['name']!;
                      final bool isDisposable = pet['isDisposable'];

                      return GestureDetector(
                        onTap: () => _showPetDetail(pet, petNicknames),
                        child: Card(
                          color: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset('assets/images/${pet['value']}.png', width: 80, height: 80),
                                  const SizedBox(height: 10),
                                  Text(displayName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              if (isDisposable)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text('1회', style: TextStyle(color: Colors.white, fontSize: 10)),
                                  ),
                                ),
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