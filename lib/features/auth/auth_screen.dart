import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import '../../app/theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen(this.c, {super.key});
  final AppController c;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController();
  bool register = false, visible = false;
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  void submit() {
    if (form.currentState!.validate()) {
      widget.c.authenticate(register, name.text, email.text, password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Scaffold(
      body: SafeArea(
        child: PageBody(
          children: [
            const SizedBox(height: 32),
            const Align(
              alignment: Alignment.centerLeft,
              child: Icon(Icons.insights_rounded, size: 48, color: lime),
            ),
            const SizedBox(height: 24),
            Text(
              'MarektLens',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Apprendre à investir.\nSans engager votre argent.',
              style: TextStyle(fontSize: 22, height: 1.4),
            ),
            const SizedBox(height: 20),
            ModeBanner(c),
            Text(c.notice),
            const SizedBox(height: 24),
            Text(
              register ? 'Créer un compte local' : 'Heureux de vous retrouver',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Form(
              key: form,
              child: AutofillGroup(
                child: Column(
                  children: [
                    if (register) ...[
                      TextFormField(
                        controller: name,
                        autofillHints: const [AutofillHints.name],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Prénom'),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Votre prénom est requis.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'E-mail'),
                      validator: (v) =>
                          v == null ||
                              !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                  .hasMatch(v.trim())
                          ? 'Indiquez une adresse e-mail valide.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: password,
                      obscureText: !visible,
                      autocorrect: false,
                      autofillHints: [
                        register
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      onFieldSubmitted: (_) => submit(),
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        suffixIcon: IconButton(
                          tooltip: 'Afficher/masquer le mot de passe',
                          onPressed: () => setState(() => visible = !visible),
                          icon: Icon(
                            visible ? Icons.visibility_off : Icons.visibility,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.length < 8 || v.length > 128
                          ? '8 à 128 caractères requis.'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    if (c.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          c.error!,
                          style: const TextStyle(color: negative),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: c.loading ? null : submit,
                        child: Text(
                          c.loading
                              ? 'Ouverture du compte…'
                              : register
                              ? 'Commencer avec 10 000 USD fictifs'
                              : 'Se connecter',
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: c.loading
                          ? null
                          : () => setState(() => register = !register),
                      child: Text(
                        register ? 'J’ai déjà un compte' : 'Créer mon compte',
                      ),
                    ),
                    TextButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Récupération simulée'),
                          content: const Text(
                            'Démonstration uniquement : dans une application avec serveur, un lien serait envoyé par e-mail. Ici, aucun e-mail n’est envoyé et aucun mot de passe n’est modifié. Vous pouvez créer un autre compte local.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('J’ai compris'),
                            ),
                          ],
                        ),
                      ),
                      child: const Text('Mot de passe oublié ?'),
                    ),
                  ],
                ),
              ),
            ),
            const Text(
              'Authentification locale de démonstration. Aucun investissement ni paiement réel. Chaque compte reçoit une seule fois son capital initial dans son environnement.',
              style: TextStyle(fontSize: 12),
            ),
            if (c.mode == DataMode.demo)
              TextButton(
                onPressed: () =>
                    attempt(context, () async => c.changeMode(DataMode.normal)),
                child: const Text('Utiliser les API configurées'),
              ),
          ],
        ),
      ),
    );
  }
}
