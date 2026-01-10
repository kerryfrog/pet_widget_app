import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // 현재 로그인된 유저 스트림
  Stream<User?> get userChanges => _auth.authStateChanges();

  // 현재 유저 가져오기
  User? get currentUser => _auth.currentUser;

  // 구글 로그인
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // 1. 구글 로그인 흐름 시작
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // 사용자가 취소함

      // 2. 인증 정보 가져오기
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Firebase 자격 증명 생성
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Firebase에 로그인
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print("Google Login Error: $e");
      return null;
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
