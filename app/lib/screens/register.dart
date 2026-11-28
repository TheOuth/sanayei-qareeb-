import 'package:flutter/material.dart';
import 'app_drawer.dart';
import '../core.dart';
import '../widgets.dart';
import 'profile_form.dart';

/// إنشاء ملف صنايعي: من حساب موجود، أو حساب جديد كليًا
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final fromAcc = Store.aid != null && Store.atoken != null;
    return Scaffold(
      drawer: const AppDrawer(current: 'register'),
      appBar: bar(fromAcc ? 'التسجيل كصنايعي' : 'إنشاء حساب صنايعي'),
      body: ProfileForm(
        isRegister: true,
        fromAccount: fromAcc,
        header: fromAcc
            ? Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFE3F0FD), borderRadius: BorderRadius.circular(12)),
                child: const Text('حسابك موجود. أكمل بيانات عملك وسيصير حسابك صنايعيًا بنفس الدخول.', style: TextStyle(height: 1.5, fontWeight: FontWeight.w600)),
              )
            : const RegistrationNote(),
        onSubmit: (body) async {
          if (fromAcc) {
            final r = await Api.rpc('account_become_provider', {'p_id': Store.aid, 'p_token': Store.atoken, 'p': body});
            await Store.signIn(r['id'], r['token']);
          } else {
            final r = await Api.rpc('register_provider', {'p': body});
            // نربطه بالحساب الموحّد ليكون عنده دخول واحد
            try {
              final a = await Api.rpc('account_login', {'p_login': body['phone'], 'p_password': body['password'], 'p_anon': Store.anon});
              if (a['ok'] == true) await Store.signInAccount(a);
            } catch (_) {}
            if (!Store.loggedIn) await Store.signIn(r['id'], r['token']);
          }
          Store.refreshMe();
          if (!context.mounted) return;
          Navigator.of(context).popUntil((r) => r.isFirst);
          toast(context, 'تم إنشاء ملفك وهو قيد المراجعة. تابع حالته من «ملفي» في القائمة');
        },
      ),
    );
  }
}
