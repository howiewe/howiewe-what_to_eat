import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/services/database_service.dart';
import '../../data/models/location_model.dart';
import '../../data/models/time_slot_model.dart';
import '../../data/models/restaurant_model.dart';

class HomeController extends GetxController {
  final db = Get.find<DatabaseService>();

  // --- 狀態變數 ---
  final currentLocation = Rxn<LocationModel>();
  final currentTimeSlot = Rxn<TimeSlotModel>();
  final isRandomMode = false.obs;
  final currentResult = Rxn<RestaurantModel>();
  final isRolling = false.obs;

  // --- 新增：不重複邏輯控制變數 ---
  final _shownRestaurantIds = <String>{}; // 記錄這一輪已經抽過的 ID
  String? _selectedCategory; // 記錄引導模式下目前鎖定的類別

  @override
  void onInit() {
    super.onInit();
    if (db.locations.isNotEmpty) {
      currentLocation.value = db.locations.first;
    }
    detectTimeSlot();
  }

  // --- 核心功能：偵測時間 ---
  void detectTimeSlot() {
    final now = DateTime.now();
    String nowStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    try {
      // 只偵測「有設定時間」的時段
      var match = db.timeSlots.firstWhere((slot) {
        // 如果該時段沒設定時間，直接跳過不偵測
        if (slot.startTime == null || slot.endTime == null) return false;

        if (slot.startTime!.compareTo(slot.endTime!) < 0) {
          return nowStr.compareTo(slot.startTime!) >= 0 &&
              nowStr.compareTo(slot.endTime!) <= 0;
        } else {
          return nowStr.compareTo(slot.startTime!) >= 0 ||
              nowStr.compareTo(slot.endTime!) <= 0;
        }
      });
      currentTimeSlot.value = match;
      _resetSession();

      if (match.skipCategory) {
        isRandomMode.value = true;
      }
    } catch (e) {
      // 沒對中任何時段，預設選第一個 (無論有沒有時間)
      if (db.timeSlots.isNotEmpty) currentTimeSlot.value = db.timeSlots.first;
    }
  }

  // --- 切換模式/地區/時段時，都要重置「已抽過名單」 ---
  void toggleMode() {
    isRandomMode.toggle();
    _resetSession();
  }

  void changeLocation(LocationModel loc) {
    currentLocation.value = loc;
    _resetSession();
  }

  void changeTimeSlot(TimeSlotModel slot) {
    currentTimeSlot.value = slot;
    _resetSession();
  }

  // 私有方法：重置抽籤區間
  void _resetSession() {
    _shownRestaurantIds.clear();
    _selectedCategory = null; // 清除鎖定的類別
    currentResult.value = null; // 清除目前的結果卡片
  }

  // --- 核心功能：開始決定 (Roll) ---
  Future<void> startRoll() async {
    if (currentLocation.value == null || currentTimeSlot.value == null) return;

    // 1. 撈出該地區 & 該時段的所有候選名單
    var baseCandidates = db.restaurants.where((r) {
      bool locMatch = r.locationIds.contains(currentLocation.value!.id);
      bool timeMatch = r.timeSlotIds.contains(currentTimeSlot.value!.id);
      return locMatch && timeMatch;
    }).toList();

    if (baseCandidates.isEmpty) {
      Get.snackbar("哎呀", "這個時段與地區沒有設定餐廳資料！");
      return;
    }

    // 2. 判斷路徑
    // 路徑 A: 隨機模式 或 強制隨機(如飲料時段)
    if (isRandomMode.value || currentTimeSlot.value!.skipCategory) {
      _rollFromList(baseCandidates);
    }
    // 路徑 B: 引導模式
    else {
      // 如果已經選過類別了 (例如按了重抽)，就直接用鎖定的類別繼續抽
      if (_selectedCategory != null) {
        var filtered = baseCandidates.where((r) {
          String rCat = r.category.isEmpty ? "未分類" : r.category;
          return rCat == _selectedCategory;
        }).toList();
        _rollFromList(filtered);
      }
      // 如果還沒選類別，彈出選單
      else {
        final categories = baseCandidates
            .map((e) => e.category.isEmpty ? "未分類" : e.category)
            .toSet()
            .toList();

        if (categories.length <= 1) {
          // 只有一種分類就不問了，直接當作已選擇
          _selectedCategory = categories.first;
          _rollFromList(baseCandidates);
        } else {
          _showCategoryPicker(categories, baseCandidates);
        }
      }
    }
  }

  // --- 真正執行抽籤與過濾重複的邏輯 ---
  Future<void> _rollFromList(List<RestaurantModel> candidates) async {
    // 1. 過濾掉「這一輪已經顯示過」的餐廳
    var available = candidates
        .where((r) => !_shownRestaurantIds.contains(r.id))
        .toList();

    // 2. 如果全部都抽完了 (Empty)
    if (available.isEmpty) {
      // --- 修改點 A: 提示改從上方滑下，樣式更顯眼 ---
      Get.snackbar(
        "一輪結束",
        "該範圍的餐廳都看過一遍囉！名單已重置，請重新開始。",
        snackPosition: SnackPosition.TOP, // 改成 TOP
        backgroundColor: Colors.black.withOpacity(0.8), // 深色背景
        colorText: Colors.white,
        margin: const EdgeInsets.all(10), // 懸浮感
        borderRadius: 10,
        icon: const Icon(Icons.refresh, color: Colors.white),
        duration: const Duration(seconds: 3),
      );

      // --- 修改點 B: 重置並回到開始畫面 ---
      _shownRestaurantIds.clear(); // 清空已讀紀錄 (重洗牌)
      currentResult.value = null; // 設為 null 會讓 UI 自動跳回 StartCard
      isRolling.value = false; // 確保動畫狀態停止

      return; // 直接結束函式，不進行下面的抽籤
    }

    // 3. 動畫開始
    isRolling.value = true;
    currentResult.value = null; // 先清空讓 UI 轉圈圈
    await Future.delayed(const Duration(milliseconds: 800));

    // 4. 隨機選出一個
    final random = Random();
    final result = available[random.nextInt(available.length)];

    // 5. 更新狀態
    currentResult.value = result; // UI 會顯示結果卡片
    isRolling.value = false;

    // 6. 標記為已顯示 (下次就不會出現)
    _shownRestaurantIds.add(result.id);

    // 7. 存入歷史
    db.addToHistory(result.name);
  }

  // --- 顯示類別選擇器 ---
  void _showCategoryPicker(
    List<String> categories,
    List<RestaurantModel> allCandidates,
  ) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Get.theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "你想吃哪一類？",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: categories.map((cat) {
                return ActionChip(
                  label: Text(cat),
                  onPressed: () {
                    Get.back();
                    // 設定鎖定類別，這樣按「重抽」時就不會再問
                    _selectedCategory = cat;
                    // 執行抽籤
                    startRoll();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Get.back();
                  // 使用者選擇「都可以」，視為切換到隨機模式
                  isRandomMode.value = true;
                  startRoll();
                },
                child: const Text("都可以，直接抽！"),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }
}
