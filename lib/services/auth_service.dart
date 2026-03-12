import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import 'user_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();

  // Stream listening to auth state changes
  Stream<User?> get user => _auth.authStateChanges();

  // Get current user id
  String? get currentUserId => _auth.currentUser?.uid;

  // Sign In with email & password
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } catch (e) {
      throw Exception('Failed to sign in: ${e.toString()}');
    }
  }

  // Register with email & password
  Future<User?> registerWithEmail(String email, String password, String name) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update display name internally
      await credential.user?.updateDisplayName(name);
      
      // Create user profile in Firestore
      if (credential.user != null) {
        AppUser newUser = AppUser(
          uid: credential.user!.uid,
          email: credential.user!.email!,
          displayName: name,
        );
        await _userService.createUser(newUser);
      }
      
      return credential.user;
    } catch (e) {
      throw Exception('Failed to register: ${e.toString()}');
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Forgot Password
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
