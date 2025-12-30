import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:flutter_spinkit/flutter_spinkit.dart';

import 'auth_provider.dart';
// import 'favorites.dart';
// import 'menu.dart';
import 'pantry.dart';
// import 'shopping_list.dart';
import 'search_provider.dart';
import 'allergen_profile_provider.dart';
import 'allergen_chatbot_screen.dart';

Future<void> main() async {
  await supabase.Supabase.initialize(
    url: 'supabase_url',
    anonKey: 'anon_key',
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => SearchProvider()),
        ChangeNotifierProvider(create: (context) => AuthProvider()),
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
      // title: 'ChefMateAI',
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
      // Menu(),
      // Favorites(),
      // ShoppingList()
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
                'Loading...',
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
      // bottomNavigationBar: BottomNavigationBar(
      //   currentIndex: _currentIndex,
      //   onTap: (index) {
      //     setState(() {
      //       _currentIndex = index;
      //     });
      //   },
      //   type: BottomNavigationBarType.fixed,
      //   items: const [
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.kitchen),
      //       label: 'Pantry',
      //     ),
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.menu_book),
      //       label: 'Menu',
      //     ),
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.favorite),
      //       label: 'Favorites',
      //     ),
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.shopping_cart),
      //       label: 'Shopping List',
      //     ),
      //   ],
      // ),
    );
  }
}
