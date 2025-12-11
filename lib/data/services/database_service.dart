import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/location_model.dart';
import '../models/time_slot_model.dart';
import '../models/restaurant_model.dart';
import '../models/history_model.dart';

class DatabaseService extends GetxService {
  final _box = GetStorage();
  final _uuid = const Uuid();

  final locations = <LocationModel>[].obs;
  final timeSlots = <TimeSlotModel>[].obs;
  final restaurants = <RestaurantModel>[].obs;
  final history = <HistoryModel>[].obs;

  Future<DatabaseService> init() async {
    await GetStorage.init();
    _loadData();
    return this;
  }

  void _loadData() {
    // 讀取 Locations
    List? storedLocs = _box.read('locations');
    if (storedLocs != null) {
      locations.assignAll(
        storedLocs.map((e) => LocationModel.fromJson(e)).toList(),
      );
    } else {
      locations.addAll([
        LocationModel(id: _uuid.v4(), name: "家裡附近"),
        LocationModel(id: _uuid.v4(), name: "公司附近"),
      ]);
      _saveLocations();
    }

    // 讀取 TimeSlots
    List? storedSlots = _box.read('timeSlots');
    if (storedSlots != null) {
      timeSlots.assignAll(
        storedSlots.map((e) => TimeSlotModel.fromJson(e)).toList(),
      );
    } else {
      timeSlots.addAll([
        TimeSlotModel(
          id: _uuid.v4(),
          name: "早餐",
          startTime: "05:00",
          endTime: "10:30",
        ),
        TimeSlotModel(
          id: _uuid.v4(),
          name: "午餐",
          startTime: "11:00",
          endTime: "14:00",
        ),
        TimeSlotModel(
          id: _uuid.v4(),
          name: "下午茶",
          startTime: "14:01",
          endTime: "17:00",
          skipCategory: true,
        ),
        TimeSlotModel(
          id: _uuid.v4(),
          name: "晚餐",
          startTime: "17:01",
          endTime: "20:00",
        ),
        TimeSlotModel(
          id: _uuid.v4(),
          name: "消夜",
          startTime: "20:01",
          endTime: "04:59",
        ),
      ]);
      _saveTimeSlots();
    }

    // 讀取 Restaurants
    List? storedRests = _box.read('restaurants');
    if (storedRests != null) {
      restaurants.assignAll(
        storedRests.map((e) => RestaurantModel.fromJson(e)).toList(),
      );
    } else {
      restaurants.add(
        RestaurantModel(
          id: _uuid.v4(),
          name: "麥當勞",
          locationIds: locations.map((e) => e.id).toList(),
          timeSlotIds: timeSlots.map((e) => e.id).toList(),
          category: "速食",
        ),
      );
      _saveRestaurants();
    }

    // 讀取 History
    List? storedHistory = _box.read('history');
    if (storedHistory != null) {
      history.assignAll(
        storedHistory.map((e) => HistoryModel.fromJson(e)).toList(),
      );
    }
  }

  // --- Save Methods ---
  void _saveLocations() =>
      _box.write('locations', locations.map((e) => e.toJson()).toList());
  void _saveTimeSlots() =>
      _box.write('timeSlots', timeSlots.map((e) => e.toJson()).toList());
  void _saveRestaurants() =>
      _box.write('restaurants', restaurants.map((e) => e.toJson()).toList());
  void _saveHistory() =>
      _box.write('history', history.map((e) => e.toJson()).toList());

  // --- Actions ---
  void addLocation(String name) {
    locations.add(LocationModel(id: _uuid.v4(), name: name));
    _saveLocations();
  }

  // --- 新增：更新地區 ---
  void updateLocation(LocationModel item) {
    int index = locations.indexWhere((e) => e.id == item.id);
    if (index != -1) {
      locations[index] = item;
      _saveLocations();
    }
  }

  // --- 新增：刪除地區 ---
  void deleteLocation(String id) {
    locations.removeWhere((e) => e.id == id);
    _saveLocations();

    // 清理關聯：從所有餐廳中移除這個地區 ID
    for (var r in restaurants) {
      if (r.locationIds.contains(id)) {
        r.locationIds.remove(id);
      }
    }
    _saveRestaurants();
  }

  void addRestaurant(RestaurantModel item) {
    restaurants.add(item);
    _saveRestaurants();
  }

  void addTimeSlot(TimeSlotModel item) {
    timeSlots.add(item);
    _saveTimeSlots();
  }

  void updateTimeSlot(TimeSlotModel item) {
    int index = timeSlots.indexWhere((e) => e.id == item.id);
    if (index != -1) {
      timeSlots[index] = item;
      _saveTimeSlots();
    }
  }

  void deleteTimeSlot(String id) {
    timeSlots.removeWhere((e) => e.id == id);
    _saveTimeSlots();
    
    // 選項：刪除時段後，是否要從所有餐廳中移除該時段ID？
    // 為了資料乾淨，建議移除
    for (var r in restaurants) {
      if (r.timeSlotIds.contains(id)) {
        r.timeSlotIds.remove(id);
      }
    }
    _saveRestaurants();
  }

  // 這次新增的：更新餐廳
  void updateRestaurant(RestaurantModel item) {
    int index = restaurants.indexWhere((e) => e.id == item.id);
    if (index != -1) {
      restaurants[index] = item;
      _saveRestaurants();
    }
  }

  // 這次新增的：刪除餐廳
  void deleteRestaurant(String id) {
    restaurants.removeWhere((e) => e.id == id);
    _saveRestaurants();
  }

  void addToHistory(String name) {
    history.insert(
      0,
      HistoryModel(
        id: _uuid.v4(),
        restaurantName: name,
        timestamp: DateTime.now().toIso8601String(),
      ),
    );
    if (history.length > 20) history.removeLast();
    _saveHistory();
  }
}
