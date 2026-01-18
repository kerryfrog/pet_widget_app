import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FriendListScreen extends StatefulWidget {
  final String? myId;

  const FriendListScreen({super.key, required this.myId});

  @override
  State<FriendListScreen> createState() => _FriendListScreenState();
}

class _FriendListScreenState extends State<FriendListScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  String? _myNickname;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMyNickname();
  }

  Future<void> _loadMyNickname() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _myNickname = prefs.getString('my_nickname') ?? widget.myId;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // --- 친구 요청 보내기 ---
  Future<bool> _sendFriendRequest() async {
    final targetNicknameInput = _searchController.text.trim();
    final myId = widget.myId;

    if (myId == null) return false;
    if (targetNicknameInput.isEmpty) return false;
    
    // 키보드 내리기
    FocusScope.of(context).unfocus();

    try {
      final firestore = FirebaseFirestore.instance;

      // 1. 닉네임으로 사용자 ID 찾기
      final nicknameDoc = await firestore.collection('nicknames').doc(targetNicknameInput).get();
      
      if (!nicknameDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('존재하지 않는 닉네임입니다.')),
          );
        }
        return false;
      }

      final targetId = nicknameDoc.data()?['userId'];

      if (targetId == null) {
         if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('사용자 정보를 찾을 수 없습니다.')),
          );
        }
        return false;
      }

      if (targetId == myId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('자기 자신에게는 요청할 수 없습니다.')),
        );
        return false;
      }

      // 2. 이미 친구이거나 요청 중인지 확인
      final myFriendDoc = await firestore
          .collection('users')
          .doc(myId)
          .collection('friends')
          .doc(targetId)
          .get();

      if (myFriendDoc.exists) {
        final status = myFriendDoc.data()?['status'];
        String msg = '';
        if (status == 'accepted') msg = '이미 등록된 친구입니다.';
        if (status == 'pending_sent') msg = '이미 요청을 보냈습니다.';
        if (status == 'pending_received') msg = '상대방이 이미 요청을 보냈습니다. 받은 요청을 확인하세요.';
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
        return false;
      }

      // 3. 양쪽 유저에게 데이터 쓰기 (Batch)
      final batch = firestore.batch();

      // 내 쪽: 보낸 요청 상태로 저장
      final mySideRef = firestore
          .collection('users')
          .doc(myId)
          .collection('friends')
          .doc(targetId);
      
      batch.set(mySideRef, {
        'id': targetId,
        'nickname': targetNicknameInput, // 입력한 닉네임 저장
        'status': 'pending_sent',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 상대 쪽: 받은 요청 상태로 저장
      final targetSideRef = firestore
          .collection('users')
          .doc(targetId)
          .collection('friends')
          .doc(myId);

      batch.set(targetSideRef, {
        'id': myId,
        'nickname': _myNickname, // 내 닉네임 저장
        'status': 'pending_received',
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      _searchController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('친구 요청을 보냈습니다.')),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류 발생: $e')),
        );
      }
      return false;
    }
  }

  // --- 친구 추가 다이얼로그 ---
  void _showAddFriendDialog() {
    _searchController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('친구 추가'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            labelText: '친구 닉네임',
            hintText: '친구의 닉네임을 입력하세요',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await _sendFriendRequest();
              if (success && mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('요청 보내기'),
          ),
        ],
      ),
    );
  }

  // --- 친구 요청 수락 ---
  Future<void> _acceptRequest(String friendId, String friendNickname) async {
    final myId = widget.myId;
    if (myId == null) return;

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      // 내 쪽: accepted로 변경
      final mySideRef = firestore
          .collection('users')
          .doc(myId)
          .collection('friends')
          .doc(friendId);
      
      batch.update(mySideRef, {'status': 'accepted'});

      // 상대 쪽: accepted로 변경
      final targetSideRef = firestore
          .collection('users')
          .doc(friendId)
          .collection('friends')
          .doc(myId);
      
      // 혹시 상대방이 그사이 내 닉네임을 변경했을 수도 있으니 내 닉네임 업데이트
      batch.update(targetSideRef, {
        'status': 'accepted',
        'nickname': _myNickname ?? myId, 
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('친구 요청을 수락했습니다!')),
        );
      }
    } catch (e) {
      debugPrint('수락 실패: $e');
    }
  }

  // --- 삭제/거절/취소 ---
  Future<void> _deleteFriendOrRequest(String friendId) async {
    final myId = widget.myId;
    if (myId == null) return;

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      // 내 문서 삭제
      final mySideRef = firestore
          .collection('users')
          .doc(myId)
          .collection('friends')
          .doc(friendId);
      batch.delete(mySideRef);

      // 상대 문서 삭제
      final targetSideRef = firestore
          .collection('users')
          .doc(friendId)
          .collection('friends')
          .doc(myId);
      batch.delete(targetSideRef);

      await batch.commit();

       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제되었습니다.')),
        );
      }
    } catch (e) {
      debugPrint('삭제 실패: $e');
    }
  }

  // --- 리스트 아이템 빌더 ---
  Widget _buildFriendList(String status) {
    if (widget.myId == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.myId)
          .collection('friends')
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('오류 발생'));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          if (status == 'accepted') {
            return const Center(child: Text('등록된 친구가 없습니다.\n아이디를 검색해 친구를 추가해보세요!', textAlign: TextAlign.center));
          } else {
            return const Center(child: Text('받은 친구 요청이 없습니다.'));
          }
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final id = data['id'];
            final nickname = data['nickname'] ?? id;

            if (status == 'accepted') {
              // --- 친구 목록 ---
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: const Icon(Icons.person, color: Colors.blue),
                ),
                title: Text(nickname, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: IconButton(
                  icon: const Icon(Icons.person_remove, color: Colors.grey),
                  onPressed: () => _showDeleteDialog(id, nickname),
                ),
              );
            } else {
              // --- 받은 요청 목록 ---
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.mail_outline, color: Colors.blue),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '$nickname 님의 친구 요청',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _deleteFriendOrRequest(id),
                            child: const Text('거절', style: TextStyle(color: Colors.grey)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _acceptRequest(id, nickname),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('수락'),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }

  void _showDeleteDialog(String id, String nickname) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('친구 삭제'),
        content: Text('$nickname 님을 친구 목록에서 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteFriendOrRequest(id);
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('친구'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(text: '내 친구'),
            Tab(text: '받은 요청'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 탭 1: 내 친구 목록
          _buildFriendList('accepted'),
          // 탭 2: 받은 요청
          _buildFriendList('pending_received'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddFriendDialog,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}