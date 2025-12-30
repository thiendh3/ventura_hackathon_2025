class Recipe {
  final String name;
  final String instructions;
  final String imageUrl;

  Recipe({
    required this.name,
    required this.instructions,
    required this.imageUrl
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      name: json['name'],
      instructions: json['instructions'],
      imageUrl: json['imageUrl']
    );
  }
}
