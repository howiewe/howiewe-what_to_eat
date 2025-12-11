import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
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

  // --- 新增：控制頂部提示橫幅 ---
  final showResetBanner = false.obs;

  // --- 邏輯控制變數 ---
  final _shownRestaurantIds = <String>{}; 
  String? _selectedCategory; 

  @override
  void onInit() {
    super.onInit();
    if (db.locations.isNotEmpty) {
      currentLocation.value = db.locations.first;
    }
    detectTimeSlot();
  }

  void detectTimeSlot() {
    final now = DateTime.now();
    String nowStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    try {
      var match = db.timeSlots.firstWhere((slot) {
        if (slot.startTime == null || slot.endTime == null) return false;
        if (slot.startTime!.compareTo(slot.endTime!) < 0) {
          return nowStr.compareTo(slot.startTime!) >= 0 && nowStr.compareTo(slot.endTime!) <= 0;
        } else {
          return nowStr.compareTo(slot.startTime!) >= 0 || nowStr.compareTo(slot.endTime!) <= 0;
        }
      });
      currentTimeSlot.value = match;
      _resetSession(); 

      if (match.skipCategory) {
        isRandomMode.value = true;
      }
    } catch (e) {
      if (db.timeSlots.isNotEmpty) currentTimeSlot.value = db.timeSlots.first;
    }
  }

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

  void _resetSession() {
    _shownRestaurantIds.clear();
    _selectedCategory = null; 
    currentResult.value = null; 
    showResetBanner.value = false; // 重置時也隱藏橫幅
  }

  // --- 觸發一輪結束的提示 ---
  void _triggerResetMessage() {
    // 顯示橫幅
    showResetBanner.value = true;
    
    // 3秒後自動消失
    Future.delayed(const Duration(seconds: 3), () {
      showResetBanner.value = false;
    });

    // 重置邏輯
    _shownRestaurantIds.clear(); 
    _selectedCategory = null;    
    currentResult.value = null;  
    isRolling.value = false;     
  }

  Future<void> startRoll() async {
    // 防止重複點擊
    if (isRolling.value) return; 
    if (currentLocation.value == null || currentTimeSlot.value == null) return;

    var baseCandidates = db.restaurants.where((r) {
      bool locMatch = r.locationIds.contains(currentLocation.value!.id);
      bool timeMatch = r.timeSlotIds.contains(currentTimeSlot.value!.id);
      return locMatch && timeMatch;
    }).toList();

    if (baseCandidates.isEmpty) {
      Get.snackbar("哎呀", "這個時段與地區沒有設定餐廳資料！");
      return;
    }

    if (isRandomMode.value || currentTimeSlot.value!.skipCategory) {
      _rollFromList(baseCandidates);
    } else {
      if (_selectedCategory != null) {
        var filtered = baseCandidates.where((r) {
           String rCat = r.category.isEmpty ? "未分類" : r.category;
           return rCat == _selectedCategory;
        }).toList();
        _rollFromList(filtered);
      } else {
        final categories = baseCandidates
            .map((e) => e.category.isEmpty ? "未分類" : e.category)
            .toSet()
            .toList();

        if (categories.length <= 1) {
          _selectedCategory = categories.first; 
          _rollFromList(baseCandidates);
        } else {
          _showCategoryPicker(categories, baseCandidates);
        }
      }
    }
  }

  Future<void> _rollFromList(List<RestaurantModel> candidates) async {
    var available = candidates.where((r) => !_shownRestaurantIds.contains(r.id)).toList();

    if (available.isEmpty) {
      // 改用自訂方法，不再呼叫 Get.snackbar
      _triggerResetMessage();
      return; 
    }

    isRolling.value = true;
    // 開始轉之前，先隱藏提示 (如果有的話)
    showResetBanner.value = false;
    currentResult.value = null;
    
    await Future.delayed(const Duration(milliseconds: 800));

    final random = Random();
    final result = available[random.nextInt(available.length)];
    
    currentResult.value = result;
    isRolling.value = false;
    
    _shownRestaurantIds.add(result.id);
  }

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
                    // 這裡的 Get.back 絕對安全，因為沒有 Snackbar 干擾
                    Get.back();
                    _selectedCategory = cat;
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

  void confirmSelection() {
    if (currentResult.value != null) {
      db.addToHistory(currentResult.value!.name);
      // 清空結果，UI 會自動回到 StartCard
      currentResult.value = null; 
      isRolling.value = false;
    }
  }

  bool isUrl(String contact) {
    return contact.startsWith('http') || contact.startsWith('www');
  }

  Future<void> launchContactInfo(String contact) async {
    // 1. 記錄並重置 UI (這行會把 currentResult 變 null)
    confirmSelection();

    if (contact.isEmpty) return;

    final Uri uri;
    if (isUrl(contact)) {
      String urlStr = contact;
      if (!urlStr.startsWith('http')) {
        urlStr = 'https://$urlStr';
      }
      uri = Uri.parse(urlStr);
    } else {
      uri = Uri.parse('tel:$contact');
    }

    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        Get.snackbar("錯誤", "無法開啟: $contact");
      }
    } catch (e) {
      Get.snackbar("錯誤", "開啟失敗: $e");
    }
  }
}