import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_svg/flutter_svg.dart';

import 'auth_provider.dart';
import 'search_provider.dart';
import 'login_page.dart';
import 'recipes.dart';
import 'recipe_list.dart';
import 'user_page.dart';

class Menu extends StatefulWidget {
  const Menu({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MenuState createState() => _MenuState();
}

class _MenuState extends State<Menu> {
  bool isLoading = false;
  List<Recipe> recipes = [];
  List<dynamic> imageNameList = [];

  Future<void> fetchSuggestedRecipes(List<String> ingredients) async {
    if(ingredients.isEmpty) return;
    setState(() => isLoading = true);
    const String apiUrl = 'http://35.226.32.22:3000/api/v1/recipes/suggest';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'ingredients': ingredients}),
      );

      if (response.statusCode == 201) {
      final decodedBody = utf8.decode(response.bodyBytes);
      final data = jsonDecode(decodedBody)['recipes'] as List<dynamic>;
      imageNameList = data.map((item) => item['name_en'] ?? '').toList();
      List<String> imageUrlList = await fetchImageFromName(imageNameList);
      for (int i = 0; i < data.length; i++) {
        data[i]['imageUrl'] = imageUrlList[i];
      }

      setState(() => recipes = data.map((json) => Recipe.fromJson(json)).toList());
    } else {
    }
    } catch (error) {
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<List<String>> fetchImageFromName(List<dynamic> nameList) async {
    const String apiUrl = 'http://35.226.32.22:3000/api/v1/recipes/recipe_image';
    List<String> result = [];

    for (var name in nameList) {
      try {
        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'recipe_name': name}),
        );

        if (response.statusCode == 201) {
          final decodedBody = utf8.decode(response.bodyBytes);
          final data = jsonDecode(decodedBody);

          result.add(data['image_url']);
        } else {
        }
      } catch (error) {
      }
    }

    return result;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final searchValues = Provider.of<SearchProvider>(context, listen: false).searchValues;
    if (searchValues.isNotEmpty) {
      fetchSuggestedRecipes(searchValues);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    TextEditingController searchController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.person),
          onPressed: () {
            if (authProvider.isLoggedIn) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => UserPage()),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => LoginPage()),
              );
            }
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo SVG
            SvgPicture.string(
              '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" fill="#FFB3C6" stroke="#000000" stroke-width="2"></path><path d="M14.5 9.1c-.3-1.4-1.5-2.6-3-2.6-1.7 0-3.1 1.4-3.1 3.1 0 1.5.9 2.8 2.2 3.1" fill="none" stroke="#000000" stroke-width="2"></path><path d="M9.5 14.9c.3 1.4 1.5 2.6 3 2.6 1.7 0 3.1-1.4 3.1-3.1 0-1.5-.9-2.8-2.2-3.1" fill="none" stroke="#000000" stroke-width="2"></path></svg>''',
              width: 32,
              height: 32,
            ),
            const SizedBox(width: 8),
            // Text "Safein"
            const Text(
              'Safein',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Enter ingredients seperately by ","',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onSubmitted: (value) {
                final searchValues = value.split(',').map((e) => e.trim()).toList();
                Provider.of<SearchProvider>(context, listen: false).updateSearchValues(value);

                fetchSuggestedRecipes(searchValues);
              },
            ),
            const SizedBox(height: 32.0),
            Expanded(
              child: isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SpinKitPouringHourGlass(
                          color: Colors.green,
                          size: 50.0,
                        ),
                        SizedBox(height: 16.0),
                        Text('Cooking recipes, please wait...'),
                      ],
                    ),
                  )
                : recipes.isEmpty
                  ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.menu_book,
                        size: 100,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16.0),
                      const Text(
                        'Add your ingredients to get started',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
                : RecipeList(recipes: recipes),
            ),
          ],
        ),
      ),
    );
  }
}
