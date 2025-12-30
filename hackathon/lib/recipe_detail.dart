import 'package:flutter/material.dart';
import 'recipes.dart';

class RecipeDetail extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetail({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    String formattedInstructions = recipe.instructions.replaceAllMapped(
      RegExp(r'(\d\.)'),
      (match) => '\n${match.group(1)}',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            recipe.imageUrl.isNotEmpty
              ? Image.network(
                  recipe.imageUrl,
                  width: double.infinity,
                  height: 250,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: double.infinity,
                    height: 250,
                    color: Colors.grey,
                    child: const Icon(Icons.broken_image, size: 100, color: Colors.white),
                  ),
                )
              : Container(
                  width: double.infinity,
                  height: 250,
                  color: Colors.grey,
                  child: const Icon(Icons.image_not_supported, size: 100, color: Colors.white),
                ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                recipe.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Instructions",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formattedInstructions.trim(),
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
