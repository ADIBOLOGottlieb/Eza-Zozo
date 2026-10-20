import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models_restaurants.dart';

/// Restaurant visé par les appels à l'API (en-tête `X-Restaurant-Id`).
///
/// - propriétaire : un restaurant, ou « tous » ([all]) pour suivre tous ses restaurants à la fois ;
/// - client : le restaurant où il commande ;
/// - gérant et livreur : rien à choisir, le serveur utilise toujours leur restaurant ([current] reste null).
class RestaurantScope {
  RestaurantScope._();
  static final RestaurantScope instance = RestaurantScope._();

  /// Valeur de l'en-tête pour « tous les restaurants » (propriétaire, lecture seule).
  static const all = 'all';

  /// En-tête envoyé : null (restaurant par défaut du serveur), [all] ou l'identifiant du restaurant.
  final ValueNotifier<String?> current = ValueNotifier<String?>(null);

  /// Restaurants connus : tous pour le propriétaire, ceux qui prennent des commandes pour un client.
  final ValueNotifier<List<Restaurant>> restaurants = ValueNotifier<List<Restaurant>>(const []);

  /// Appelé après chaque changement de restaurant (l'API vide ses caches).
  VoidCallback? onChanged;

  String? _prefsKey;

  bool get isAll => current.value == all;
  int? get restaurantId => int.tryParse(current.value ?? '');
  bool get hasSeveral => restaurants.value.length > 1;

  Restaurant? get selected {
    final id = restaurantId;
    if (id == null) return null;
    for (final r in restaurants.value) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Nom affiché du choix en cours.
  String get label => isAll ? 'Tous les restaurants' : selected?.name ?? 'Restaurant';

  /// Reprend le dernier choix enregistré sous [prefsKey] (sinon [fallback]).
  Future<void> restore(String prefsKey, {String? fallback}) async {
    _prefsKey = prefsKey;
    String? saved;
    try {
      saved = (await SharedPreferences.getInstance()).getString(prefsKey);
    } catch (_) {
      saved = null;
    }
    _set(saved ?? fallback);
  }

  /// Nouveaux restaurants ; un choix qui n'existe plus est remplacé par [fallback] (ou le premier).
  void setRestaurants(List<Restaurant> list, {String? fallback}) {
    restaurants.value = List.unmodifiable(list);
    final id = restaurantId;
    if (id != null && !list.any((r) => r.id == id)) {
      select(fallback ?? (list.isEmpty ? null : '${list.first.id}'));
    } else if (current.value == null && fallback != null) {
      select(fallback);
    }
  }

  /// Choisit un restaurant ([all], un identifiant en texte, ou null) et l'enregistre.
  Future<void> select(String? value) async {
    if (value == current.value) return;
    _set(value);
    final key = _prefsKey;
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value == null) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, value);
      }
    } catch (_) {
      // Choix gardé jusqu'à la fermeture de l'app.
    }
  }

  void selectRestaurant(int id) => select('$id');

  void _set(String? value) {
    if (value == current.value) return;
    current.value = value;
    onChanged?.call();
  }

  /// Déconnexion, ou compte sans choix de restaurant (gérant, livreur).
  void reset() {
    _prefsKey = null;
    restaurants.value = const [];
    _set(null);
  }
}
