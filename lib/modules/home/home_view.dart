import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'home_controller.dart';
import '../../data/services/database_service.dart';
import '../settings/settings_hub_view.dart';
import 'result_card.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(HomeController());

    return Scaffold(
      body: Stack(
        children: [
          // 1. 主內容 (包含結果卡片)
          _buildScrollableContent(context, controller),
          
          // 2. 懸浮操作列 (底部圓角選單)
          Positioned(
            left: 20,
            right: 20,
            bottom: 30,
            child: _buildFloatingControlRow(context, controller),
          ),
          
          // 3. 設定按鈕 (右上角)
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

          // 4. 自訂通知橫幅 (一輪結束提示)
          Obx(() => AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
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
                // --- 動畫狀態 ---
                return _buildCard(
                  context,
                  child: ClipRect( // 確保文字超出卡片邊界時被切掉
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("正在決定...", style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 25),
                        
                        // 動畫區域
                        Container(
                          height: 70, 
                          width: double.infinity,
                          alignment: Alignment.center,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 100),
                            
                            // 保持使用 Stack，讓新舊文字同時存在
                            layoutBuilder: (currentChild, previousChildren) {
                              return Stack(
                                alignment: Alignment.center,
                                children: <Widget>[
                                  ...previousChildren,
                                  if (currentChild != null) currentChild,
                                ],
                              );
                            },

                            // [修正重點] 區分進場與退場的軌跡
                            transitionBuilder: (Widget child, Animation<double> animation) {
                              // 1. 定義進場軌跡：從右邊 (1.0) 滑到中間 (0.0)
                              final inTween = Tween<Offset>(
                                begin: const Offset(1.0, 0.0), 
                                end: Offset.zero
                              );

                              // 2. 定義退場軌跡：從中間 (0.0) 滑到左邊 (-1.0)
                              // 注意：AnimatedSwitcher 對舊元件是跑「反向動畫」(Value: 1.0 -> 0.0)
                              // 當 Value=1.0 時 (退場開始)，我們希望它在 Offset.zero (中間)
                              // 當 Value=0.0 時 (退場結束)，我們希望它在 Offset(-1.0, 0.0) (左邊)
                              final outTween = Tween<Offset>(
                                begin: const Offset(-1.0, 0.0), 
                                end: Offset.zero
                              );

                              // 3. 判斷這個 child 是「新來的」還是「要走的」
                              // 透過 Key 來比對 (當前 Controller 的文字 = 新文字)
                              final isNewChild = child.key == ValueKey<String>(controller.rollingDisplay.value);

                              if (isNewChild) {
                                // 如果是新文字，跑進場動畫 (右 -> 中)
                                return SlideTransition(
                                  position: inTween.animate(animation),
                                  child: child,
                                );
                              } else {
                                // 如果是舊文字，跑退場動畫 (中 -> 左)
                                return SlideTransition(
                                  position: outTween.animate(animation),
                                  child: child,
                                );
                              }
                            },
                            
                            child: Container(
                              // [重要] 這裡的 Key 必須跟上面判斷邏輯一致
                              key: ValueKey<String>(controller.rollingDisplay.value),
                              width: double.infinity, 
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                controller.rollingDisplay.value,
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: Theme.of(context).brightness == Brightness.dark 
                                      ? Colors.white 
                                      : Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              } else if (controller.currentResult.value != null) {
                // 顯示結果
                return ResultCard(result: controller.currentResult.value!, controller: controller);
              } else {
                // 顯示開始畫面
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
        // 歷史紀錄列表
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

  // --- [修改重點] 統一介面邏輯 (備用，如果有 ResultCard 這個 Widget 就不會用到這邊) ---
  // 因為你已經拆分出 ResultCard，這裡其實只要留 ResultCard 的呼叫即可
  // 但為了防止你的 result_card.dart 參數有問題，我這裡稍微調整 ResultCard 的呼叫方式
  
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

  // --- 底部懸浮操作列 ---
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