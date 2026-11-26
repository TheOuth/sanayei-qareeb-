import 'package:flutter/material.dart';
import 'app_drawer.dart';
import 'legal.dart';
import '../core.dart';
import '../update_gate.dart';
import '../theme.dart';
import '../widgets.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final wa = (Meta.cfg['support_whatsapp'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
    final mail = (Meta.cfg['support_email'] ?? '').toString();
    return Scaffold(
      drawer: const AppDrawer(current: 'about'),
      appBar: bar('عن التطبيق'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('صنايعي قريب يوصلك بأقرب صنايعي في منطقتك بالاتصال أو الواتساب مباشرة، مجانًا للزبائن.', style: TextStyle(height: 1.6)),
        const SizedBox(height: 14),
        if (wa.isNotEmpty) Card(child: ListTile(leading: const Icon(Icons.chat_rounded, color: C.green), title: const Text('الدعم على واتساب'), onTap: () => openUrl('https://wa.me/$wa'))),
        if (mail.isNotEmpty) Card(child: ListTile(leading: const Icon(Icons.email_outlined), title: Text(mail), onTap: () => openUrl('mailto:$mail'))),
        Card(child: ListTile(leading: const Icon(Icons.privacy_tip_outlined), title: const Text('سياسة الخصوصية'), trailing: const Icon(Icons.chevron_left_rounded), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalScreen())))),
        Card(child: ListTile(leading: const Icon(Icons.gavel_rounded), title: const Text('قوانين التطبيق'), trailing: const Icon(Icons.chevron_left_rounded), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalScreen(initial: 1))))),
        const SizedBox(height: 20),
        Center(child: Text('الإصدار ${AppVersion.name} (${AppVersion.build})', style: const TextStyle(color: C.mute, fontSize: 12))),
      ]),
    );
  }
}
