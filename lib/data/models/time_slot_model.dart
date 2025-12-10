class TimeSlotModel {
  String id;
  String name;
  String? startTime; // 改成可為空 (HH:mm)
  String? endTime;   // 改成可為空 (HH:mm)
  bool skipCategory; // 是否跳過分類 (隨機模式)

  // 判斷是否為「不限時間」的時段
  bool get isAllDay => startTime == null || endTime == null;

  TimeSlotModel({
    required this.id,
    required this.name,
    this.startTime,
    this.endTime,
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