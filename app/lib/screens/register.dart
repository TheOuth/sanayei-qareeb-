import 'package:flutter/material.dart';
import 'app_drawer.dart';
import '../core.dart';
import '../widgets.dart';
import 'profile_form.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(current: 'register'),
      appBar: bar('سجّل كصنايعي'),
      body: ProfileForm(
        isRegister: true,
        onSubmit: (body) async {
          final r = await Api.rpc('register_provider', {'p': body});
          await Store.signIn(r['id'], r['token']);
          Store.refreshMe();
          if (!context.mounted) return;
          Navigator.of(context).popUntil((r) => r.isFirst);
          toast(context, 'تم إنشاء حسابك وهو قيد المراجعة. تابع حالته من لوحتي في القائمة');
        },
      ),
    );
  }
}
