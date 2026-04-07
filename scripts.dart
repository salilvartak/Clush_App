import 'dart:io';
import 'dart:convert';
void main() {
  // Read Android Keystore
  var file = File(r'c:\Users\Salil\Desktop\Flutter\Clush_App\android\app\upload-keystore.jks');
  if (file.existsSync()) {
    File(r'c:\Users\Salil\Desktop\Flutter\Clush_App\clean_keystore_base64.txt').writeAsStringSync(base64Encode(file.readAsBytesSync()));
    print('Generated keystore from app dir');
  }
  var file2 = File(r'c:\Users\Salil\upload-keystore.jks');
  if (file2.existsSync()) {
    File(r'c:\Users\Salil\Desktop\Flutter\Clush_App\clean_keystore_base64_home.txt').writeAsStringSync(base64Encode(file2.readAsBytesSync()));
    print('Generated keystore from home dir');
  }
}
