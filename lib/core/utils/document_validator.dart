final RegExp _biNif = RegExp(r'^[A-Za-z0-9]{9,14}$');

/// BI / NIF: validação permissiva (alfanumérico, 9 a 14 caracteres).
/// Ignora espaços e hífens. A coluna `users.cpf` guarda este valor.
bool isValidBiNif(String input) =>
    _biNif.hasMatch(input.trim().replaceAll(RegExp(r'[\s-]'), ''));
