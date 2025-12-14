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
  static const String idLocWork = "loc_work";
  static const String idLocRemote = "loc_remote";

  // 時段 ID
  static const String idTimeBreakfast = "time_breakfast";
  static const String idTimeLunch = "time_lunch";
  static const String idTimeTea = "time_tea";     // 強制隨機 (如下午茶)
  static const String idTimeDinner = "time_dinner";
  static const String idTimeMidnight = "time_midnight"; // 跨日 (宵夜)
  static const String idTimeAllDay = "time_allday";     // 不限時

  // ==========================================
  // 2. 地區資料 (Locations)
  // ==========================================
  static List<LocationModel> get devLocations => [
    LocationModel(id: idLocHome, name: "溫暖的家"),
    LocationModel(id: idLocWork, name: "公司附近"),
    LocationModel(id: idLocRemote, name: "出差/遠端"),
  ];

  static List<LocationModel> get prodLocations => [
    LocationModel(id: "prod_home", name: "家裡附近"),
    LocationModel(id: "prod_work", name: "公司/學校"),
  ];

  // ==========================================
  // 3. 時段資料 (TimeSlots)
  // ==========================================
  static List<TimeSlotModel> get devTimeSlots => [
    // 正常時段
    TimeSlotModel(id: idTimeBreakfast, name: "活力早餐", startTime: "06:00", endTime: "10:30"),
    TimeSlotModel(id: idTimeLunch, name: "午餐時光", startTime: "11:00", endTime: "14:00"),
    
    // 特殊邏輯：強制隨機 (skipCategory = true)
    TimeSlotModel(id: idTimeTea, name: "下午茶/飲料", startTime: "14:00", endTime: "17:00", skipCategory: true),
    
    TimeSlotModel(id: idTimeDinner, name: "晚餐", startTime: "17:00", endTime: "21:00"),
    
    // 特殊邏輯：跨日 (開始時間 > 結束時間)
    TimeSlotModel(id: idTimeMidnight, name: "罪惡宵夜", startTime: "22:00", endTime: "04:00"),
    
    // 特殊邏輯：不限時 (沒有 startTime/endTime)
    TimeSlotModel(id: idTimeAllDay, name: "全天候供應"),
  ];

  static List<TimeSlotModel> get prodTimeSlots => [
    TimeSlotModel(id: "prod_lunch", name: "午餐", startTime: "11:00", endTime: "14:00"),
    TimeSlotModel(id: "prod_dinner", name: "晚餐", startTime: "17:00", endTime: "20:00"),
  ];

  // ==========================================
  // 4. 餐廳資料 (Restaurants) - 各種情境測試
  // ==========================================
  static List<RestaurantModel> get devRestaurants => [
    // --- 情境 A: 完整資料 (有圖、有電話、有網址、多地區、多時段) ---
    RestaurantModel(
      id: "rest_001",
      name: "豪華海陸大餐 (測試完整UI)",
      category: "排餐",
      locationIds: [idLocHome, idLocWork, idLocRemote], // 到處都有
      timeSlotIds: [idTimeLunch, idTimeDinner],
      contactInfo: "https://www.google.com", // 網址
      // 這裡你可以放一張手機裡的圖片路徑測試，或是留空
      menuImage: null, 
    ),

    // --- 情境 B: 極簡資料 (只有名字) ---
    RestaurantModel(
      id: "rest_002",
      name: "巷口無名麵店",
      category: "麵食", // 甚至 category 也可以空字串測試
      locationIds: [idLocHome],
      timeSlotIds: [idTimeDinner, idTimeMidnight], // 晚餐跟宵夜開
    ),

    // --- 情境 C: 飲料/甜點 (配合強制隨機時段) ---
    RestaurantModel(
      id: "rest_003",
      name: "50嵐",
      category: "飲料",
      locationIds: [idLocWork],
      timeSlotIds: [idTimeTea, idTimeAllDay],
      contactInfo: "0912345678", // 電話
    ),
    RestaurantModel(
      id: "rest_004",
      name: "星巴克",
      category: "咖啡",
      locationIds: [idLocWork, idLocRemote],
      timeSlotIds: [idTimeBreakfast, idTimeTea],
    ),

    // --- 情境 D: 跨日宵夜場 ---
    RestaurantModel(
      id: "rest_005",
      name: "林東芳牛肉麵",
      category: "麵食",
      locationIds: [idLocRemote],
      timeSlotIds: [idTimeMidnight], 
      contactInfo: "0227522556",
    ),

    // --- 情境 E: 測試超長文字 (UI 壓力測試) ---
    RestaurantModel(
      id: "rest_006",
      name: "這是一間名字超級無敵長長長長長到可能會換行的義大利麵餐廳",
      category: "異國料理",
      locationIds: [idLocHome],
      timeSlotIds: [idTimeLunch],
      contactInfo: "無聯絡資訊",
    ),

    // --- 情境 F: 沒分類 (Category 為空) ---
    RestaurantModel(
      id: "rest_007",
      name: "神秘路邊攤",
      category: "", // 測試分類顯示
      locationIds: [idLocHome],
      timeSlotIds: [idTimeAllDay],
    ),
  ];
  
  static List<RestaurantModel> get prodRestaurants => [];
}