// Appels API des restaurants : liste publique (clients), gestion et vue d'ensemble (propriétaire).
import '../models_restaurants.dart';
import 'api.dart';

Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<Restaurant> _restaurants(dynamic v) =>
    v is List ? v.map((e) => Restaurant.fromJson(_map(e))).toList() : <Restaurant>[];

/// Restaurants qui prennent des commandes (public).
Future<List<Restaurant>> fetchRestaurants() async => _restaurants(await Api.instance.get('/restaurants'));

/// Tous les restaurants, actifs ou non (propriétaire).
Future<List<Restaurant>> fetchOwnerRestaurants() async => _restaurants(await Api.instance.get('/owner/restaurants'));

/// Chiffres du jour de chaque restaurant et totaux (propriétaire).
Future<OwnerOverview> fetchOwnerOverview() async => OwnerOverview.fromJson(_map(await Api.instance.get('/owner/overview')));

/// Nouveau restaurant ; [copyMenuFrom] : recopie le menu et les règles (prix de livraison, frais...) d'un autre.
Future<Restaurant> createRestaurant({
  required String name,
  String? address,
  String? phone,
  int? copyMenuFrom,
}) async =>
    Restaurant.fromJson(_map(await Api.instance.post('/owner/restaurants', {
      'name': name,
      if (address != null && address.trim().isNotEmpty) 'address': address.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      'copy_menu_from': ?copyMenuFrom,
    })));

/// Renomme, réordonne, ferme ou rouvre un restaurant (champs null non envoyés).
Future<Restaurant> updateRestaurant(int id, {String? name, bool? active, int? position}) async =>
    Restaurant.fromJson(_map(await Api.instance.patch('/owner/restaurants/$id', {
      'name': ?name,
      'active': ?active,
      'position': ?position,
    })));
