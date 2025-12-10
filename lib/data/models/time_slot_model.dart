class TimeSlotModel {
  String id;
  String name;
  String startTime; // 格式 "06:00"
  String endTime; // 格式 "10:30"
  bool skipCategory; // 是否跳過分類選擇 (例: 飲料時段)

  TimeSlotModel({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.skipCategory = false,
  });

  factory TimeSlotModel.fromJson(Map<String, dynamic> json) => TimeSlotModel(
    id: json['id'],
    name: json['name'],
    startTime: json['startTime'],
    endTime: json['endTime'],
    skipCategory: json['skipCategory'] ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'startTime': startTime,
    'endTime': endTime,
    'skipCategory': skipCategory,
  };
}
