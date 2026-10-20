// Plusieurs restaurants d'un même propriétaire : restaurant, vue d'ensemble (GET /api/owner/overview).

int _int(dynamic v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
double? _double(dynamic v) => v is num ? v.toDouble() : null;
DateTime? _date(dynamic v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

/// Un restaurant (GET /api/restaurants pour les clients, /api/owner/restaurants pour le propriétaire).
class Restaurant {
  final int id;
  final String name;
  final bool active;
  final int position;
  final String address;
  final String phone;
  final double? lat;
  final double? lng;
  /// Ouvert maintenant (interrupteur et horaires).
  final bool isOpen;
  final DateTime? nextOpeningAt;
  /// Propriétaire seulement : gérants et livreurs actifs.
  final int managers;
  final int drivers;

  const Restaurant({
    required this.id,
    required this.name,
    this.active = true,
    this.position = 0,
    this.address = '',
    this.phone = '',
    this.lat,
    this.lng,
    this.isOpen = true,
    this.nextOpeningAt,
    this.managers = 0,
    this.drivers = 0,
  });

  factory Restaurant.fromJson(Map<String, dynamic> j) => Restaurant(
        id: _int(j['id']),
        name: (j['name'] ?? '').toString(),
        active: j['active'] != false && j['active'] != 0,
        position: _int(j['position']),
        address: (j['address'] ?? '').toString(),
        phone: (j['phone'] ?? '').toString(),
        lat: _double(j['lat']),
        lng: _double(j['lng']),
        isOpen: j['is_open'] == true,
        nextOpeningAt: _date(j['next_opening_at']),
        managers: _int(j['managers']),
        drivers: _int(j['drivers']),
      );
}

/// Un jour des 7 derniers jours.
class DayPoint {
  final DateTime day;
  final int orders;
  final int revenue;
  const DayPoint(this.day, this.orders, this.revenue);

  factory DayPoint.fromJson(Map<String, dynamic> j) =>
      DayPoint(DateTime.tryParse('${j['day']}') ?? DateTime.now(), _int(j['orders']), _int(j['revenue']));
}

List<DayPoint> _days(dynamic v) => v is List ? v.map((e) => DayPoint.fromJson(_map(e))).toList() : const [];

/// Chiffres du jour d'un restaurant, pour la vue d'ensemble du propriétaire.
class RestaurantOverview {
  final int id;
  final String name;
  final bool active;
  final String address;
  final String phone;
  final bool isOpen;
  final bool manualOpen;
  final DateTime? nextOpeningAt;
  final int ordersToday;
  final int revenueToday;
  final int avgBasket;
  final int cancelledToday;
  final int revenueLastWeek;
  /// Évolution du chiffre d'affaires par rapport au même jour la semaine dernière (null si 0 la semaine dernière).
  final double? revenueChangePercent;
  final int activeOrders;
  final int pendingOrders;
  final int kitchenOrders;
  final int readyOrders;
  final int deliveringOrders;
  final int alerts;
  final int criticalAlerts;
  final int paymentsToReview;
  final List<DayPoint> last7Days;

  const RestaurantOverview({
    required this.id,
    required this.name,
    this.active = true,
    this.address = '',
    this.phone = '',
    this.isOpen = false,
    this.manualOpen = true,
    this.nextOpeningAt,
    this.ordersToday = 0,
    this.revenueToday = 0,
    this.avgBasket = 0,
    this.cancelledToday = 0,
    this.revenueLastWeek = 0,
    this.revenueChangePercent,
    this.activeOrders = 0,
    this.pendingOrders = 0,
    this.kitchenOrders = 0,
    this.readyOrders = 0,
    this.deliveringOrders = 0,
    this.alerts = 0,
    this.criticalAlerts = 0,
    this.paymentsToReview = 0,
    this.last7Days = const [],
  });

  /// Quelque chose demande l'attention du propriétaire.
  bool get needsAttention => criticalAlerts > 0 || paymentsToReview > 0 || pendingOrders > 0;

  factory RestaurantOverview.fromJson(Map<String, dynamic> j) {
    final today = _map(j['today']);
    final live = _map(j['live']);
    return RestaurantOverview(
      id: _int(j['id']),
      name: (j['name'] ?? '').toString(),
      active: j['active'] != false,
      address: (j['address'] ?? '').toString(),
      phone: (j['phone'] ?? '').toString(),
      isOpen: j['is_open'] == true,
      manualOpen: j['manual_open'] != false,
      nextOpeningAt: _date(j['next_opening_at']),
      ordersToday: _int(today['orders']),
      revenueToday: _int(today['revenue']),
      avgBasket: _int(today['avg_basket']),
      cancelledToday: _int(today['cancelled']),
      revenueLastWeek: _int(_map(j['same_day_last_week'])['revenue']),
      revenueChangePercent: _double(j['revenue_change_percent']),
      activeOrders: _int(live['active']),
      pendingOrders: _int(live['pending']),
      kitchenOrders: _int(live['kitchen']),
      readyOrders: _int(live['ready']),
      deliveringOrders: _int(live['delivering']),
      alerts: _int(j['alerts']),
      criticalAlerts: _int(j['critical_alerts']),
      paymentsToReview: _int(j['payments_to_review']),
      last7Days: _days(j['last7_days']),
    );
  }
}

/// Vue d'ensemble de tous les restaurants (totaux + détail).
class OwnerOverview {
  final DateTime generatedAt;
  final List<RestaurantOverview> restaurants;
  final int restaurantCount;
  final int openCount;
  final int orders;
  final int revenue;
  final int revenueLastWeek;
  final double? revenueChangePercent;
  final int activeOrders;
  final int pendingOrders;
  final int alerts;
  final int paymentsToReview;
  final List<DayPoint> last7Days;

  const OwnerOverview({
    required this.generatedAt,
    required this.restaurants,
    this.restaurantCount = 0,
    this.openCount = 0,
    this.orders = 0,
    this.revenue = 0,
    this.revenueLastWeek = 0,
    this.revenueChangePercent,
    this.activeOrders = 0,
    this.pendingOrders = 0,
    this.alerts = 0,
    this.paymentsToReview = 0,
    this.last7Days = const [],
  });

  factory OwnerOverview.fromJson(Map<String, dynamic> j) {
    final t = _map(j['totals']);
    final list = j['restaurants'] is List
        ? (j['restaurants'] as List).map((e) => RestaurantOverview.fromJson(_map(e))).toList()
        : <RestaurantOverview>[];
    return OwnerOverview(
      generatedAt: _date(j['generated_at']) ?? DateTime.now(),
      restaurants: list,
      restaurantCount: _int(t['restaurants']),
      openCount: _int(t['open']),
      orders: _int(t['orders']),
      revenue: _int(t['revenue']),
      revenueLastWeek: _int(t['same_day_last_week_revenue']),
      revenueChangePercent: _double(t['revenue_change_percent']),
      activeOrders: _int(t['active']),
      pendingOrders: _int(t['pending']),
      alerts: _int(t['alerts']),
      paymentsToReview: _int(t['payments_to_review']),
      last7Days: _days(t['last7_days']),
    );
  }
}
