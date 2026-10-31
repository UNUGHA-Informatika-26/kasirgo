class UserData {
  // Data Profil Toko/Usaha yang terhubung ke Beranda, Struk, dan PDF
  static String storeName = '';
  static String storeAddress = '';
  static String storePhone = '';
  static String storeEmail = '';

  static void updateProfile({
    required String name,
    required String address,
    required String phone,
    required String email,
  }) {
    storeName = name;
    storeAddress = address;
    storePhone = phone;
    storeEmail = email;
  }
}
