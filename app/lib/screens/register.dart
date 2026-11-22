import 'package:flutter/material.dart';
import '../core.dart';
import 'dashboard.dart';
import 'profile_form.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سجّل كصنايعي')),
      body: ProfileForm(
        isRegister: true,
        onSubmit: (body) async {
          final r = await Api.rpc('register_provider', {'p': body});
          await Store.signIn(r['id'], r['token']);
          if (!context.mounted) return;
          Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const DashboardScreen()), (r) => r.isFirst);
        },
      ),
    );
  }
}
