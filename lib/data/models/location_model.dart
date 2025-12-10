class LocationModel {
  String id;
  String name;

  LocationModel({required this.id, required this.name});

  factory LocationModel.fromJson(Map<String, dynamic> json) =>
      LocationModel(id: json['id'], name: json['name']);

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
