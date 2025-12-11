import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'home_controller.dart';
import '../../data/services/database_service.dart';
import '../../data/models/restaurant_model.dart';
import '../settings/settings_hub_view.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(HomeController());

    return Scaffold(
      body: Stack(
        children: [
          // 1. 主內容
          _buildScrollableContent(context, controller),
          
          // 2. 懸浮操作列
          Positioned(
            left: 20,
            right: 20,
            bottom: 30,
            child: _buildFloatingControlRow(context, controller),
          ),
          
          // 3. 設定按鈕
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.settings),
              tooltip: "資料管理",
              onPressed: () {
                Get.to(() => const SettingsHubView());
              },
            ),
          ),

          // 4. 【新增】自訂通知橫幅 (取代 Snackbar)
          Obx(() => AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            // 如果 showResetBanner 為 true，位置在上方；否則藏在螢幕外
            top: controller.showResetBanner.value ? MediaQuery.of(context).padding.top + 10 : -100,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.refresh, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "一輪結束！名單已重置。",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildScrollableContent(BuildContext context, HomeController controller) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.of(context).size.height * 0.15),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Obx(() {
              if (controller.isRolling.value) {
                return _buildCard(
                  context,
                  child: const Center(child: CircularProgressIndicator()),
                );
              } else if (controller.currentResult.value != null) {
                return _buildResultCard(context, controller);
              } else {
                return _buildStartCard(context, controller);
              }
            }),
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(24, 40, 24, 10),
          sliver: SliverToBoxAdapter(
            child: Text(
              "最近吃過...",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
        ),
        Obx(() {
          final history = Get.find<DatabaseService>().history;
          if (history.isEmpty) {
            return const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  "還沒有紀錄，快去抽一餐吧！",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }
          return SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = history[index];
              return ListTile(
                leading: const Icon(Icons.history, size: 20),
                title: Text(item.restaurantName),
                subtitle: Text(item.timestamp.substring(0, 10)),
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              );
            }, childCount: history.length),
          );
        }),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  Widget _buildStartCard(BuildContext context, HomeController controller) {
    return _buildCard(
      context,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.restaurant_menu, size: 60, color: Colors.orange),
          const SizedBox(height: 20),
          Text("不知道吃什麼？", style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          Text(
            "根據下方設定，幫你決定！",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 30),
          FilledButton.icon(
            onPressed: controller.startRoll,
            icon: const Icon(Icons.play_arrow),
            label: const Text("開始決定"),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(BuildContext context, HomeController controller) {
    final result = controller.currentResult.value!;
    final hasMenu = result.menuImage != null && result.menuImage!.isNotEmpty;

    return _buildCard(
      context,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "今天吃這個！",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Text(
            result.name,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Chip(label: Text(result.category)),

          const SizedBox(height: 25),

          if (hasMenu)
            FilledButton.icon(
              onPressed: () => _showMenuDialog(context, result, controller),
              icon: const Icon(Icons.menu_book),
              label: const Text("查看菜單"),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
                backgroundColor: Colors.orange,
              ),
            )
          else
            _buildActionButtons(result, controller),

          const SizedBox(height: 20),

          if (hasMenu)
            TextButton.icon(
              onPressed: controller.startRoll,
              icon: const Icon(Icons.refresh),
              label: const Text("不想吃，重抽"),
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(RestaurantModel result, HomeController controller) {
    final hasContact = result.contactInfo != null && result.contactInfo!.isNotEmpty;
    final isUrl = hasContact ? controller.isUrl(result.contactInfo!) : false;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton.filledTonal(
          onPressed: controller.startRoll,
          icon: const Icon(Icons.refresh),
          tooltip: "重抽",
        ),

        // 決定按鈕
        IconButton.filled(
          onPressed: () {
            if (hasContact) {
              controller.launchContactInfo(result.contactInfo!); 
            } else {
              controller.confirmSelection(); 
            }
          },
          icon: Icon(hasContact ? (isUrl ? Icons.public : Icons.call) : Icons.check),
          style: IconButton.styleFrom(
            backgroundColor: hasContact ? (isUrl ? Colors.blue : Colors.green) : Colors.grey,
          ),
          tooltip: hasContact ? (isUrl ? "開啟網頁" : "撥打電話") : "決定吃這家",
        ),
      ],
    );
  }

  void _showMenuDialog(BuildContext context, RestaurantModel result, HomeController controller) {
    final hasContact = result.contactInfo != null && result.contactInfo!.isNotEmpty;
    final isUrl = hasContact ? controller.isUrl(result.contactInfo!) : false;

    Get.dialog(
      Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(result.name, style: const TextStyle(color: Colors.white)),
        ),
        body: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.file(File(result.menuImage!)),
              ),
            ),
            
            Positioned(
              left: 20,
              right: 20,
              bottom: 40,
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          // 先關閉 Dialog，再執行後續
                          Get.back();
                          
                          if (hasContact) {
                            controller.launchContactInfo(result.contactInfo!);
                          } else {
                            controller.confirmSelection();
                          }
                        },
                        icon: Icon(hasContact ? (isUrl ? Icons.public : Icons.call) : Icons.check),
                        label: Text(
                          !hasContact 
                              ? "決定吃這家 (無聯絡資訊)" 
                              : (isUrl ? "前往訂購網頁" : "撥打電話訂購")
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: !hasContact 
                              ? Colors.grey 
                              : (isUrl ? Colors.blue : Colors.green),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
      useSafeArea: false,
    );
  }

  Widget _buildCard(BuildContext context, {required Widget child}) {
    return Container(
      height: 350,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildFloatingControlRow(BuildContext context, HomeController controller) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Obx(
        () => Row(
          children: [
            Expanded(
              child: _buildControlItem(
                context,
                icon: Icons.location_on_outlined,
                label: controller.currentLocation.value?.name ?? "選擇地區",
                onTap: () => _showLocationPicker(context, controller),
              ),
            ),
            VerticalDivider(indent: 15, endIndent: 15, color: Theme.of(context).dividerColor),
            Expanded(
              child: _buildControlItem(
                context,
                icon: Icons.access_time,
                label: controller.currentTimeSlot.value?.name ?? "選擇時段",
                onTap: () => _showTimePicker(context, controller),
              ),
            ),
            VerticalDivider(indent: 15, endIndent: 15, color: Theme.of(context).dividerColor),
            Expanded(
              child: _buildControlItem(
                context,
                icon: controller.isRandomMode.value ? Icons.shuffle : Icons.category_outlined,
                label: controller.isRandomMode.value ? "隨機" : "引導",
                onTap: controller.toggleMode,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlItem(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showLocationPicker(BuildContext context, HomeController controller) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("選擇地區", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Obx(
              () => Column(
                children: controller.db.locations.map(
                      (loc) => ListTile(
                        title: Text(loc.name),
                        leading: loc.id == controller.currentLocation.value?.id
                            ? const Icon(Icons.check, color: Colors.green)
                            : null,
                        onTap: () {
                          controller.changeLocation(loc);
                          Get.back();
                        },
                      ),
                    ).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTimePicker(BuildContext context, HomeController controller) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("選擇時段", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Obx(
                () => Column(
                  children: controller.db.timeSlots.map(
                        (slot) => ListTile(
                          title: Text(slot.name),
                          subtitle: Text("${slot.startTime} - ${slot.endTime}"),
                          leading: slot.id == controller.currentTimeSlot.value?.id
                              ? const Icon(Icons.check, color: Colors.green)
                              : null,
                          onTap: () {
                            controller.changeTimeSlot(slot);
                            Get.back();
                          },
                        ),
                      ).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}