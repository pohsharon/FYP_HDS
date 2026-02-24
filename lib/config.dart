
class Config {
  static String get apiBaseUrl {
    // if (Platform.isAndroid) {
      // return "http://10.0.2.2:8000/api"; // Android emulator uses 10.0.2.2
    // } else if (Platform.isIOS) {
      // return "http://127.0.0.1:8080/api"; // iOS simulator uses localhost
    // } else {
      // return "http://192.168.1.20:8000/api"; // Default for other platforms (Mac, Windows)
    // }
    return "http://192.168.8.121:8080/api"; //Android real device
    // return "https://app-hosbaduriansystem-dev-001-g5dwg4gpeqbfgqgy.southeastasia-01.azurewebsites.net/api";
  }

  // No change in Supabase
  static const String supabaseBaseUrl =
      'https://ltnvfdqfrmwrhovleudk.supabase.co/storage/v1/object/public/hds_media/';
}
