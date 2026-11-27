import 'package:flutter/material.dart';
import '../core.dart';
import '../theme.dart';
import '../widgets.dart';
import 'app_drawer.dart' show bar;

/// صفحة كاملة لرسالة واحدة (نص طويل، روابط كأزرار، وزر تحديث إن كانت رسالة تحديث)
class NotificationDetailScreen extends StatelessWidget {
  final Map n;
  final VoidCallback? target;
  final String targetLabel;
  const NotificationDetailScreen({super.key, required this.n, this.target, this.targetLabel = 'فتح القسم'});

  static final urlRe = RegExp(r'https?://[^\s<>"]+', caseSensitive: false);

  String _when() {
    final d = DateTime.fromMillisecondsSinceEpoch((n['ts'] as num).toInt());
    String t2(int v) => v.toString().padLeft(2, '0');
    return '${d.year}/${t2(d.month)}/${t2(d.day)}  ${t2(d.hour)}:${t2(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final title = (n['title'] ?? '').toString();
    final body = (n['body'] ?? '').toString();
    final kind = (n['kind'] ?? '').toString().split(':')[0];
    final links = urlRe.allMatches(body).map((m) => m.group(0)!.replaceAll(RegExp(r'[).,،؛]+$'), '')).toSet().toList();
    final upUrl = (Meta.cfg['update_url'] ?? '').toString();
    return Scaffold(
      appBar: bar('الرسالة', bell: false, menu: false),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.hair)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, height: 1.5)),
            const SizedBox(height: 4),
            Text(_when(), style: const TextStyle(fontSize: 12, color: C.mute)),
            if (body.isNotEmpty) ...[
              const Divider(height: 26),
              SelectableText(body, style: const TextStyle(fontSize: 15.5, height: 1.9)),
            ],
          ]),
        ),
        if (kind == 'update' && upUrl.isNotEmpty) ...[
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: () => openUrl(upUrl), icon: const Icon(Icons.system_update_rounded), label: const Text('تحديث الآن')),
        ],
        for (final u in links.where((u) => !(kind == 'update' && u == upUrl))) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: () => openUrl(u), icon: const Icon(Icons.open_in_new_rounded), label: Text(u.replaceFirst(RegExp(r'^https?://'), ''), maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.ltr)),
        ],
        if (target != null) ...[
          const SizedBox(height: 10),
          OutlinedButton(onPressed: target, child: Text(targetLabel)),
        ],
      ]),
    );
  }
}
