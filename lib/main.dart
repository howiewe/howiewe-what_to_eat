import 'package:flutter/material.dart'; // 讓你看得懂 Scaffold, Text, Icon...
import 'package:get/get.dart'; // 讓你看得懂 Get, GetMaterialApp
import 'modules/home/home_view.dart';
import 'data/services/database_service.dart'; // 讓你看得懂 DatabaseService

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 DatabaseService
  // 這裡會報錯的話，請檢查你的檔案路徑是否正確：lib/data/services/database_service.dart
  await Get.putAsync(() => DatabaseService().init());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: '決定吃什麼',
      debugShowCheckedModeBanner: false, // 去除右上角 debug 標籤
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: ThemeMode.system, // 自動跟隨系統
      home: const HomeView(),
    );
  }
}
