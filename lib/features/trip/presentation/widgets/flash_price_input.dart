import 'package:flutter/material.dart';

class FlashPriceInput extends StatefulWidget {
  final void Function(double price) onSubmit;
  const FlashPriceInput({super.key, required this.onSubmit});

  @override
  State<FlashPriceInput> createState() => _FlashPriceInputState();
}

class _FlashPriceInputState extends State<FlashPriceInput> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Valor da proposta (R\$)',
            errorText: _error,
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () {
            final raw = _controller.text.replaceAll(',', '.').trim();
            final parsed = double.tryParse(raw);
            if (parsed == null || parsed <= 0 || parsed > 10000) {
              setState(() => _error = 'Preço inválido');
              return;
            }
            setState(() => _error = null);
            widget.onSubmit(parsed);
          },
          child: const Text('Enviar proposta'),
        ),
      ],
    );
  }
}
