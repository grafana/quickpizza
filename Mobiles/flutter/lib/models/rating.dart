class Rating {
  final int id;
  final int pizzaId;
  final int stars;

  Rating({required this.id, required this.pizzaId, required this.stars});

  factory Rating.fromJson(Map<String, dynamic> json) {
    return Rating(
      id: json['id'] as int,
      pizzaId: json['pizza_id'] as int,
      stars: json['stars'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {'pizza_id': pizzaId, 'stars': stars};
  }
}
