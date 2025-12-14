import 'models/location_model.dart';
import 'models/time_slot_model.dart';
import 'models/restaurant_model.dart';

/// 這裡集中管理所有的測試資料
/// 使用 Static Const ID 確保餐廳與地點/時段的關聯正確
class DataSeeder {
   
   // ==========================================
   // 1. 設定 ID 常數 (方便下方組裝資料時引用)
   // ==========================================
   
   // 地區 ID
   static const String idLocHome = "loc_home";
   static const String idLocWork = "loc_work";    // <-- 選擇這個作為單一地區
   static const String idLocRemote = "loc_remote";

   // 時段 ID
   static const String idTimeBreakfast = "time_breakfast";
   static const String idTimeLunch = "time_lunch"; // <-- 正常時段 (40 間, 4 類別)
   static const String idTimeTea = "time_tea";       // <-- 強制隨機 (10 間, 10 類別)
   static const String idTimeDinner = "time_dinner";
   static const String idTimeMidnight = "time_midnight";
   static const String idTimeAllDay = "time_allday";

   // ------------------------------------------
   // 輔助函式：生成重複的 RestaurantModel
   // ------------------------------------------
   static List<RestaurantModel> _generateRestaurants({
      required String timeSlotId,
      required List<String> categories,
      required int count,
      required String prefix,
      required int startIndex, // 用於生成獨特的 ID 和 ContactInfo
   }) {
      List<RestaurantModel> list = [];
      for (int i = 0; i < count; i++) {
         final globalIndex = startIndex + i;
         // 循環使用類別 (確保類別分佈均勻)
         String category = categories[i % categories.length];
         
         // 隨機生成電話或網址
         final String contact;
         if (globalIndex % 2 == 0) {
            // 偶數給電話 (格式: 02-1234567X)
            contact = "02-1234567${globalIndex % 10}";
         } else {
            // 奇數給網址 (格式: https://rest-00X.com)
            contact = "https://rest-${globalIndex.toString().padLeft(3, '0')}.com";
         }

         list.add(
            RestaurantModel(
               id: "${timeSlotId}_${globalIndex.toString().padLeft(3, '0')}",
               name: "$prefix $category No.${i + 1}",
               category: category,
               locationIds: [idLocWork], // 僅限單一地區
               timeSlotIds: [timeSlotId],
               contactInfo: contact, // 隨機的電話或網址
            ),
         );
      }
      return list;
   }


   // ==========================================
   // 2. 地區資料 (Locations)
   // ==========================================
   static List<LocationModel> get devLocations => [
      // 僅保留您指定的一個地區
      LocationModel(id: idLocWork, name: "公司附近"),
   ];

   static List<LocationModel> get prodLocations => [];

   // ==========================================
   // 3. 時段資料 (TimeSlots)
   // ==========================================
   static List<TimeSlotModel> get devTimeSlots => [
      // 正常時段 (午餐: 40 間, 4 類別)
      TimeSlotModel(id: idTimeLunch, name: "午餐時光", startTime: "11:00", endTime: "14:00"),
      
      // 特殊邏輯：強制隨機 (下午茶: 10 間, 10 類別)
      TimeSlotModel(id: idTimeTea, name: "下午茶/飲料", startTime: "14:00", endTime: "17:00", skipCategory: true),
   ];

   static List<TimeSlotModel> get prodTimeSlots => [];

   // ==========================================
   // 4. 餐廳資料 (Restaurants) - 整合生成邏輯
   // ==========================================
   static List<RestaurantModel> get devRestaurants {
      
      // --- A. 正常時段 (午餐): 40 間, 4 類別 ---
      const List<String> lunchCategories = [
         "飯食", "麵食", "異國料理", "輕食"
      ];
      final lunchRestaurants = _generateRestaurants(
         timeSlotId: idTimeLunch,
         categories: lunchCategories,
         count: 40,
         prefix: "[午餐]",
         startIndex: 1, // 從 index 1 開始
      );

      // --- B. 強制隨機時段 (下午茶): 10 間, 10 類別 ---
      const List<String> teaCategories = [
         "飲料店A", "咖啡廳", "甜點類", "冰品", "炸物類",
         "手搖飲B", "可麗餅", "蛋糕店", "果汁", "珍珠奶茶",
      ];
      final teaRestaurants = _generateRestaurants(
         timeSlotId: idTimeTea,
         categories: teaCategories,
         count: 10,
         prefix: "[下午茶]",
         startIndex: 41, // 接著午餐的 40 間，從 index 41 開始
      );
      
      // 組合所有資料 (共 50 間)
      return [...lunchRestaurants, ...teaRestaurants];
   }
   
   static List<RestaurantModel> get prodRestaurants => [];
}