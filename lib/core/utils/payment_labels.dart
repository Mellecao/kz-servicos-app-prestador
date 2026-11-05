/// Rótulo (pt-AO) do método de pagamento guardado no banco.
/// `pix` já não é oferecido; valores antigos aparecem como "Transferência".
String labelForPaymentMethod(String? method) => switch (method) {
  'cash' => 'Numerário',
  'debit' => 'Multicaixa / cartão de débito',
  'credit' => 'Cartão de crédito',
  'billing' => 'Faturação',
  'pix' => 'Transferência',
  null => '-',
  _ => method,
};
