import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
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

  // 用來追蹤類別輸入框的文字 (做智慧過濾用)
  final searchText = "".obs;

  // 圖片路徑
  final menuImagePath = RxnString();

  // 勾選狀態
  final selectedLocationIds = <String>{}.obs;
  final selectedTimeSlotIds = <String>{}.obs;

  String? _editingId;

  @override
  void onInit() {
    super.onInit();
    // 監聽類別輸入框，當文字改變時更新 searchText
    categoryController.addListener(() {
      searchText.value = categoryController.text;
    });
  }

  // --- 計算屬性：過濾後的類別列表 ---
  List<String> get filteredCategories {
    // 1. 拿到所有不重複類別
    final allCats = db.restaurants
        .map((e) => e.category)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    allCats.sort();

    // 2. 如果沒輸入文字，回傳全部
    if (searchText.value.isEmpty) {
      return allCats;
    }

    // 3. 有輸入文字，做模糊比對
    return allCats.where((cat) => cat.contains(searchText.value)).toList();
  }

  // --- 點擊標籤填入 ---
  void setCategoryText(String text) {
    categoryController.text = text;
    // 游標移動到最後
    categoryController.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
  }

  // --- 選擇圖片 ---
  Future<void> pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        // 1. 取得 App 的永久文件目錄
        final directory = await getApplicationDocumentsDirectory();

        // 2. 產生一個不重複的檔名 (使用 UUID + 原本的副檔名，例如 .jpg)
        final String fileName =
            '${const Uuid().v4()}${p.extension(image.path)}';

        // 3. 完整的儲存路徑
        final String savedPath = '${directory.path}/$fileName';

        // 4. 將暫存圖片「複製」到永久路徑
        await File(image.path).copy(savedPath);

        // 5. 存入變數
        menuImagePath.value = savedPath;
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

      // 設定類別並手動觸發 searchText 更新
      categoryController.text = existingItem.category;
      searchText.value = existingItem.category;

      contactController.text = existingItem.contactInfo ?? "";
      menuImagePath.value = existingItem.menuImage;
      selectedLocationIds.assignAll(existingItem.locationIds);
      selectedTimeSlotIds.assignAll(existingItem.timeSlotIds);
    } else {
      _editingId = null;
      nameController.clear();
      categoryController.clear();
      searchText.value = ""; // 清空搜尋文字
      contactController.clear();
      menuImagePath.value = null;
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
      menuImage: menuImagePath.value,
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
