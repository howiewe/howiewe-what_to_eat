import 'package:flutter/foundation.dart'; // 用來判斷 kDebugMode
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:uuid/uuid.dart';

import '../models/location_model.dart';
import '../models/time_slot_model.dart';
import '../models/restaurant_model.dart';
import '../models/history_model.dart';
import '../data_seeder.dart'; // 引入剛剛建立的種子資料檔

class DatabaseService extends GetxService {
  final _box = GetStorage();
  final _uuid = const Uuid();

  // Observable Lists (UI 會監聽這些變數)
  final locations = <LocationModel>[].obs;
  final timeSlots = <TimeSlotModel>[].obs;
  final restaurants = <RestaurantModel>[].obs;
  final history = <HistoryModel>[].obs;

  Future<DatabaseService> init() async {
    await GetStorage.init();
    _loadData(); // 啟動時載入資料
    return this;
  }

  /// 核心載入邏輯：決定要用「存檔」還是「預設種子」
  void _loadData() {
    
    // ==========================================
    // 1. 載入 Locations (地區)
    // ==========================================
    List? storedLocs = _box.read('locations');
    if (storedLocs != null && storedLocs.isNotEmpty) {
      // (A) 有存檔：轉成物件放入 List
      locations.assignAll(storedLocs.map((e) => LocationModel.fromJson(e)).toList());
    } else {
      // (B) 沒存檔 (第一次開啟)：載入 DataSeeder 預設值
      if (kDebugMode) {
        print("🛠️ [Debug Mode] 載入 Location 測試資料");
        locations.assignAll(DataSeeder.devLocations);
      } else {
        debugPrint("🚀 [Release Mode] 載入 Location 正式預設值");
        locations.assignAll(DataSeeder.prodLocations);
      }
      _saveLocations(); // 載入後馬上存檔，下次開啟就會變成 (A) 流程
    }

    // ==========================================
    // 2. 載入 TimeSlots (時段)
    // ==========================================
    List? storedSlots = _box.read('timeSlots');
    if (storedSlots != null && storedSlots.isNotEmpty) {
      timeSlots.assignAll(storedSlots.map((e) => TimeSlotModel.fromJson(e)).toList());
    } else {
      if (kDebugMode) {
        print("🛠️ [Debug Mode] 載入 TimeSlot 測試資料");
        timeSlots.assignAll(DataSeeder.devTimeSlots);
      } else {
        debugPrint("🚀 [Release Mode] 載入 TimeSlot 正式預設值");
        timeSlots.assignAll(DataSeeder.prodTimeSlots);
      }
      _saveTimeSlots();
    }

    // ==========================================
    // 3. 載入 Restaurants (餐廳)
    // ==========================================
    List? storedRests = _box.read('restaurants');
    if (storedRests != null && storedRests.isNotEmpty) {
      restaurants.assignAll(storedRests.map((e) => RestaurantModel.fromJson(e)).toList());
    } else {
      if (kDebugMode) {
        print("🛠️ [Debug Mode] 載入 Restaurant 測試資料");
        restaurants.assignAll(DataSeeder.devRestaurants);
      } else {
        debugPrint("🚀 [Release Mode] 載入 Restaurant 正式預設值 (通常為空)");
        restaurants.assignAll(DataSeeder.prodRestaurants);
      }
      _saveRestaurants();
    }

    // ==========================================
    // 4. 載入 History (歷史紀錄)
    // ==========================================
    // 歷史紀錄不需要種子資料，空的就好
    List? storedHistory = _box.read('history');
    if (storedHistory != null) {
      history.assignAll(storedHistory.map((e) => HistoryModel.fromJson(e)).toList());
    }
  }

  // --- 以下為儲存與增刪改查邏輯 (保持不變) ---

  void _saveLocations() => _box.write('locations', locations.map((e) => e.toJson()).toList());
  void _saveTimeSlots() => _box.write('timeSlots', timeSlots.map((e) => e.toJson()).toList());
  void _saveRestaurants() => _box.write('restaurants', restaurants.map((e) => e.toJson()).toList());
  void _saveHistory() => _box.write('history', history.map((e) => e.toJson()).toList());

  // Location CRUD
  void addLocation(String name) {
    locations.add(LocationModel(id: _uuid.v4(), name: name));
    _saveLocations();
  }

  void addLocationWithId(String id, String name) {
    locations.add(LocationModel(id: id, name: name));
    _saveLocations();
  }

  void updateLocation(LocationModel item) {
    int index = locations.indexWhere((e) => e.id == item.id);
    if (index != -1) {
      locations[index] = item;
      _saveLocations();
    }
  }

  void deleteLocation(String id) {
    locations.removeWhere((e) => e.id == id);
    _saveLocations();
    // 關聯刪除：如果地區刪了，餐廳裡的 locationId 也要移除
    for (var r in restaurants) {
      if (r.locationIds.contains(id)) {
        r.locationIds.remove(id);
      }
    }
    _saveRestaurants();
  }

  // Restaurant CRUD
  void addRestaurant(RestaurantModel item) {
    restaurants.add(item);
    _saveRestaurants();
  }

  void updateRestaurant(RestaurantModel item) {
    int index = restaurants.indexWhere((e) => e.id == item.id);
    if (index != -1) {
      restaurants[index] = item;
      _saveRestaurants();
    }
  }

  void deleteRestaurant(String id) {
    restaurants.removeWhere((e) => e.id == id);
    _saveRestaurants();
  }

  // TimeSlot CRUD
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
    // 關聯刪除
    for (var r in restaurants) {
      if (r.timeSlotIds.contains(id)) {
        r.timeSlotIds.remove(id);
      }
    }
    _saveRestaurants();
  }

  // History Logic
  void addToHistory(String name) {
    history.insert(
      0,
      HistoryModel(
        id: _uuid.v4(),
        restaurantName: name,
        timestamp: DateTime.now().toIso8601String(),
      ),
    );
    // 只保留最近 20 筆
    if (history.length > 20) history.removeLast();
    _saveHistory();
  }
}