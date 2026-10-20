import 'package:flutter/material.dart';

import '../../models_restaurants.dart';
import '../../services/restaurants_api.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../utils/polling.dart';
import '../../widgets/common.dart' show EmptyState;
import 'restaurants_screen.dart';

const _weekDays = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
const _months = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

String _dayLabel(DateTime d) => '${_weekDays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';

/// Propriétaire : tous ses restaurants d'un coup d'œil (téléphone, tablette ou PC).
/// Chiffres du jour, commandes en cours, ce qui demande son attention et les 7 derniers jours.
class OwnerOverviewScreen extends StatefulWidget {
  /// Ouvrir le tableau de bord d'un restaurant.
  final void Function(int restaurantId) onOpenRestaurant;

  /// Ouvrir les commandes d'un restaurant.
  final void Function(int restaurantId) onOpenOrders;

  /// Onglet affiché : le rafraîchissement automatique ne tourne que dans ce cas.
  final bool active;

  const OwnerOverviewScreen({
    super.key,
    required this.onOpenRestaurant,
    required this.onOpenOrders,
    this.active = true,
  });

  @override
  State<OwnerOverviewScreen> createState() => _OwnerOverviewScreenState();
}

class _OwnerOverviewScreenState extends State<OwnerOverviewScreen> {
  OwnerOverview? _data;
  Object? _error;
  bool _loading = false;

  // Toutes les 30 s, jamais en arrière-plan ni quand l'onglet est caché.
  late final SmartPoller _poller = SmartPoller(
    onPoll: _load,
    getInterval: (_) => const Duration(seconds: 30),
    canPoll: () => mounted && widget.active,
  );

  @override
  void initState() {
    super.initState();
    _load();
    _poller.startPolling('on');
  }

  @override
  void didUpdateWidget(OwnerOverviewScreen old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _load();
  }

  @override
  void dispose() {
    _poller.stop();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    try {
      final data = await fetchOwnerOverview();
      if (mounted) {
        setState(() {
          _data = data;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    // Onglet caché : aucune infobulle du graphique ne reste affichée par-dessus l'onglet suivant.
    return TooltipVisibility(
      visible: widget.active,
      child: _buildPage(context, data),
    );
  }

  Widget _buildPage(BuildContext context, OwnerOverview? data) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes restaurants'),
        actions: [
          IconButton(
            tooltip: 'Gérer les restaurants',
            icon: const Icon(Icons.edit_location_alt_rounded),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const RestaurantsScreen()));
              _load();
            },
          ),
          IconButton(tooltip: 'Actualiser', icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: data == null
          ? (_error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('$_error', textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('Réessayer')),
                    ]),
                  ),
                )
              : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _load,
              child: LayoutBuilder(builder: (context, constraints) {
                final width = constraints.maxWidth;
                final columns = width >= 1300 ? 3 : (width >= 760 ? 2 : 1);
                final pad = width >= 760 ? 24.0 : 16.0;
                return ListView(
                  padding: EdgeInsets.fromLTRB(pad, 8, pad, 32),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1600),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _TotalsPanel(data: data, wide: width >= 760),
                            const SizedBox(height: 20),
                            Text('Aujourd\'hui, restaurant par restaurant',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 10),
                            if (data.restaurants.isEmpty)
                              const EmptyState(emoji: '🏪', title: 'Aucun restaurant')
                            else
                              _Grid(
                                columns: columns,
                                children: [
                                  for (final r in data.restaurants)
                                    _RestaurantCard(
                                      r: r,
                                      onOpen: r.active ? () => widget.onOpenRestaurant(r.id) : null,
                                      onOrders: r.active ? () => widget.onOpenOrders(r.id) : null,
                                    ),
                                ],
                              ),
                            const SizedBox(height: 12),
                            Text(
                              'Mis à jour ${timeAgo(data.generatedAt)} • actualisé toutes les 30 secondes',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
    );
  }
}

/// Grille simple (cartes de hauteur variable, alignées en haut de chaque rangée).
class _Grid extends StatelessWidget {
  final int columns;
  final List<Widget> children;
  const _Grid({required this.columns, required this.children});

  @override
  Widget build(BuildContext context) {
    if (columns <= 1) {
      return Column(children: [
        for (final c in children) Padding(padding: const EdgeInsets.only(bottom: 12), child: c),
      ]);
    }
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < columns; j++) ...[
                if (j > 0) const SizedBox(width: 12),
                Expanded(child: i + j < children.length ? children[i + j] : const SizedBox.shrink()),
              ],
            ],
          ),
        ),
      ));
    }
    return Column(children: rows);
  }
}

/// Évolution par rapport au même jour de la semaine dernière : flèche + pourcentage (jamais la couleur seule).
class _Change extends StatelessWidget {
  final double? percent;
  final double size;
  const _Change(this.percent, {this.size = 13});

  @override
  Widget build(BuildContext context) {
    final p = percent;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    if (p == null) {
      return Text('— vs sem. dernière', style: TextStyle(fontSize: size, color: muted));
    }
    final up = p >= 0;
    final color = up ? AppColors.green : AppColors.danger;
    final text = '${up ? '+' : ''}${p.toStringAsFixed(p.abs() >= 10 ? 0 : 1).replaceAll('.', ',')} %';
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: size + 3, color: color),
      const SizedBox(width: 3),
      Text(text, style: TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: color)),
      Text(' vs sem. dernière', style: TextStyle(fontSize: size, color: muted)),
    ]);
  }
}

/// Totaux de tous les restaurants : chiffre du jour (grand chiffre) + indicateurs + 7 derniers jours.
class _TotalsPanel extends StatelessWidget {
  final OwnerOverview data;
  final bool wide;
  const _TotalsPanel({required this.data, required this.wide});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hero = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Chiffre d\'affaires du jour • tous les restaurants',
            style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(formatPrice(data.revenue),
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, height: 1.1)),
        ),
        const SizedBox(height: 4),
        _Change(data.revenueChangePercent),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Kpi(icon: Icons.receipt_long_rounded, label: 'Commandes', value: '${data.orders}'),
            _Kpi(icon: Icons.local_fire_department_rounded, label: 'En cours', value: '${data.activeOrders}'),
            _Kpi(
              icon: Icons.hourglass_top_rounded,
              label: 'En attente',
              value: '${data.pendingOrders}',
              warn: data.pendingOrders > 0,
            ),
            _Kpi(icon: Icons.storefront_rounded, label: 'Ouverts', value: '${data.openCount}/${data.restaurantCount}'),
            if (data.paymentsToReview > 0)
              _Kpi(
                icon: Icons.price_check_rounded,
                label: 'Paiements à vérifier',
                value: '${data.paymentsToReview}',
                warn: true,
              ),
            if (data.alerts > 0)
              _Kpi(icon: Icons.notification_important_rounded, label: 'Alertes', value: '${data.alerts}', warn: true),
          ],
        ),
      ],
    );
    final chart = _WeekBars(days: data.last7Days, height: wide ? 120 : 90);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: wide
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 3, child: hero),
                const SizedBox(width: 24),
                Expanded(flex: 2, child: _chartWithTitle(context, chart)),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                hero,
                const SizedBox(height: 18),
                _chartWithTitle(context, chart),
              ]),
      ),
    );
  }

  Widget _chartWithTitle(BuildContext context, Widget chart) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Chiffre d\'affaires, 7 derniers jours',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          chart,
        ],
      );
}

class _Kpi extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool warn;
  const _Kpi({required this.icon, required this.label, required this.value, this.warn = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconColor = warn ? const Color(0xFFE08A00) : brandColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
      ]),
    );
  }
}

/// Chiffre d'affaires des 7 derniers jours : une barre par jour (une seule série, couleur de la marque),
/// détail au survol ou à l'appui long, valeur du jour écrite au-dessus de la dernière barre.
class _WeekBars extends StatelessWidget {
  final List<DayPoint> days;
  final double height;
  const _WeekBars({required this.days, this.height = 90});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (days.isEmpty) return SizedBox(height: height);
    final max = days.map((d) => d.revenue).fold<int>(0, (a, b) => a > b ? a : b);
    final color = brandColor(context);
    return SizedBox(
      height: height + 34,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < days.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Expanded(
              child: Tooltip(
                message: '${_dayLabel(days[i].day)} : ${formatPrice(days[i].revenue)} • '
                    '${days[i].orders} commande${days[i].orders > 1 ? 's' : ''}',
                triggerMode: TooltipTriggerMode.tap,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (i == days.length - 1)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(formatPrice(days[i].revenue),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    const SizedBox(height: 2),
                    Center(
                      child: FractionallySizedBox(
                        widthFactor: 0.62,
                        child: Container(
                          // Hauteur minimale de 2 px : un jour sans vente reste visible sur la ligne de base.
                          height: max == 0 ? 2 : (days[i].revenue / max * height).clamp(2, height).toDouble(),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                      ),
                    ),
                    Container(height: 1, color: scheme.outlineVariant),
                    const SizedBox(height: 4),
                    Text(
                      i == days.length - 1 ? 'auj.' : _weekDays[days[i].day.weekday - 1],
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Carte d'un restaurant : ouverture, chiffre du jour, commandes en cours, ce qui demande attention.
class _RestaurantCard extends StatelessWidget {
  final RestaurantOverview r;
  final VoidCallback? onOpen;
  final VoidCallback? onOrders;
  const _RestaurantCard({required this.r, this.onOpen, this.onOrders});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final String openText;
    if (!r.active) {
      openText = 'Fermé définitivement';
    } else if (r.isOpen) {
      openText = 'Ouvert';
    } else if (!r.manualOpen) {
      openText = 'Fermé (interrupteur)';
    } else if (r.nextOpeningAt != null) {
      final t = r.nextOpeningAt!;
      openText = 'Fermé • ouvre ${_dayLabel(t)} à ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    } else {
      openText = 'Fermé';
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(r.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                ),
                _OpenBadge(open: r.active && r.isOpen, label: r.active && r.isOpen ? 'Ouvert' : 'Fermé'),
              ]),
              const SizedBox(height: 2),
              Text(
                r.address.isEmpty ? openText : '$openText • ${r.address}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: muted, fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(formatPrice(r.revenueToday),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(height: 2),
                    _Change(r.revenueChangePercent, size: 12),
                  ]),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${r.ordersToday}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  Text('commande${r.ordersToday > 1 ? 's' : ''}', style: TextStyle(color: muted, fontSize: 12)),
                ]),
              ]),
              if (r.avgBasket > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Panier moyen ${formatPrice(r.avgBasket)}', style: TextStyle(color: muted, fontSize: 12.5)),
                ),
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, children: [
                _Pill('En attente', r.pendingOrders, highlight: r.pendingOrders > 0),
                _Pill('En cuisine', r.kitchenOrders),
                _Pill('Prêtes', r.readyOrders),
                _Pill('En livraison', r.deliveringOrders),
              ]),
              if (r.paymentsToReview > 0 || r.alerts > 0) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 12, runSpacing: 6, children: [
                  if (r.paymentsToReview > 0)
                    _Warn(Icons.price_check_rounded,
                        '${r.paymentsToReview} paiement${r.paymentsToReview > 1 ? 's' : ''} à vérifier'),
                  if (r.alerts > 0)
                    _Warn(
                      Icons.notification_important_rounded,
                      '${r.alerts} alerte${r.alerts > 1 ? 's' : ''}'
                      '${r.criticalAlerts > 0 ? ' dont ${r.criticalAlerts} critique${r.criticalAlerts > 1 ? 's' : ''}' : ''}',
                      critical: r.criticalAlerts > 0,
                    ),
                ]),
              ],
              const SizedBox(height: 14),
              _WeekBars(days: r.last7Days, height: 46),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOrders,
                    icon: const Icon(Icons.receipt_long_rounded, size: 18),
                    label: const Text('Commandes'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.insights_rounded, size: 18),
                    label: const Text('Détails'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpenBadge extends StatelessWidget {
  final bool open;
  final String label;
  const _OpenBadge({required this.open, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = open ? AppColors.green : Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(open ? Icons.check_circle_rounded : Icons.do_not_disturb_on_rounded, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final int count;
  final bool highlight;
  const _Pill(this.label, this.count, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFE08A00).withValues(alpha: 0.14) : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text.rich(TextSpan(children: [
        TextSpan(text: '$count ', style: const TextStyle(fontWeight: FontWeight.w900)),
        TextSpan(text: label, style: TextStyle(color: scheme.onSurfaceVariant)),
      ]), style: const TextStyle(fontSize: 12.5)),
    );
  }
}

class _Warn extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool critical;
  const _Warn(this.icon, this.text, {this.critical = false});

  @override
  Widget build(BuildContext context) {
    final color = critical ? AppColors.danger : const Color(0xFFE08A00);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
    ]);
  }
}
