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

    ever(db.timeSlots, (List<TimeSlotModel> updatedList) {
      // 如果當前沒選時段，或是資料庫被清空，就不處理
      if (currentTimeSlot.value == null || updatedList.isEmpty) return;

      // 在新的列表中，尋找目前正在使用的時段 ID
      try {
        final updatedSlot = updatedList.firstWhere(
          (slot) => slot.id == currentTimeSlot.value!.id
        );

        // A. 更新手中的資料 (這樣 UI 顯示的名字才會變)
        currentTimeSlot.value = updatedSlot;

        // B. 重新檢查是否強制隨機
        if (updatedSlot.skipCategory) {
          // 如果變成了強制隨機，立刻切換模式
          isRandomMode.value = true;
        } 
        
        // C. 為了安全起見，重置當前的一輪狀態 (避免分類資料不一致)
        _resetSession();
        
      } catch (e) {
        // 如果找不到 ID (代表目前的時段被刪除了)，則重新偵測適合的時段
        detectTimeSlot();
      }
    });

  }

  

  // 1. [修正] 自動偵測時段
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
      
      // 使用統一的方法切換，避免邏輯重複
      changeTimeSlot(match);
      
    } catch (e) {
      if (db.timeSlots.isNotEmpty) {
        // 沒抓到時間就預設第一個，也走統一流程
        changeTimeSlot(db.timeSlots.first);
      }
    }
  }

  // 2. [修正] 手動切換時段
  void changeTimeSlot(TimeSlotModel slot) {
    currentTimeSlot.value = slot;
    _resetSession();

    // 關鍵修正：切換時段時，檢查是否為強制隨機
    if (slot.skipCategory) {
      isRandomMode.value = true;
    } else {
      // 這裡不一定要設回 false，因為使用者可能在午餐也想用隨機
      // 保持原本的 isRandomMode 狀態即可
    }
  }

  void changeLocation(LocationModel loc) {
    currentLocation.value = loc;
    _resetSession();
  }

  // 3. [修正] 切換模式按鈕
  void toggleMode() {
    // 如果當前時段是「強制隨機」，且現在已經是隨機模式，則禁止切換回引導
    if (currentTimeSlot.value?.skipCategory == true && isRandomMode.value) {
      Get.snackbar(
        "模式鎖定", 
        "此時段設定為強制隨機 (例如飲料/下午茶)，無法使用分類引導。",
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(20),
      );
      return; 
    }
    
    isRandomMode.toggle();
    _resetSession();
  }

  void _resetSession() {
    _shownRestaurantIds.clear();
    _selectedCategory = null; 
    currentResult.value = null; 
    showResetBanner.value = false;
  }

  void _triggerResetMessage() {
    showResetBanner.value = true;
    Future.delayed(const Duration(seconds: 3), () {
      showResetBanner.value = false;
    });
    _shownRestaurantIds.clear(); 
    _selectedCategory = null;    
    currentResult.value = null;  
    isRolling.value = false;     
  }

  Future<void> startRoll() async {
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

    // 這裡的邏輯原本是沒問題的，但配合上面的 changeTimeSlot 修正後 UI 會更一致
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
      _triggerResetMessage();
      return; 
    }

    isRolling.value = true;
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
                  // 這裡我們暫時開啟隨機模式，但只針對這一次
                  // 或者直接呼叫 _rollFromList(allCandidates)
                  _rollFromList(allCandidates);
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
      // 確認選擇後，重置 Session，避免下次誤判一輪結束
      _resetSession(); 
      isRolling.value = false;
    }
  }

  bool isUrl(String contact) {
    return contact.startsWith('http') || contact.startsWith('www');
  }

  Future<void> launchContactInfo(String contact) async {
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