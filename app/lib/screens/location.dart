import 'package:flutter/material.dart';
import '../core.dart';
import '../widgets.dart';
import '../theme.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});
  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  StateG? _st;
  bool _busy = false;

  Future<void> _gps() async {
    setState(() => _busy = true);
    final l = await detectLocation(context);
    if (!mounted) return;
    setState(() => _busy = false);
    if (l != null) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: Text(_st == null ? 'موقعي' : _st!.name), leading: BackButton(onPressed: () { if (_st == null) { Navigator.pop(context); } else { setState(() => _st = null); } })),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (_st == null) ...[
          FilledButton.icon(
            onPressed: _busy ? null : _gps,
            icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.my_location_rounded),
            label: const Text('حدّد موقعي تلقائيًا (GPS)'),
          ),
          const SizedBox(height: 6),
          const Text('الـ GPS يعطيك الأقرب بدقة. أو اختر ولايتك ثم مدينتك:', style: TextStyle(color: C.mute, fontSize: 13)),
          const SizedBox(height: 10),
          for (final s in Meta.states) Card(child: ListTile(title: Text(s.name), trailing: const Icon(Icons.chevron_left_rounded), onTap: () => setState(() => _st = s))),
        ] else
          for (final c in _st!.cities)
            Card(
              child: ListTile(
                title: Text(c.name),
                onTap: () async {
                  await Store.setLoc({'lat': c.lat, 'lng': c.lng, 'city_id': c.id, 'label': c.name, 'gps': false});
                  if (mounted) Navigator.pop(context, true);
                },
              ),
            ),
      ]),
    );
  }
}
