import 'dart:io'; // 用於顯示手機儲存的圖片
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'home_controller.dart';
import '../../data/services/database_service.dart';
import '../../data/models/restaurant_model.dart';
import '../settings/settings_view.dart'; // 引入設定頁面

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    // 綁定 Controller
    final controller = Get.put(HomeController());

    return Scaffold(
      // 隱藏 AppBar，用 Stack + SafeArea 自己排版
      body: Stack(
        children: [
          // 1. 底層：可滑動內容 (歷史紀錄在下方)
          _buildScrollableContent(context, controller),

          // 2. 頂層：懸浮操作列 (Floating Row)
          Positioned(
            left: 20,
            right: 20,
            bottom: 30,
            child: _buildFloatingControlRow(context, controller),
          ),

          // 3. 頂部工具列 (設定按鈕)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.settings),
              tooltip: "資料管理",
              onPressed: () {
                // 跳轉到設定頁面
                Get.to(() => const SettingsView());
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollableContent(
    BuildContext context,
    HomeController controller,
  ) {
    return CustomScrollView(
      slivers: [
        // 上方留白，把卡片往下推到螢幕中間偏上
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.of(context).size.height * 0.15),
        ),

        // --- 核心卡片區域 ---
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Obx(() {
              // 根據狀態顯示不同內容
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

        // --- 歷史紀錄標題 ---
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

        // --- 歷史紀錄列表 ---
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
                subtitle: Text(item.timestamp.substring(0, 10)), // 簡單顯示日期
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              );
            }, childCount: history.length),
          );
        }),

        // 底部留白，避免內容被懸浮按鈕擋住
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  // --- 元件：初始卡片 ---
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
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
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

  // --- 元件：結果卡片 (含菜單邏輯) ---
  Widget _buildResultCard(BuildContext context, HomeController controller) {
    final result = controller.currentResult.value!;
    // 檢查是否有菜單圖片
    final hasMenu = result.menuImage != null && result.menuImage!.isNotEmpty;

    return _buildCard(
      context,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "今天吃這個！",
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Text(
            result.name,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Chip(label: Text(result.category)),

          const SizedBox(height: 25),

          // --- UX 核心邏輯 ---
          if (hasMenu)
            FilledButton.icon(
              onPressed: () => _showMenuDialog(context, result),
              icon: const Icon(Icons.menu_book),
              label: const Text("查看菜單"),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                textStyle: const TextStyle(fontSize: 18),
                backgroundColor: Colors.orange,
              ),
            )
          else
            // 如果沒菜單，直接顯示操作按鈕
            _buildActionButtons(result, controller),

          const SizedBox(height: 20),

          // 如果有菜單，顯示一個較小的「重抽」文字按鈕在下方
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

  // --- 沒菜單時的標準按鈕列 ---
  Widget _buildActionButtons(
    RestaurantModel result,
    HomeController controller,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton.filledTonal(
          onPressed: controller.startRoll,
          icon: const Icon(Icons.refresh),
          tooltip: "重抽",
        ),
        if (result.contactInfo != null)
          IconButton.filled(
            onPressed: () => Get.snackbar("聯絡", "開啟: ${result.contactInfo}"),
            icon: const Icon(Icons.call),
            tooltip: "訂餐",
          ),
      ],
    );
  }

  // --- 菜單全螢幕展示 Dialog ---
  void _showMenuDialog(BuildContext context, RestaurantModel result) {
    Get.dialog(
      Scaffold(
        backgroundColor: Colors.black, // 深色背景專注看圖
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(result.name, style: const TextStyle(color: Colors.white)),
        ),
        body: Stack(
          children: [
            // 1. 可縮放的圖片
            Center(
              child: InteractiveViewer(
                child: Image.file(
                  File(result.menuImage!),
                  errorBuilder: (ctx, err, stack) => const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, color: Colors.white, size: 50),
                      Text("圖片讀取失敗", style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),

            // 2. 下方懸浮訂購鈕 (看完菜單 -> 訂購)
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
                          Get.back(); // 關閉菜單
                          if (result.contactInfo != null) {
                            // 這裡可以換成 url_launcher 打電話
                            Get.snackbar("訂購", "正在撥打: ${result.contactInfo}");
                          } else {
                            Get.snackbar("提示", "這家店沒有紀錄電話喔");
                          }
                        },
                        icon: const Icon(Icons.phone),
                        label: const Text("決定訂購"),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      useSafeArea: false, // 全螢幕覆蓋
    );
  }

  // --- 共用卡片樣式 ---
  Widget _buildCard(BuildContext context, {required Widget child}) {
    return Container(
      height: 350, // 稍微加高一點以容納按鈕
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(32),
        // 使用 withValues 修正 withOpacity 警告
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

  // --- 核心需求：底部懸浮控制列 ---
  Widget _buildFloatingControlRow(
    BuildContext context,
    HomeController controller,
  ) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        // 使用 withValues 修正警告
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
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
            // 1. 地區選擇
            Expanded(
              child: _buildControlItem(
                context,
                icon: Icons.location_on_outlined,
                label: controller.currentLocation.value?.name ?? "選擇地區",
                onTap: () => _showLocationPicker(context, controller),
              ),
            ),
            // 分隔線
            VerticalDivider(
              indent: 15,
              endIndent: 15,
              color: Theme.of(context).dividerColor,
            ),

            // 2. 時段選擇
            Expanded(
              child: _buildControlItem(
                context,
                icon: Icons.access_time,
                label: controller.currentTimeSlot.value?.name ?? "選擇時段",
                onTap: () => _showTimePicker(context, controller),
              ),
            ),
            // 分隔線
            VerticalDivider(
              indent: 15,
              endIndent: 15,
              color: Theme.of(context).dividerColor,
            ),

            // 3. 模式選擇
            Expanded(
              child: _buildControlItem(
                context,
                icon: controller.isRandomMode.value
                    ? Icons.shuffle
                    : Icons.category_outlined,
                label: controller.isRandomMode.value ? "隨機" : "引導",
                onTap: controller.toggleMode,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
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

  // --- BottomSheet: 地區選擇器 ---
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
            const Text(
              "選擇地區",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            // 使用 Obx 確保列表更新 (如果 settings 改了地區)
            Obx(
              () => Column(
                children: controller.db.locations
                    .map(
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
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- BottomSheet: 時段選擇器 ---
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
              const Text(
                "選擇時段",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Obx(
                () => Column(
                  children: controller.db.timeSlots
                      .map(
                        (slot) => ListTile(
                          title: Text(slot.name),
                          subtitle: Text("${slot.startTime} - ${slot.endTime}"),
                          leading:
                              slot.id == controller.currentTimeSlot.value?.id
                              ? const Icon(Icons.check, color: Colors.green)
                              : null,
                          onTap: () {
                            controller.changeTimeSlot(slot);
                            Get.back();
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
