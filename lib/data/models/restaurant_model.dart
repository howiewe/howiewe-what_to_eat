class RestaurantModel {
  String id;
  String name;
  List<String> locationIds; // 支援多地區
  List<String> timeSlotIds; // 支援多時段
  String category; // 類別名稱 (如: 餃子, 麵食)，若無則為空
  String? contactInfo; // 電話或網址
  String? menuImage; // 菜單圖片路徑 (選填)

  RestaurantModel({
    required this.id,
    required this.name,
    required this.locationIds,
    required this.timeSlotIds,
    required this.category,
    this.contactInfo,
    this.menuImage,
  });

  factory RestaurantModel.fromJson(Map<String, dynamic> json) =>
      RestaurantModel(
        id: json['id'],
        name: json['name'],
        locationIds: List<String>.from(json['locationIds']),
        timeSlotIds: List<String>.from(json['timeSlotIds']),
        category: json['category'],
        contactInfo: json['contactInfo'],
        menuImage: json['menuImage'],
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'locationIds': locationIds,
    'timeSlotIds': timeSlotIds,
    'category': category,
    'contactInfo': contactInfo,
    'menuImage': menuImage,
  };
}
