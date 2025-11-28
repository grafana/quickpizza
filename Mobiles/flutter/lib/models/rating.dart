class Rating {
  final int id;
  final int pizzaId;
  final int stars;
  final int userId;

  Rating({
    required this.id,
    required this.pizzaId,
    required this.stars,
    required this.userId,
  });

  factory Rating.fromJson(Map<String, dynamic> json) {
    return Rating(
      id: json['id'] as int,
      pizzaId: json['pizza_id'] as int,
      stars: json['stars'] as int,
      userId: json['user_id'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pizza_id': pizzaId,
      'stars': stars,
    };
  }
}

