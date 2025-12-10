import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart'; // 圖片選擇器
import 'package:uuid/uuid.dart';
import '../../data/services/database_service.dart';
import '../../data/models/restaurant_model.dart';

class SettingsController extends GetxController {
  final db = Get.find<DatabaseService>();
  final _picker = ImagePicker();

  // --- 表單控制變數 ---
  final nameController = TextEditingController();
  final categoryController = TextEditingController();
  final contactController = TextEditingController();

  // 圖片路徑 (Observable)
  final menuImagePath = RxnString();

  // 勾選狀態
  final selectedLocationIds = <String>{}.obs;
  final selectedTimeSlotIds = <String>{}.obs;

  String? _editingId;

  // --- 選擇圖片 ---
  Future<void> pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        menuImagePath.value = image.path;
      }
    } catch (e) {
      Get.snackbar("錯誤", "無法選取圖片: $e");
    }
  }

  // --- 移除圖片 ---
  void removeImage() {
    menuImagePath.value = null;
  }

  // --- 開啟編輯視窗 ---
  void openEditor([RestaurantModel? existingItem]) {
    if (existingItem != null) {
      _editingId = existingItem.id;
      nameController.text = existingItem.name;
      categoryController.text = existingItem.category;
      contactController.text = existingItem.contactInfo ?? "";
      menuImagePath.value = existingItem.menuImage; // 載入舊圖片路徑
      selectedLocationIds.assignAll(existingItem.locationIds);
      selectedTimeSlotIds.assignAll(existingItem.timeSlotIds);
    } else {
      _editingId = null;
      nameController.clear();
      categoryController.clear();
      contactController.clear();
      menuImagePath.value = null; // 清空圖片
      selectedLocationIds.clear();
      selectedTimeSlotIds.clear();

      if (db.locations.length == 1) {
        selectedLocationIds.add(db.locations.first.id);
      }
    }
  }

  // --- 儲存資料 ---
  void saveItem() {
    if (nameController.text.isEmpty) {
      Get.snackbar("欄位錯誤", "餐廳名稱不能為空");
      return;
    }
    if (selectedLocationIds.isEmpty || selectedTimeSlotIds.isEmpty) {
      Get.snackbar("欄位錯誤", "請至少選擇一個地區和時段");
      return;
    }

    final newItem = RestaurantModel(
      id: _editingId ?? const Uuid().v4(),
      name: nameController.text,
      category: categoryController.text,
      contactInfo: contactController.text.isEmpty
          ? null
          : contactController.text,
      menuImage: menuImagePath.value, // 儲存圖片路徑
      locationIds: selectedLocationIds.toList(),
      timeSlotIds: selectedTimeSlotIds.toList(),
    );

    if (_editingId != null) {
      db.updateRestaurant(newItem);
    } else {
      db.addRestaurant(newItem);
    }

    Get.back();
  }

  // --- 刪除 ---
  void deleteItem(String id) {
    db.deleteRestaurant(id);
  }

  void toggleLocation(String id) {
    if (selectedLocationIds.contains(id)) {
      selectedLocationIds.remove(id);
    } else {
      selectedLocationIds.add(id);
    }
  }

  void toggleTimeSlot(String id) {
    if (selectedTimeSlotIds.contains(id)) {
      selectedTimeSlotIds.remove(id);
    } else {
      selectedTimeSlotIds.add(id);
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    categoryController.dispose();
    contactController.dispose();
    super.onClose();
  }
}
