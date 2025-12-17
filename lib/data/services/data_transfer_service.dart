import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart'; // 處理 ZIP
import 'package:file_picker/file_picker.dart'; // 選檔案
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart'; // 分享
import 'package:uuid/uuid.dart';

import '../models/location_model.dart';
import '../models/restaurant_model.dart';
import '../models/time_slot_model.dart';
import 'database_service.dart';

/// 負責資料的 匯出(打包) 與 匯入(解析)
/// 與 DatabaseService 解偶，只透過公開方法存取資料
class DataTransferService extends GetxService {
  final _db = Get.find<DatabaseService>();
  final _uuid = const Uuid();

  // 定義 ZIP 內部的 JSON 檔名
  static const String _dataFileName = "data.json";

  // =========================================================
  //  匯出邏輯 (Export) - 以「地區」為單位
  // =========================================================
  Future<void> exportLocation(LocationModel targetLocation) async {
    try {
      Get.loadingSnackbar(); // 顯示載入中 (GetX 內建或自定義)

      // 1. 準備暫存目錄
      final tempDir = await getTemporaryDirectory();
      final packDir = Directory('${tempDir.path}/export_pack');
      if (await packDir.exists()) await packDir.delete(recursive: true);
      await packDir.create();

      // 2. 篩選資料 (找出該地區的餐廳，與其依賴的時段)
      final relatedRestaurants = _db.restaurants
          .where((r) => r.locationIds.contains(targetLocation.id))
          .toList();

      if (relatedRestaurants.isEmpty) {
        Get.back(); // 關閉 loading
        Get.snackbar("提示", "該地區沒有餐廳資料可以匯出");
        return;
      }

      // 找出這些餐廳用到了哪些時段 ID
      final usedTimeSlotIds = relatedRestaurants
          .expand((r) => r.timeSlotIds)
          .toSet();

      // 把時段物件抓出來
      final relatedTimeSlots = _db.timeSlots
          .where((slot) => usedTimeSlotIds.contains(slot.id))
          .toList();

      // 3. 處理圖片並建立傳輸物件 (DTO)
      // 我們不直接存 UUID，而是建立一個 Map 結構
      List<Map<String, dynamic>> restaurantsJson = [];

      for (var r in relatedRestaurants) {
        String? exportImageName;

        // 如果有圖片，複製到暫存區
        if (r.menuImage != null && r.menuImage!.isNotEmpty) {
          final imgFile = File(r.menuImage!);
          if (await imgFile.exists()) {
            // 為了避免檔名衝突，重新命名: img_{index}.ext
            final ext = p.extension(r.menuImage!);
            final newName = "img_${_uuid.v4()}$ext";
            await imgFile.copy('${packDir.path}/$newName');
            exportImageName = newName; // JSON 裡只存檔名
          }
        }

        // 建立餐廳的傳輸資料
        restaurantsJson.add({
          "name": r.name,
          "category": r.category,
          "contactInfo": r.contactInfo,
          "menuImage": exportImageName, // 相對路徑 (檔名)
          // 這裡我們不傳 locationIds 列表，因為這包資料就是專屬 targetLocation 的
          // 我們也不傳 timeSlotIds 的 UUID，而是傳「時段名稱」或「原始ID」，
          // 這裡選擇傳「原始ID」，並在下方附上時段定義表供對照
          "linkedTimeSlotIds": r.timeSlotIds,
        });
      }

      // 4. 建立時段定義表
      // 接收端會用這個表來重建或比對時段
      List<Map<String, dynamic>> timeSlotsJson = relatedTimeSlots.map((slot) {
        return slot.toJson(); // 直接用原本的 JSON 結構，包含 id, name, startTime...
      }).toList();

      // 5. 組合最終的 data.json
      final finalData = {
        "version": 1,
        "sourceRegionName": targetLocation.name,
        "timestamp": DateTime.now().toIso8601String(),
        "timeSlots": timeSlotsJson,
        "restaurants": restaurantsJson,
      };

      // 寫入 data.json
      final jsonFile = File('${packDir.path}/$_dataFileName');
      await jsonFile.writeAsString(jsonEncode(finalData));

      // 6. 壓縮成 ZIP
      var encoder = ZipFileEncoder();
      final zipFilePath = '${tempDir.path}/${targetLocation.name}_備份.zip';
      encoder.create(zipFilePath);

      // 把 packDir 裡的所有檔案加入 zip
      // 注意：addDirectory 在某些版本行為不同，我們手動加檔案比較保險
      await for (var file in packDir.list()) {
        if (file is File) {
          final filename = p.basename(file.path);
          await encoder.addFile(file, filename);
        }
      }
      encoder.close();

      // 7. 呼叫系統分享
      // 這裡使用 Share.shareXFiles (新版寫法)
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(zipFilePath)],
          subject: '美食名單備份',
          text: '這是我的「${targetLocation.name}」餐廳名單，匯入 App 就可以用囉！',
        ),
      );
    } catch (e) {
      if (Get.isDialogOpen == true) Get.back();
      debugPrint("Export Error: $e"); // 改用 debugPrint
      Get.snackbar("匯出失敗", "發生錯誤: $e");
    }
  }

  // =========================================================
  //  匯入邏輯 (Import) - 智慧融合
  // =========================================================
  Future<void> importData() async {
    // 1. 先讓使用者選擇檔案 (這時候還沒開始轉圈圈)
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result == null || result.files.single.path == null) return;

    // 2. 開始轉圈圈
    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false, // 使用者點旁邊關不掉，強迫等待
    );

    // 定義變數在 try 外面，方便最後顯示訊息
    int addedCount = 0;
    String regionName = "";
    Directory? extractDir;

    try {
      final zipFile = File(result.files.single.path!);
      final bytes = await zipFile.readAsBytes();

      // 解壓縮
      final archive = ZipDecoder().decodeBytes(bytes);

      final tempDir = await getTemporaryDirectory();
      extractDir = Directory('${tempDir.path}/import_temp_${_uuid.v4()}');
      await extractDir.create();

      Map<String, dynamic>? dataJson;

      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          final outFile = File('${extractDir.path}/$filename');
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(data);

          if (filename == _dataFileName) {
            dataJson = jsonDecode(await outFile.readAsString());
          }
        }
      }

      if (dataJson == null) {
        throw "無效的備份檔 (找不到 data.json)";
      }

      // 讀取資料
      regionName = dataJson["sourceRegionName"];
      final List timeSlotsRaw = dataJson["timeSlots"];
      final List restaurantsRaw = dataJson["restaurants"];

      // [Step A] 處理地區
      String targetLocationId;
      var existingLoc = _db.locations.firstWhereOrNull(
        (l) => l.name == regionName,
      );

      if (existingLoc != null) {
        targetLocationId = existingLoc.id;
      } else {
        targetLocationId = _uuid.v4();
        _db.addLocationWithId(targetLocationId, regionName);
      }

      // [Step B] 處理時段
      Map<String, String> timeSlotMap = {};
      final appDocDir = await getApplicationDocumentsDirectory();

      for (var slotData in timeSlotsRaw) {
        final String oldId = slotData['id'];
        final String name = slotData['name'];
        var existingSlot = _db.timeSlots.firstWhereOrNull(
          (s) => s.name == name,
        );

        if (existingSlot != null) {
          timeSlotMap[oldId] = existingSlot.id;
        } else {
          final newSlot = TimeSlotModel.fromJson(slotData);
          newSlot.id = _uuid.v4();
          _db.addTimeSlot(newSlot);
          timeSlotMap[oldId] = newSlot.id;
        }
      }

      // [Step C] 處理餐廳
      for (var rData in restaurantsRaw) {
        final String name = rData['name'];
        bool alreadyExists = _db.restaurants.any(
          (dbR) =>
              dbR.name == name && dbR.locationIds.contains(targetLocationId),
        );

        if (alreadyExists) continue;

        String? localImagePath;
        final String? zipImageName = rData['menuImage'];
        if (zipImageName != null && zipImageName.isNotEmpty) {
          final tempImg = File('${extractDir.path}/$zipImageName');
          if (await tempImg.exists()) {
            final newFileName = '${_uuid.v4()}${p.extension(zipImageName)}';
            final savedPath = '${appDocDir.path}/$newFileName';
            await tempImg.copy(savedPath);
            localImagePath = savedPath;
          }
        }

        List<String> rawLinkedSlots = List<String>.from(
          rData['linkedTimeSlotIds'],
        );
        List<String> newTimeSlotIds = [];
        for (var rawId in rawLinkedSlots) {
          if (timeSlotMap.containsKey(rawId)) {
            newTimeSlotIds.add(timeSlotMap[rawId]!);
          }
        }

        final newRest = RestaurantModel(
          id: _uuid.v4(),
          name: name,
          category: rData['category'],
          contactInfo: rData['contactInfo'],
          menuImage: localImagePath,
          locationIds: [targetLocationId],
          timeSlotIds: newTimeSlotIds,
        );

        _db.addRestaurant(newRest);
        addedCount++;
      }
    } catch (e) {
      debugPrint("Import Error: $e");
      // 這裡不關 Dialog，留給 finally 關，避免重複操作
      Get.snackbar(
        "匯入失敗",
        "檔案格式錯誤或損毀 ($e)",
        backgroundColor: Colors.red.withValues(alpha: 0.5),
        colorText: Colors.white,
      );
      return; // 發生錯誤就直接結束
    } finally {
      // 【關鍵修正】不管成功失敗，最後這裡一定會執行

      // 1. 清理暫存檔案 (如果有)
      if (extractDir != null && await extractDir.exists()) {
        await extractDir.delete(recursive: true);
      }

      // 2. 稍微等一下，確保 UI 執行緒有空閒
      await Future.delayed(const Duration(milliseconds: 200));

      // 3. 檢查是否有 Dialog 開著，有的話才關閉
      if (Get.isDialogOpen == true) {
        Get.back();
      }
    }

    // 成功訊息放在 finally 之後顯示，確保 Dialog 已經關了
    if (addedCount > 0) {
      // 再等一下，避免 Dialog 關閉動畫跟 Snackbar 打架
      await Future.delayed(const Duration(milliseconds: 100));
      Get.snackbar("匯入成功", "成功新增 $addedCount 間餐廳至「$regionName」");
    } else {
      await Future.delayed(const Duration(milliseconds: 100));
      Get.snackbar("匯入完成", "資料已存在，沒有新增任何餐廳");
    }
  }
}

// 擴充 Get 方便呼叫 loading
extension GetLoading on GetInterface {
  void loadingSnackbar() {
    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );
  }
}
