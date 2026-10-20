import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models_restaurants.dart';
import '../providers/cart_provider.dart';
import '../services/restaurant_scope.dart';
import '../theme.dart';
import 'common.dart' show confirmDialog;

/// Point vert (ouvert) ou gris (fermé).
class _OpenDot extends StatelessWidget {
  final bool open;
  const _OpenDot(this.open);

  @override
  Widget build(BuildContext context) => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: open ? AppColors.green : Theme.of(context).colorScheme.outline,
          shape: BoxShape.circle,
        ),
      );
}

/// Liste des choix (« Tous les restaurants » en option) dans une feuille du bas.
Future<String?> _pickRestaurant(
  BuildContext context, {
  required List<Restaurant> restaurants,
  required String? current,
  bool allowAll = false,
  String title = 'Choisir un restaurant',
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.75),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            if (allowAll)
              ListTile(
                leading: const Icon(Icons.dashboard_rounded),
                title: const Text('Tous les restaurants', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Vue d\'ensemble, commandes et rapports de tous vos restaurants'),
                trailing: current == RestaurantScope.all ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.pop(ctx, RestaurantScope.all),
              ),
            for (final r in restaurants)
              ListTile(
                leading: const Icon(Icons.storefront_rounded),
                title: Row(
                  children: [
                    Flexible(child: Text(r.name, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    _OpenDot(r.active && r.isOpen),
                  ],
                ),
                subtitle: Text(
                  !r.active ? 'Fermé définitivement' : (r.address.isEmpty ? (r.isOpen ? 'Ouvert' : 'Fermé') : r.address),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: current == '${r.id}' ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.pop(ctx, '${r.id}'),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Barre du propriétaire en haut de l'espace de gestion : restaurant suivi (ou tous), touchée pour en changer.
class OwnerRestaurantBar extends StatelessWidget {
  const OwnerRestaurantBar({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = RestaurantScope.instance;
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<List<Restaurant>>(
      valueListenable: scope.restaurants,
      builder: (context, restaurants, _) => ValueListenableBuilder<String?>(
        valueListenable: scope.current,
        builder: (context, current, _) {
          final selected = scope.selected;
          // Écran peu haut (smartphone couché) : barre sur une ligne, sans sous-titre.
          final compact = MediaQuery.sizeOf(context).height < 500;
          return Material(
            color: scheme.surfaceContainerHigh,
            child: SafeArea(
              bottom: false,
              child: InkWell(
                onTap: () async {
                  final choice = await _pickRestaurant(context,
                      restaurants: restaurants, current: current, allowAll: true, title: 'Restaurant suivi');
                  if (choice != null) await scope.select(choice);
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: compact ? 6 : 10),
                  child: Row(
                    children: [
                      Icon(scope.isAll ? Icons.dashboard_rounded : Icons.storefront_rounded, color: brandColor(context)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              scope.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                            if (!compact) Text(
                              scope.isAll
                                  ? '${restaurants.length} restaurant${restaurants.length > 1 ? 's' : ''} • touchez pour en choisir un'
                                  : selected == null
                                      ? 'Touchez pour choisir'
                                      : (selected.isOpen ? 'Ouvert' : 'Fermé'),
                              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      if (selected != null) ...[_OpenDot(selected.active && selected.isOpen), const SizedBox(width: 8)],
                      const Icon(Icons.unfold_more_rounded),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Onglet qui exige un restaurant précis (caisse, menu) alors que le propriétaire suit « tous les restaurants ».
class ChooseRestaurantView extends StatelessWidget {
  final String title;
  final String message;
  const ChooseRestaurantView({super.key, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final scope = RestaurantScope.instance;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ValueListenableBuilder<List<Restaurant>>(
        valueListenable: scope.restaurants,
        builder: (context, restaurants, _) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                Icon(Icons.storefront_rounded, size: 56, color: brandColor(context)),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 20),
                for (final r in restaurants.where((r) => r.active))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      onPressed: () => scope.selectRestaurant(r.id),
                      icon: _OpenDot(r.isOpen),
                      label: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Client : restaurant où il commande (affiché seulement s'il y en a plusieurs). Changer vide le panier.
class ClientRestaurantSelector extends StatelessWidget {
  const ClientRestaurantSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = RestaurantScope.instance;
    return ValueListenableBuilder<List<Restaurant>>(
      valueListenable: scope.restaurants,
      builder: (context, restaurants, _) => ValueListenableBuilder<String?>(
        valueListenable: scope.current,
        builder: (context, current, _) {
          if (restaurants.length < 2) return const SizedBox.shrink();
          final selected = scope.selected;
          return ActionChip(
            avatar: Icon(Icons.storefront_rounded, size: 18, color: brandColor(context)),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(selected?.name ?? 'Choisir un restaurant',
                      overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                const Icon(Icons.expand_more_rounded, size: 18),
              ],
            ),
            onPressed: () => changeClientRestaurant(context),
          );
        },
      ),
    );
  }
}

/// Feuille de choix du restaurant du client ; confirmation si le panier n'est pas vide.
Future<void> changeClientRestaurant(BuildContext context) async {
  final scope = RestaurantScope.instance;
  final cart = context.read<CartProvider>();
  final choice = await _pickRestaurant(context,
      restaurants: scope.restaurants.value, current: scope.current.value, title: 'Où voulez-vous commander ?');
  if (choice == null || choice == scope.current.value || !context.mounted) return;
  if (!cart.isEmpty) {
    final ok = await confirmDialog(context, 'Changer de restaurant',
        'Votre panier contient des plats d\'un autre restaurant : il sera vidé.', confirm: 'Changer');
    if (!ok) return;
  }
  await scope.select(choice);
  final id = scope.restaurantId;
  if (id != null) await cart.useRestaurant(id);
}
