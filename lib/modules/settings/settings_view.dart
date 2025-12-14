import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'settings_controller.dart';
import '../../data/models/restaurant_model.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SettingsController());

    return Scaffold(
      appBar: AppBar(
        title: const Text("餐廳資料管理"),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(context, controller),
        icon: const Icon(Icons.add),
        label: const Text("新增餐廳"),
      ),
      body: Obx(() {
        if (controller.db.restaurants.isEmpty) {
          return Center(
            child: Text("目前沒有資料，趕快新增吧！", style: TextStyle(color: Colors.grey[500])),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: controller.db.restaurants.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = controller.db.restaurants[index];
            return Dismissible(
              key: Key(item.id),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (_) => controller.deleteItem(item.id),
              child: ListTile(
                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("${item.category} • 適用 ${item.timeSlotIds.length} 個時段"),
                trailing: const Icon(Icons.edit, size: 20, color: Colors.grey),
                onTap: () => _showEditor(context, controller, existingItem: item),
              ),
            );
          },
        );
      }),
    );
  }

  // --- 彈出編輯視窗 (Bottom Sheet) ---
  void _showEditor(BuildContext context, SettingsController controller, {RestaurantModel? existingItem}) {
    controller.openEditor(existingItem);

    Get.bottomSheet(
      Container(
        height: MediaQuery.of(context).size.height * 0.9,
        padding: EdgeInsets.fromLTRB(
          20, 
          20, 
          20, 
          MediaQuery.of(context).viewInsets.bottom + 20
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 標題列
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(existingItem == null ? "新增餐廳" : "編輯餐廳", 
                     style: Theme.of(context).textTheme.titleLarge),
                IconButton(onPressed: () => Get.back(), icon: const Icon(Icons.close))
              ],
            ),
            const Divider(),
            
            // 表單內容 (可滑動)
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. 名稱
                    TextField(
                      controller: controller.nameController,
                      decoration: const InputDecoration(labelText: "餐廳名稱 (必填)", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 15),

                    // 2. 類別 (智慧過濾 + 橫向滑動)
                    TextField(
                      controller: controller.categoryController,
                      decoration: const InputDecoration(
                        labelText: "類別", 
                        border: OutlineInputBorder(),
                        hintText: "輸入或選取...",
                        prefixIcon: Icon(Icons.category),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    // 橫向滑動標籤列
                    Obx(() {
                      final cats = controller.filteredCategories;
                      // 如果沒有選項且沒有輸入文字，就隱藏
                      if (cats.isEmpty && controller.searchText.value.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Container(
                        height: 50,
                        margin: const EdgeInsets.only(top: 8),
                        child: cats.isEmpty 
                          ? const Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Text("將建立新分類", style: TextStyle(color: Colors.grey, fontSize: 12)),
                            )
                          : ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: cats.length,
                              separatorBuilder: (context, index) => const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final cat = cats[index];
                                return ActionChip(
                                  label: Text(cat),
                                  elevation: 0,
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  side: BorderSide.none,
                                  onPressed: () => controller.setCategoryText(cat),
                                );
                              },
                            ),
                      );
                    }),

                    const SizedBox(height: 15),
                    
                    // 3. 聯絡資訊
                    TextField(
                      controller: controller.contactController,
                      decoration: const InputDecoration(labelText: "聯絡資訊 (選填: 電話/網址)", border: OutlineInputBorder()),
                    ),
                    
                    const SizedBox(height: 25),
                    const Text("📷 菜單照片", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),

                    // 4. 圖片選擇器
                    GestureDetector(
                      onTap: controller.pickImage,
                      child: Obx(() {
                        final path = controller.menuImagePath.value;
                        return Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.2), // 使用新版顏色API
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.4)),
                            image: path != null 
                                ? DecorationImage(image: FileImage(File(path)), fit: BoxFit.cover) 
                                : null,
                          ),
                          child: path == null
                              ? const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                                    SizedBox(height: 5),
                                    Text("點擊上傳菜單", style: TextStyle(color: Colors.grey)),
                                  ],
                                )
                              : Stack(
                                  children: [
                                    Positioned(
                                      right: 5,
                                      top: 5,
                                      child: CircleAvatar(
                                        backgroundColor: Colors.black54,
                                        radius: 16,
                                        child: IconButton(
                                          icon: const Icon(Icons.close, size: 16, color: Colors.white),
                                          onPressed: controller.removeImage,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        );
                      }),
                    ),
                    
                    const SizedBox(height: 25),
                    const Text("📍 適用地區 (多選)", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Obx(() => Wrap(
                      spacing: 8,
                      children: controller.db.locations.map((loc) {
                        final isSelected = controller.selectedLocationIds.contains(loc.id);
                        return FilterChip(
                          label: Text(loc.name),
                          selected: isSelected,
                          onSelected: (_) => controller.toggleLocation(loc.id),
                        );
                      }).toList(),
                    )),

                    const SizedBox(height: 25),
                    const Text("⏰ 適用時段 (多選)", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Obx(() => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: controller.db.timeSlots.map((slot) {
                        final isSelected = controller.selectedTimeSlotIds.contains(slot.id);
                        return FilterChip(
                          label: Text(slot.name),
                          selected: isSelected,
                          onSelected: (_) => controller.toggleTimeSlot(slot.id),
                        );
                      }).toList(),
                    )),
                    
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
            
            // 底部儲存按鈕
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: controller.saveItem,
                icon: const Icon(Icons.save),
                label: const Text("儲存"),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }
}