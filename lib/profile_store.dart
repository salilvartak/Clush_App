import 'dart:io';

class ProfileStore {
  // Singleton pattern ensures we access the same instance everywhere
  static final ProfileStore instance = ProfileStore._internal();
  
  factory ProfileStore() {
    return instance;
  }
  
  ProfileStore._internal();

  // Data fields to hold user input
  String? name;
  DateTime? birthday;
  String? gender;
  String? intent;
  List<String> interests = [];
  List<String> foods = [];
  List<String> places = [];
  List<File> photos = []; // Only stores non-null files
  
  // Helper to clear data after successful submission
  void clear() {
    name = null;
    birthday = null;
    gender = null;
    intent = null;
    interests = [];
    foods = [];
    places = [];
    photos = [];
  }
}