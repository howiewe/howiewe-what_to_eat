import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'settings_view.dart';
import 'timeslot_view.dart';
import 'location_view.dart'; // 記得引入這個
import '../../data/services/data_transfer_service.dart'; 

class SettingsHubView extends StatelessWidget {
  const SettingsHubView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("設定"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined), // 或是 Icons.folder_open
            tooltip: "匯入備份",
            onPressed: () {
              // 呼叫服務執行匯入
              Get.find<DataTransferService>().importData();
            },
          ),
          const SizedBox(width: 8), //稍微留點邊距
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. 餐廳管理卡片
          _buildMenuCard(
            context,
            icon: Icons.restaurant,
            title: "餐廳資料管理",
            subtitle: "新增、編輯、刪除你的口袋名單",
            color: Colors.orange,
            onTap: () => Get.to(() => const SettingsView()),
          ),
          
          const SizedBox(height: 16),
          
          // 2. 時段管理卡片 (移到第二個)
          _buildMenuCard(
            context,
            icon: Icons.access_time,
            title: "時段設定",
            subtitle: "自訂早餐、午餐或飲料時段",
            color: Colors.blue,
            onTap: () => Get.to(() => const TimeSlotView()),
          ),

          const SizedBox(height: 16),

          // 3. 地區設定 (移到最後面)
          _buildMenuCard(
            context,
            icon: Icons.location_on,
            title: "地區設定",
            subtitle: "新增家、公司或其他活動範圍",
            color: Colors.green,
            onTap: () => Get.to(() => const LocationView()),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, {
    required IconData icon, 
    required String title, 
    required String subtitle, 
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  // 使用 withValues 修正警告
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}