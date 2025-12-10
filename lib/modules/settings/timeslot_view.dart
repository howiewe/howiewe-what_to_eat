import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../data/services/database_service.dart';
import '../../data/models/time_slot_model.dart';

class TimeSlotController extends GetxController {
  final db = Get.find<DatabaseService>();
  
  // 編輯用的變數
  final nameController = TextEditingController();
  final isTimeEnabled = true.obs; // 是否啟用時間限制
  final skipCategory = false.obs; // 是否跳過分類
  final startTime = Rxn<TimeOfDay>();
  final endTime = Rxn<TimeOfDay>();
  
  String? _editingId; // 記錄正在編輯的ID

  // 開啟編輯器
  void openEditor([TimeSlotModel? item]) {
    if (item != null) {
      _editingId = item.id;
      nameController.text = item.name;
      skipCategory.value = item.skipCategory;
      
      if (item.startTime != null && item.endTime != null) {
        isTimeEnabled.value = true;
        startTime.value = _stringToTime(item.startTime!);
        endTime.value = _stringToTime(item.endTime!);
      } else {
        isTimeEnabled.value = false;
        startTime.value = const TimeOfDay(hour: 12, minute: 0);
        endTime.value = const TimeOfDay(hour: 13, minute: 0);
      }
    } else {
      _editingId = null;
      nameController.clear();
      isTimeEnabled.value = true; // 預設開啟
      skipCategory.value = false;
      startTime.value = const TimeOfDay(hour: 12, minute: 0);
      endTime.value = const TimeOfDay(hour: 13, minute: 0);
    }
  }

  // 儲存
  void save() {
    if (nameController.text.isEmpty) {
      Get.snackbar("錯誤", "請輸入時段名稱");
      return;
    }

    String? startStr;
    String? endStr;

    if (isTimeEnabled.value) {
      if (startTime.value == null || endTime.value == null) {
        Get.snackbar("錯誤", "請設定時間範圍");
        return;
      }
      startStr = _timeToString(startTime.value!);
      endStr = _timeToString(endTime.value!);
    }

    final newItem = TimeSlotModel(
      id: _editingId ?? const Uuid().v4(),
      name: nameController.text,
      startTime: startStr,
      endTime: endStr,
      skipCategory: skipCategory.value,
    );

    if (_editingId != null) {
      db.updateTimeSlot(newItem);
    } else {
      db.addTimeSlot(newItem);
    }
    Get.back();
  }

  // 輔助：TimeOfDay <-> String
  TimeOfDay _stringToTime(String s) {
    final parts = s.split(":");
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
  
  String _timeToString(TimeOfDay t) {
    return "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
  }
  
  // 選擇時間 UI
  Future<void> pickTime(BuildContext context, bool isStart) async {
    final initial = isStart ? startTime.value : endTime.value;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial ?? TimeOfDay.now(),
    );
    if (picked != null) {
      if (isStart) startTime.value = picked;
      else endTime.value = picked;
    }
  }
}

class TimeSlotView extends StatelessWidget {
  const TimeSlotView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(TimeSlotController());

    return Scaffold(
      appBar: AppBar(title: const Text("時段設定")),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditor(context, controller),
        child: const Icon(Icons.add),
      ),
      body: Obx(() => ListView.separated(
        itemCount: controller.db.timeSlots.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = controller.db.timeSlots[index];
          return Dismissible(
            key: Key(item.id),
            direction: DismissDirection.endToStart,
            background: Container(color: Colors.red, child: const Icon(Icons.delete, color: Colors.white)),
            onDismissed: (_) => controller.db.deleteTimeSlot(item.id),
            child: ListTile(
              title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                item.isAllDay ? "不限時間 (手動選擇)" : "${item.startTime} - ${item.endTime}",
                style: TextStyle(color: item.isAllDay ? Colors.blue : Colors.grey),
              ),
              trailing: item.skipCategory 
                  ? const Chip(label: Text("強制隨機", style: TextStyle(fontSize: 10))) 
                  : const Icon(Icons.edit, size: 16),
              onTap: () => _showEditor(context, controller, item),
            ),
          );
        },
      )),
    );
  }

  void _showEditor(BuildContext context, TimeSlotController controller, [TimeSlotModel? item]) {
    controller.openEditor(item);
    
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(item == null ? "新增時段" : "編輯時段", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            // 名稱
            TextField(
              controller: controller.nameController,
              decoration: const InputDecoration(labelText: "時段名稱 (如: 飲料, 早午餐)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),

            // 是否設定時間開關
            Obx(() => SwitchListTile(
              title: const Text("設定自動偵測時間"),
              subtitle: const Text("若關閉則此時段只能手動選擇"),
              value: controller.isTimeEnabled.value,
              onChanged: (v) => controller.isTimeEnabled.value = v,
              contentPadding: EdgeInsets.zero,
            )),

            // 時間選擇器 (只有開啟時顯示)
            Obx(() {
              if (!controller.isTimeEnabled.value) return const SizedBox.shrink();
              return Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => controller.pickTime(context, true),
                      child: Text(controller.startTime.value?.format(context) ?? "開始時間"),
                    ),
                  ),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("至")),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => controller.pickTime(context, false),
                      child: Text(controller.endTime.value?.format(context) ?? "結束時間"),
                    ),
                  ),
                ],
              );
            }),

            // 強制隨機開關
            Obx(() => CheckboxListTile(
              title: const Text("跳過類型選擇 (強制隨機)"),
              subtitle: const Text("適合飲料、甜點等不分種類的項目"),
              value: controller.skipCategory.value,
              onChanged: (v) => controller.skipCategory.value = v!,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            )),

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