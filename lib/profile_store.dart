// lib/profile_store.dart
import 'dart:io';

class ProfileStore {
  static final ProfileStore instance = ProfileStore._internal();
  
  factory ProfileStore() {
    return instance;
  }
  
  ProfileStore._internal();

  // Basic Info
  String? name;
  DateTime? birthday;
  String? gender;
  
  // New Fields
  String? sexualOrientation;
  String? pronouns;
  String? ethnicity;
  String? height;
  String? religion;
  String? education;
  String? jobTitle;
  String? languages;
  String? politicalViews;
  String? kids;
  String? starSign;
  String? pets;
  String? drink;
  String? smoke;
  String? weed;
  String? location;

  // Interaction Data
  String? intent;
  List<String> interests = [];
  List<String> foods = [];
  List<String> places = [];
  List<File> photos = []; 
  
  void clear() {
    name = null;
    birthday = null;
    gender = null;
    sexualOrientation = null;
    pronouns = null;
    ethnicity = null;
    height = null;
    religion = null;
    education = null;
    jobTitle = null;
    languages = null;
    politicalViews = null;
    kids = null;
    starSign = null;
    pets = null;
    drink = null;
    smoke = null;
    weed = null;
    location = null;
    intent = null;
    interests = [];
    foods = [];
    places = [];
    photos = [];
  }
}