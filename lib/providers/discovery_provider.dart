import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Model ───────────────────────────────────────────────────────────────────

final class DiscoverFilters {
  const DiscoverFilters({
    this.age = const RangeValues(18, 60),
    this.distance = 50,
    this.intent = '',
    this.height = const RangeValues(100, 250),
    this.religion,
    this.ethnicity,
    this.politics,
    this.starSign,
    this.education,
    this.kids,
    this.pets,
    this.exercise,
    this.drinks,
    this.smoke,
    this.weed,
  });

  final RangeValues age;
  final double distance;
  final String intent;
  final RangeValues height;
  final String? religion;
  final String? ethnicity;
  final String? politics;
  final String? starSign;
  final String? education;
  final String? kids;
  final String? pets;
  final String? exercise;
  final String? drinks;
  final String? smoke;
  final String? weed;

  DiscoverFilters copyWith({
    RangeValues? age,
    double? distance,
    String? intent,
    RangeValues? height,
    String? religion,
    String? ethnicity,
    String? politics,
    String? starSign,
    String? education,
    String? kids,
    String? pets,
    String? exercise,
    String? drinks,
    String? smoke,
    String? weed,
  }) =>
      DiscoverFilters(
        age: age ?? this.age,
        distance: distance ?? this.distance,
        intent: intent ?? this.intent,
        height: height ?? this.height,
        religion: religion ?? this.religion,
        ethnicity: ethnicity ?? this.ethnicity,
        politics: politics ?? this.politics,
        starSign: starSign ?? this.starSign,
        education: education ?? this.education,
        kids: kids ?? this.kids,
        pets: pets ?? this.pets,
        exercise: exercise ?? this.exercise,
        drinks: drinks ?? this.drinks,
        smoke: smoke ?? this.smoke,
        weed: weed ?? this.weed,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class DiscoverFiltersNotifier extends AsyncNotifier<DiscoverFilters> {
  @override
  Future<DiscoverFilters> build() async {
    final prefs = await SharedPreferences.getInstance();
    return _fromPrefs(prefs);
  }

  DiscoverFilters _fromPrefs(SharedPreferences prefs) {
    final ageStart = prefs.getDouble('filter_age_start');
    final ageEnd = prefs.getDouble('filter_age_end');
    final htStart = prefs.getDouble('filter_height_start');
    final htEnd = prefs.getDouble('filter_height_end');
    return DiscoverFilters(
      age: (ageStart != null && ageEnd != null)
          ? RangeValues(ageStart, ageEnd)
          : const RangeValues(18, 60),
      distance: prefs.getDouble('filter_distance') ?? 50,
      intent: prefs.getString('filter_intent') ?? '',
      height: (htStart != null && htEnd != null)
          ? RangeValues(htStart, htEnd)
          : const RangeValues(100, 250),
      religion: prefs.getString('filter_religion'),
      ethnicity: prefs.getString('filter_ethnicity'),
      politics: prefs.getString('filter_politics'),
      starSign: prefs.getString('filter_star_sign'),
      education: prefs.getString('filter_education'),
      kids: prefs.getString('filter_kids'),
      pets: prefs.getString('filter_pets'),
      exercise: prefs.getString('filter_exercise'),
      drinks: prefs.getString('filter_drinks'),
      smoke: prefs.getString('filter_smoke'),
      weed: prefs.getString('filter_weed'),
    );
  }

  /// Apply new filters, persist to SharedPreferences, and update state.
  Future<void> applyFilters(DiscoverFilters filters) async {
    state = AsyncData(filters);
    final prefs = await SharedPreferences.getInstance();
    await _persist(prefs, filters);
  }

  Future<void> _persist(SharedPreferences prefs, DiscoverFilters f) async {
    await prefs.setDouble('filter_age_start', f.age.start);
    await prefs.setDouble('filter_age_end', f.age.end);
    await prefs.setDouble('filter_distance', f.distance);
    await prefs.setString('filter_intent', f.intent);
    await prefs.setDouble('filter_height_start', f.height.start);
    await prefs.setDouble('filter_height_end', f.height.end);
    if (f.religion != null) {
      await prefs.setString('filter_religion', f.religion!);
    }
    if (f.ethnicity != null) {
      await prefs.setString('filter_ethnicity', f.ethnicity!);
    }
    if (f.politics != null) {
      await prefs.setString('filter_politics', f.politics!);
    }
    if (f.starSign != null) {
      await prefs.setString('filter_star_sign', f.starSign!);
    }
    if (f.education != null) {
      await prefs.setString('filter_education', f.education!);
    }
    if (f.kids != null) await prefs.setString('filter_kids', f.kids!);
    if (f.pets != null) await prefs.setString('filter_pets', f.pets!);
    if (f.exercise != null) {
      await prefs.setString('filter_exercise', f.exercise!);
    }
    if (f.drinks != null) await prefs.setString('filter_drinks', f.drinks!);
    if (f.smoke != null) await prefs.setString('filter_smoke', f.smoke!);
    if (f.weed != null) await prefs.setString('filter_weed', f.weed!);
  }
}

final discoverFiltersProvider =
    AsyncNotifierProvider<DiscoverFiltersNotifier, DiscoverFilters>(
  DiscoverFiltersNotifier.new,
);
