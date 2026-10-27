import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<int?> quantityDialog(
  BuildContext context, {
  required String title,
  int initial = 1,
  int maximum = 1000000,
  String? subtitle,
}) async {
  return showDialog<int>(
    context: context,
    builder: (context) => _QuantityDialog(title, initial, maximum, subtitle),
  );
}

class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog(this.title, this.initial, this.maximum, this.subtitle);
  final String title;
  final int initial, maximum;
  final String? subtitle;
  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  late final controller = TextEditingController(text: '${widget.initial}');
  final key = GlobalKey<FormState>();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SingleChildScrollView(
      child: Form(
        key: key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.subtitle != null) ...[
              Text(widget.subtitle!),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Quantité (1 à ${widget.maximum})',
              ),
              validator: (v) {
                final q = int.tryParse(v ?? '');
                return q == null || q <= 0 || q > widget.maximum
                    ? 'Entier requis, entre 1 et ${widget.maximum}.'
                    : null;
              },
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: () {
          if (key.currentState!.validate()) {
            Navigator.pop(context, int.parse(controller.text));
          }
        },
        child: const Text('Valider'),
      ),
    ],
  );
}
