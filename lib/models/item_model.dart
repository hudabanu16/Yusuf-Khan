class Item {
  final String name;
  final String description;
  final double quantity;
  final double unitPrice;

  Item({
    required this.name,
    this.description = '',
    required this.quantity,
    required this.unitPrice,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'quantity': quantity,
      'Unit Price': unitPrice,
    };
  }

  factory Item.fromFirestore(Map<String, dynamic> data) {
    return Item(
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      quantity: (data['quantity'] ?? 0).toDouble(),
      unitPrice: (data['unitPrice'] ?? 0).toDouble(),
    );
  }
}
