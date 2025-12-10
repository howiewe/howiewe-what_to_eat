class HistoryModel {
  String id;
  String restaurantName; // 存名稱，避免餐廳被刪除後紀錄壞掉
  String timestamp; // ISO 8601 String

  HistoryModel({
    required this.id,
    required this.restaurantName,
    required this.timestamp,
  });

  factory HistoryModel.fromJson(Map<String, dynamic> json) => HistoryModel(
    id: json['id'],
    restaurantName: json['restaurantName'],
    timestamp: json['timestamp'],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'restaurantName': restaurantName,
    'timestamp': timestamp,
  };
}
