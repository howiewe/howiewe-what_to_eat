import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'settings_view.dart';
import 'timeslot_view.dart';

class SettingsHubView extends StatelessWidget {
  const SettingsHubView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("設定"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 餐廳管理卡片
          _buildMenuCard(
            context,
            icon: Icons.restaurant,
            title: "餐廳資料管理",
            subtitle: "新增、編輯、刪除你的口袋名單",
            color: Colors.orange,
            onTap: () => Get.to(() => const SettingsView()),
          ),
          
          const SizedBox(height: 16),
          
          // 時段管理卡片
          _buildMenuCard(
            context,
            icon: Icons.access_time,
            title: "時段設定",
            subtitle: "自訂早餐、午餐或飲料時段",
            color: Colors.blue,
            onTap: () => Get.to(() => const TimeSlotView()),
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
                  color: color.withOpacity(0.1),
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