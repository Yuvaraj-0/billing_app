import 'dart:convert';

class PackageItem {
  String itemName;
  double? price; // Optional: null for package items; can be set on bill page

  PackageItem({
    required this.itemName,
    this.price,
  });

  bool get isIncluded => price == null || price == 0;

  Map<String, dynamic> toMap() => {
    'itemName': itemName,
    'price': price,
  };

  factory PackageItem.fromMap(Map<String, dynamic> map) => PackageItem(
    itemName: map['itemName'] as String? ?? '',
    price: (map['price'] as num?)?.toDouble(),
  );

  String toJson() => json.encode(toMap());
  factory PackageItem.fromJson(String source) =>
      PackageItem.fromMap(json.decode(source) as Map<String, dynamic>);
}

class PackageModel {
  String id;
  String name;
  String? description;
  double? comboPrice; // Single total package price for the entire package
  List<PackageItem> items;

  PackageModel({
    required this.id,
    required this.name,
    this.description,
    this.comboPrice,
    List<PackageItem>? items,
  }) : items = items ?? [];

  double? get packagePrice => comboPrice;
  set packagePrice(double? val) => comboPrice = val;

  double get itemsTotal =>
      items.fold(0.0, (sum, item) => sum + (item.price ?? 0.0));

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'comboPrice': comboPrice,
    'items': items.map((i) => i.toMap()).toList(),
  };

  factory PackageModel.fromMap(Map<String, dynamic> map) => PackageModel(
    id: map['id'] as String? ?? '',
    name: map['name'] as String? ?? '',
    description: map['description'] as String?,
    comboPrice: (map['comboPrice'] as num?)?.toDouble(),
    items: (map['items'] as List<dynamic>?)
            ?.map((i) =>
                PackageItem.fromMap(Map<String, dynamic>.from(i as Map)))
            .toList() ??
        [],
  );

  String toJson() => json.encode(toMap());
  factory PackageModel.fromJson(String source) =>
      PackageModel.fromMap(json.decode(source) as Map<String, dynamic>);

  static List<PackageModel> get defaultPackages => [
    PackageModel(
      id: 'marriage_pkg',
      name: 'Marriage Package',
      description: 'Complete wedding photography, videography & premium album',
      comboPrice: 80000,
      items: [
        PackageItem(itemName: 'Traditional Photography (2 Days)'),
        PackageItem(itemName: 'Candid Photography (Bride & Groom)'),
        PackageItem(itemName: 'Cinematic Wedding Film & Teaser'),
        PackageItem(itemName: 'Drone Aerial Shoot'),
        PackageItem(itemName: 'Premium Wedding Album (40 Sheets)'),
      ],
    ),
    PackageModel(
      id: 'engagement_pkg',
      name: 'Engagement Package',
      description: 'Event photo, highlight teaser and photo album',
      comboPrice: 28000,
      items: [
        PackageItem(itemName: 'Event Photography'),
        PackageItem(itemName: 'Cinematic Video Highlights'),
        PackageItem(itemName: 'Photo Album (25 Sheets)'),
      ],
    ),
    PackageModel(
      id: 'birthday_pkg',
      name: 'Birthday Party Package',
      description: 'Birthday celebration photo, reel video and mini book',
      comboPrice: 14000,
      items: [
        PackageItem(itemName: 'Birthday Event Photography'),
        PackageItem(itemName: 'Video Reels & Highlights'),
        PackageItem(itemName: 'Mini Photo Book (20 Pages)'),
      ],
    ),
    PackageModel(
      id: 'babyshower_pkg',
      name: 'Baby Shower / Maternity',
      description: 'Creative shoot, function coverage and teaser',
      comboPrice: 18000,
      items: [
        PackageItem(itemName: 'Maternity / Function Shoot'),
        PackageItem(itemName: 'Creative Video Teaser'),
        PackageItem(itemName: 'Mounted Photo Frame & Album'),
      ],
    ),
  ];
}
