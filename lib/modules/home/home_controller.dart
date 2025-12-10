import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart'; // 引入開啟網頁/電話的套件
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

  // --- 邏輯控制變數 (不重複抽籤用) ---
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
    String nowStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    try {
      // 只偵測「有設定時間」的時段
      var match = db.timeSlots.firstWhere((slot) {
        // 如果該時段沒設定時間，直接跳過不偵測
        if (slot.startTime == null || slot.endTime == null) return false;

        if (slot.startTime!.compareTo(slot.endTime!) < 0) {
          return nowStr.compareTo(slot.startTime!) >= 0 && nowStr.compareTo(slot.endTime!) <= 0;
        } else {
          return nowStr.compareTo(slot.startTime!) >= 0 || nowStr.compareTo(slot.endTime!) <= 0;
        }
      });
      currentTimeSlot.value = match;
      
      // 切換時段時，重置抽籤狀態
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
    var available = candidates.where((r) => !_shownRestaurantIds.contains(r.id)).toList();

    // 2. 如果全部都抽完了 (Empty)
    if (available.isEmpty) {
      Get.snackbar(
        "一輪結束", 
        "該範圍的餐廳都看過一遍囉！已回到初始狀態。", 
        snackPosition: SnackPosition.TOP, // 從上方滑下
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        colorText: Colors.white,
        margin: const EdgeInsets.all(10),
        borderRadius: 10,
        icon: const Icon(Icons.refresh, color: Colors.white),
        duration: const Duration(seconds: 3),
      );

      // --- 重置邏輯 ---
      _shownRestaurantIds.clear(); // 1. 清空已讀紀錄
      _selectedCategory = null;    // 2. 清空鎖定的類別 (這樣引導模式才會重新問你)
      currentResult.value = null;  // 3. 回到 StartCard
      isRolling.value = false;     
      
      return; 
    }

    // 3. 動畫開始
    isRolling.value = true;
    currentResult.value = null;
    await Future.delayed(const Duration(milliseconds: 800));

    // 4. 隨機選出一個
    final random = Random();
    final result = available[random.nextInt(available.length)];
    
    // 5. 更新狀態
    currentResult.value = result;
    isRolling.value = false;
    
    // 6. 標記為已顯示 (下次就不會出現)
    _shownRestaurantIds.add(result.id);

    // 7. 存入歷史
    db.addToHistory(result.name);
  }

  // --- 顯示類別選擇器 ---
  void _showCategoryPicker(List<String> categories, List<RestaurantModel> allCandidates) {
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
            const Text("你想吃哪一類？", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: categories.map((cat) {
                return ActionChip(
                  label: Text(cat),
                  onPressed: () {
                    Get.back();
                    // 設定鎖定類別
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

  // ==========================================
  //  新增：聯絡資訊處理 (電話/網址)
  // ==========================================

  // 判斷是否為網址
  bool isUrl(String contact) {
    return contact.startsWith('http') || contact.startsWith('www');
  }

  // 執行開啟動作
  Future<void> launchContactInfo(String contact) async {
    if (contact.isEmpty) return;

    final Uri uri;
    
    if (isUrl(contact)) {
      // 處理網址：如果是 www 開頭自動補上 https
      String urlStr = contact;
      if (!urlStr.startsWith('http')) {
        urlStr = 'https://$urlStr';
      }
      uri = Uri.parse(urlStr);
    } else {
      // 處理電話
      uri = Uri.parse('tel:$contact');
    }

    try {
      // 嘗試開啟
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        Get.snackbar("錯誤", "無法開啟: $contact");
      }
    } catch (e) {
      Get.snackbar("錯誤", "開啟失敗: $e");
    }
  }
}