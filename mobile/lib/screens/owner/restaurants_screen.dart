import 'package:flutter/material.dart';

import '../../models_restaurants.dart';
import '../../services/restaurant_scope.dart';
import '../../services/restaurants_api.dart';
import '../../theme.dart';
import '../../widgets/common.dart' show confirmDialog, showMessage;
import '../admin/admin_layout.dart';

/// Propriétaire : ajouter, renommer, fermer ou rouvrir ses restaurants.
/// Adresse, téléphone, horaires et frais se règlent ensuite dans « Paramètres du restaurant ».
class RestaurantsScreen extends StatefulWidget {
  const RestaurantsScreen({super.key});

  @override
  State<RestaurantsScreen> createState() => _RestaurantsScreenState();
}

class _RestaurantsScreenState extends State<RestaurantsScreen> {
  List<Restaurant>? _list;
  Object? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await fetchOwnerRestaurants();
      // Le sélecteur de restaurant de l'espace de gestion suit aussitôt.
      RestaurantScope.instance.setRestaurants(list, fallback: RestaurantScope.all);
      if (mounted) {
        setState(() {
          _list = list;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _load();
      if (mounted) showMessage(context, done);
    } catch (e) {
      if (mounted) showMessage(context, e, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    final result = await showDialog<_NewRestaurant>(
      context: context,
      builder: (_) => _NewRestaurantDialog(existing: _list ?? const []),
    );
    if (result == null) return;
    await _run(
      () => createRestaurant(
        name: result.name,
        address: result.address,
        phone: result.phone,
        copyMenuFrom: result.copyMenuFrom,
      ),
      'Restaurant « ${result.name} » créé',
    );
  }

  Future<void> _rename(Restaurant r) async {
    final controller = TextEditingController(text: r.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renommer'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nom du restaurant'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Enregistrer')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || name == r.name) return;
    await _run(() => updateRestaurant(r.id, name: name), 'Restaurant renommé');
  }

  Future<void> _toggle(Restaurant r) async {
    if (r.active) {
      final ok = await confirmDialog(
        context,
        'Fermer « ${r.name} » ?',
        'Les clients ne pourront plus y commander et il disparaîtra de l\'application. '
            'Son historique (commandes, rapports, encaissements) reste consultable. Vous pourrez le rouvrir.',
        confirm: 'Fermer définitivement',
        danger: true,
      );
      if (!ok) return;
    }
    await _run(() => updateRestaurant(r.id, active: !r.active), r.active ? 'Restaurant fermé' : 'Restaurant rouvert');
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('Gérer mes restaurants')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy || list == null ? null : _create,
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('Nouveau restaurant'),
      ),
      body: list == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('$_error', textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('Réessayer')),
                      ]),
                    ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: MaxContentWidth(
                maxWidth: 820,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                      child: Text(
                        'Chaque restaurant a son menu, ses horaires, ses zones de livraison, ses gérants et ses livreurs. '
                        'Choisissez un restaurant en haut de l\'écran pour régler ses paramètres.',
                        style: TextStyle(color: muted),
                      ),
                    ),
                    for (final r in list)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                          child: Row(children: [
                            Icon(Icons.storefront_rounded, color: r.active ? brandColor(context) : muted),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(r.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                const SizedBox(height: 2),
                                Text(
                                  [
                                    if (!r.active) 'Fermé définitivement' else (r.isOpen ? 'Ouvert' : 'Fermé'),
                                    if (r.address.isNotEmpty) r.address,
                                    '${r.managers} gérant${r.managers > 1 ? 's' : ''}',
                                    '${r.drivers} livreur${r.drivers > 1 ? 's' : ''}',
                                  ].join(' • '),
                                  style: TextStyle(color: muted, fontSize: 12.5),
                                ),
                              ]),
                            ),
                            IconButton(
                              tooltip: 'Renommer',
                              onPressed: _busy ? null : () => _rename(r),
                              icon: const Icon(Icons.edit_rounded),
                            ),
                            Switch(value: r.active, onChanged: _busy ? null : (_) => _toggle(r)),
                          ]),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _NewRestaurant {
  final String name;
  final String address;
  final String phone;
  final int? copyMenuFrom;
  const _NewRestaurant(this.name, this.address, this.phone, this.copyMenuFrom);
}

class _NewRestaurantDialog extends StatefulWidget {
  final List<Restaurant> existing;
  const _NewRestaurantDialog({required this.existing});

  @override
  State<_NewRestaurantDialog> createState() => _NewRestaurantDialogState();
}

class _NewRestaurantDialogState extends State<_NewRestaurantDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  late int? _copyFrom = widget.existing.where((r) => r.active).firstOrNull?.id;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(context, _NewRestaurant(_name.text.trim(), _address.text.trim(), _phone.text.trim(), _copyFrom));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouveau restaurant'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nom', hintText: 'ex. Eza Zozo Bè'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Nom requis' : null,
              ),
              TextFormField(
                controller: _address,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Adresse (facultatif)'),
              ),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                maxLength: 30,
                decoration: const InputDecoration(labelText: 'Téléphone (facultatif)'),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<int?>(
                initialValue: _copyFrom,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Menu de départ'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Menu vide')),
                  for (final r in widget.existing)
                    DropdownMenuItem<int?>(value: r.id, child: Text('Copier le menu de ${r.name}', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _copyFrom = v),
              ),
              const SizedBox(height: 8),
              Text(
                _copyFrom == null
                    ? 'Le restaurant démarre sans plats : ajoutez-les dans l\'onglet Menu.'
                    : 'Plats, packs, prix et règles de livraison sont recopiés ; vous pourrez les modifier ensuite.',
                style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: _submit, child: const Text('Créer')),
      ],
    );
  }
}
