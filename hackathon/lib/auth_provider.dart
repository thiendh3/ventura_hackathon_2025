import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pantry.dart';

class AuthProvider with ChangeNotifier {
  bool _isLoggedIn = false;
  String? _userEmail;

  bool get isLoggedIn => _isLoggedIn;
  String? get userEmail => _userEmail;

  Future<void> loginUser(BuildContext context, String email, String password) async {
    final supabase = Supabase.instance.client;
    try {
      await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      // ignore: use_build_context_synchronously
      _isLoggedIn = true;
      // ignore: use_build_context_synchronously
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const Pantry()));
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Login Failed: $e'),
      ));
    } finally {
      notifyListeners();
    }
  }

  Future<void> signupUser(BuildContext context, String email, String password, String verifyPassword) async {
    final supabase = Supabase.instance.client;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    if (password != verifyPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    try {
      await supabase.auth.signUp(
        email: email,
        password: password,
      );
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar( const SnackBar(
        content: Text('Sign-up successful! Verify in your email to sign in!'),
      ));
      // ignore: use_build_context_synchronously
      Navigator.pop(context); 
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Sign-up Failed: $e'),
      ));
    } finally {
      notifyListeners();
    }
  }

  Future<void> logout(BuildContext context) async {
    final supabase = Supabase.instance.client;
    await supabase.auth.signOut();
    _isLoggedIn = false;
    _userEmail = null;
    // ignore: use_build_context_synchronously
    Navigator.pop(context); 
    notifyListeners();
  }
}
