import 'package:flutter/material.dart';
import '../../data/models/restaurant_model.dart';
import 'home_controller.dart';

class ResultCard extends StatelessWidget {
  final RestaurantModel result;
  final HomeController controller;

  const ResultCard({
    super.key,
    required this.result,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    // 判斷狀態
    final hasMenu = result.menuImage != null && result.menuImage!.isNotEmpty;
    final hasContact = result.contactInfo != null && result.contactInfo!.isNotEmpty;
    final isUrl = hasContact ? controller.isUrl(result.contactInfo!) : false;

    // 決定按鈕顯示的文字與圖示
    String primaryLabel;
    IconData primaryIcon;
    Color primaryColor;
    VoidCallback primaryAction;

    if (hasMenu) {
      primaryLabel = "查看菜單";
      primaryIcon = Icons.menu_book;
      primaryColor = Colors.orange;
      // 注意：這裡需要把 _showMenuDialog 也搬過來，或者透過 controller 呼叫
      // 為了簡單起見，我們先假設還是在 View 層處理，這裡先用簡單的作法
      primaryAction = () => controller.showMenuDialog(context, result); 
    } else if (hasContact) {
      primaryLabel = "前往訂購";
      primaryIcon = isUrl ? Icons.public : Icons.call;
      primaryColor = isUrl ? Colors.blue : Colors.green;
      primaryAction = () => controller.launchContactInfo(result.contactInfo!);
    } else {
      primaryLabel = "決定這家";
      primaryIcon = Icons.check_circle;
      primaryColor = Colors.green;
      primaryAction = controller.confirmSelection;
    }

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

          FilledButton.icon(
            onPressed: primaryAction,
            icon: Icon(primaryIcon),
            label: Text(primaryLabel),
            style: FilledButton.styleFrom(
              backgroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle: const TextStyle(fontSize: 18),
            ),
          ),

          const SizedBox(height: 20),

          TextButton.icon(
            onPressed: controller.startRoll,
            icon: const Icon(Icons.refresh),
            label: const Text("不想吃，重抽"),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}