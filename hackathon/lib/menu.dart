import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

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
      print('Failed to fetch recipes: ${response.statusCode}');
    }
    } catch (error) {
      print('Error: $error');
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
          print('Failed to fetch images: ${response.statusCode}');
        }
      } catch (error) {
        print('Error: $error');
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
        title: const Text('Menu'),
        centerTitle: true,
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
