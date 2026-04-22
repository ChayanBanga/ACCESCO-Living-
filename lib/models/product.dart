class Product {
  final int id;
  final String name;
  final String description;
  final double price;
  final String category;
  final String emoji;
  final String? imageUrl; // New field for image URL

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.emoji,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'emoji': emoji,
      'imageUrl': imageUrl,
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      price: json['price'].toDouble(),
      category: json['category'],
      emoji: json['emoji'],
      imageUrl: json['imageUrl'],
    );
  }
}
