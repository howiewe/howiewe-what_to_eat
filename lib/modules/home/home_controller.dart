import 'dart:math';
import 'package:get/get.dart';
import '../../data/services/database_service.dart';
import '../../data/models/location_model.dart';
import '../../data/models/time_slot_model.dart';
import '../../data/models/restaurant_model.dart';

class HomeController extends GetxController {
  final db = Get.find<DatabaseService>();

  // --- 狀態變數 (UI 會監聽這些) ---
  final currentLocation = Rxn<LocationModel>();
  final currentTimeSlot = Rxn<TimeSlotModel>();
  final isRandomMode = false.obs; // false = 引導模式(預設), true = 隨機模式
  final currentResult = Rxn<RestaurantModel>(); // 抽到的結果
  final isRolling = false.obs; // 是否正在跑動畫

  @override
  void onInit() {
    super.onInit();
    // 1. 設定預設地區 (拿列表第一個)
    if (db.locations.isNotEmpty) {
      currentLocation.value = db.locations.first;
    }
    // 2. 自動偵測時段
    detectTimeSlot();
  }

  // --- 核心功能：偵測時間 ---
  void detectTimeSlot() {
    final now = DateTime.now();
    // 格式化為 HH:mm 字串以便比對
    String nowStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    // 尋找符合的時段
    // 邏輯：如果 Start < End (一般時段 11:00-14:00)，則 Start <= Now <= End
    // 邏輯：如果 Start > End (跨日 22:00-02:00)，則 Now >= Start 或 Now <= End
    try {
      var match = db.timeSlots.firstWhere((slot) {
        if (slot.startTime.compareTo(slot.endTime) < 0) {
          return nowStr.compareTo(slot.startTime) >= 0 &&
              nowStr.compareTo(slot.endTime) <= 0;
        } else {
          return nowStr.compareTo(slot.startTime) >= 0 ||
              nowStr.compareTo(slot.endTime) <= 0;
        }
      });
      currentTimeSlot.value = match;

      // 特殊邏輯：如果是飲料時段(skipCategory=true)，自動切換為隨機模式
      if (match.skipCategory) {
        isRandomMode.value = true;
      }
    } catch (e) {
      // 沒對中任何時段，預設選第一個
      if (db.timeSlots.isNotEmpty) currentTimeSlot.value = db.timeSlots.first;
    }
  }

  // --- 核心功能：切換模式 ---
  void toggleMode() {
    isRandomMode.toggle();
  }

  // --- 核心功能：開始決定 (Roll) ---
  Future<void> startRoll() async {
    if (currentLocation.value == null || currentTimeSlot.value == null) return;

    // 簡單動畫效果
    isRolling.value = true;
    currentResult.value = null; // 清空上次結果
    await Future.delayed(const Duration(milliseconds: 800)); // 假裝在思考

    // 1. 篩選符合 地區 & 時段 的餐廳
    var candidates = db.restaurants.where((r) {
      bool locMatch = r.locationIds.contains(currentLocation.value!.id);
      bool timeMatch = r.timeSlotIds.contains(currentTimeSlot.value!.id);
      return locMatch && timeMatch;
    }).toList();

    if (candidates.isEmpty) {
      isRolling.value = false;
      Get.snackbar("哎呀", "這個時段與地區沒有設定餐廳資料！");
      return;
    }

    // 2. 判斷模式
    if (isRandomMode.value || currentTimeSlot.value!.skipCategory) {
      // [隨機模式] 直接抽
      _pickFinal(candidates);
    } else {
      // [引導模式] 這裡應該彈出分類選擇，為了簡化流程，我們先做「隨機抽分類 -> 再抽餐廳」
      // 實際上你會希望這裡彈出 BottomSheet 讓使用者選分類，我們先自動化
      _pickFinal(candidates);
    }
  }

  void _pickFinal(List<RestaurantModel> candidates) {
    final random = Random();
    currentResult.value = candidates[random.nextInt(candidates.length)];
    isRolling.value = false;

    // 自動存入歷史紀錄
    if (currentResult.value != null) {
      db.addToHistory(currentResult.value!.name);
    }
  }

  // 讓 View 可以呼叫切換地點
  void changeLocation(LocationModel loc) => currentLocation.value = loc;

  // 讓 View 可以呼叫切換時段
  void changeTimeSlot(TimeSlotModel slot) => currentTimeSlot.value = slot;
}
