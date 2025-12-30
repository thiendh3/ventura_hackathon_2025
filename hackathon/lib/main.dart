import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import 'pantry.dart';
import 'search_provider.dart';
import 'allergen_profile_provider.dart';
import 'allergen_chatbot_screen.dart';

Future<void> main() async {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => SearchProvider()),
        ChangeNotifierProvider(create: (context) => AllergenProfileProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.pink,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late List<Widget> _tabs;
  bool _isCheckingProfile = true;

  @override
  void initState() {
    super.initState();
    _tabs = [
      Pantry(),
    ];
    _checkProfileAndNavigate();
  }

  Future<void> _checkProfileAndNavigate() async {
    final allergenProvider = Provider.of<AllergenProfileProvider>(context, listen: false);
    await allergenProvider.loadProfile();

    if (mounted) {
      final hasProfile = await allergenProvider.checkHasProfile();
      setState(() => _isCheckingProfile = false);

      if (!hasProfile) {
        // Navigate to chatbot screen
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const AllergenChatbotScreen()),
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingProfile) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SpinKitPouringHourGlass(
                color: Color(0xFF4ECDC4),
                size: 50,
              ),
              const SizedBox(height: 16),
              Text(
                'Đang tải...',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: _tabs[_currentIndex],
    );
  }
}
