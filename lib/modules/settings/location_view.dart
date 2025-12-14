import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/services/database_service.dart';
import '../../data/models/location_model.dart';

class LocationController extends GetxController {
  final db = Get.find<DatabaseService>();
  final nameController = TextEditingController();
  String? _editingId; // 記錄正在編輯的 ID (null 代表新增)

  // 開啟編輯器
  void openEditor([LocationModel? item]) {
    if (item != null) {
      _editingId = item.id;
      nameController.text = item.name;
    } else {
      _editingId = null;
      nameController.clear();
    }
  }

  // 儲存
  void save() {
    if (nameController.text.isEmpty) {
      Get.snackbar("錯誤", "請輸入地區名稱");
      return;
    }

    if (_editingId != null) {
      // 更新
      final newItem = LocationModel(id: _editingId!, name: nameController.text);
      db.updateLocation(newItem);
    } else {
      // 新增
      db.addLocation(nameController.text);
    }
    Get.back(); // 關閉 BottomSheet
  }

  // 刪除
  void delete(String id) {
    // 防呆：如果只剩最後一個地區，不建議刪除，否則 App 會沒地區可用
    if (db.locations.length <= 1) {
      Get.snackbar("無法刪除", "至少需要保留一個地區設定");
      return;
    }
    db.deleteLocation(id);
  }
}

class LocationView extends StatelessWidget {
  const LocationView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(LocationController());

    return Scaffold(
      appBar: AppBar(title: const Text("地區設定")),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditor(context, controller),
        child: const Icon(Icons.add),
      ),
      body: Obx(() => ListView.separated(
        itemCount: controller.db.locations.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = controller.db.locations[index];
          return Dismissible(
            key: Key(item.id),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            // 加入確認對話框以免誤刪
            confirmDismiss: (direction) async {
              if (controller.db.locations.length <= 1) {
                Get.snackbar("無法刪除", "至少需要保留一個地區設定");
                return false;
              }
              return true; 
            },
            onDismissed: (_) => controller.delete(item.id),
            child: ListTile(
              leading: const Icon(Icons.location_on, color: Colors.grey),
              title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.edit, size: 16, color: Colors.grey),
              onTap: () => _showEditor(context, controller, item),
            ),
          );
        },
      )),
    );
  }

  void _showEditor(BuildContext context, LocationController controller, [LocationModel? item]) {
    controller.openEditor(item);

    Get.bottomSheet(
      Container(
        padding: EdgeInsets.fromLTRB(
          20, 
          20, 
          20, 
          MediaQuery.of(context).viewInsets.bottom + 20 // 底部留出鍵盤高度 + 緩衝
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(item == null ? "新增地區" : "編輯地區", 
                 style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            TextField(
              controller: controller.nameController,
              autofocus: true, // 自動跳出鍵盤
              decoration: const InputDecoration(
                labelText: "地區名稱 (如: 家, 公司, 學校)", 
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_city),
              ),
            ),
            
            const SizedBox(height: 20),
            FilledButton(
              onPressed: controller.save,
              child: const Text("儲存"),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }
}