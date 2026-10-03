import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/app_user.dart';
import 'login_screen.dart';
import 'admin_dashboard.dart';
import 'employee_dashboard.dart';

/// Checks whether a Firebase Auth session already exists when the app
/// starts, and routes straight to the right dashboard if so — instead of
/// always showing the login screen even when the person never logged out.
/// Firebase Auth persists sessions across app restarts by default; this
/// widget is what actually makes use of that instead of ignoring it.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final firebaseUser = snapshot.data;
        if (firebaseUser == null) {
          return const LoginScreen();
        }

        return FutureBuilder<AppUser>(
          future: AuthService().getUserProfile(firebaseUser.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (profileSnapshot.hasError || !profileSnapshot.hasData) {
              // Signed in with Firebase, but no matching Firestore users/{uid}
              // doc (e.g. it was deleted while they were still logged in
              // elsewhere). Don't get stuck — offer a way out.
              return _BrokenSessionScreen(onSignOut: () => AuthService().logout());
            }
            final user = profileSnapshot.data!;
            return user.isOwner ? AdminDashboard(user: user) : EmployeeDashboard(user: user);
          },
        );
      },
    );
  }
}

class _BrokenSessionScreen extends StatelessWidget {
  final VoidCallback onSignOut;
  const _BrokenSessionScreen({required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              const Text(
                'You\'re signed in, but no matching account profile was found. '
                'Please sign out and log in again, or contact your Owner/Admin.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onSignOut, child: const Text('Sign Out')),
            ],
          ),
        ),
      ),
    );
  }
}
