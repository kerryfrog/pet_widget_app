import 'package:pet_widget_app/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart'; // Import Apple Sign-In

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: DefaultFirebaseOptions.currentPlatform.iosClientId,
  );

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

  // 애플 로그인
  Future<UserCredential?> signInWithApple() async {
    try {
      // 1. 애플에서 인증 정보 가져오기
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // 2. Firebase용 Credential 생성 (이 코드로 교체하세요)
      final OAuthCredential credential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // 3. Firebase 로그인
      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      return userCredential;
    } catch (e) {
      print("Apple Login Error: $e");
      return null;
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}

