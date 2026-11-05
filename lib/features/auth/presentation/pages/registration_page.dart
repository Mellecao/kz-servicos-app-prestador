import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/utils/angola_phone.dart';
import 'package:kz_servicos_prestador/core/utils/document_validator.dart';
import 'package:kz_servicos_prestador/features/profile/data/models/mock_provider.dart';

class RegistrationPage extends StatefulWidget {
  final ValueChanged<ProviderType> onComplete;
  final ProviderType providerType;

  const RegistrationPage({
    super.key,
    required this.onComplete,
    required this.providerType,
  });

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

FormFieldValidator<String> _validated(
  bool Function(String) isValid,
  String message,
) => (v) {
  if (v == null || v.trim().isEmpty) return 'Campo obrigatório';
  return isValid(v) ? null : message;
};

class _RegistrationPageState extends State<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  int _step = 0;

  // Personal
  final _nameController = TextEditingController();
  final _cpfController = TextEditingController();
  final _phoneController = TextEditingController();

  // CNH
  final _cnhNumberController = TextEditingController();
  final _cnhCategoryController = TextEditingController();
  final _cnhExpiryController = TextEditingController();

  // Vehicle
  final _vehiclePlateController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleYearController = TextEditingController();
  final _vehicleColorController = TextEditingController();

  // Bank
  final _bankNameController = TextEditingController();
  final _bankAgencyController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _pixKeyController = TextEditingController();

  // Service categories
  final Set<String> _selectedCategories = {};

  bool get _isDriver => widget.providerType == ProviderType.driver;

  List<String> get _stepTitles => _isDriver
      ? const [
          'Dados pessoais',
          'Carta de condução',
          'Veículo',
          'Dados bancários',
        ]
      : const ['Dados pessoais', 'Categorias de serviço', 'Dados bancários'];

  int get _totalSteps => _stepTitles.length;

  @override
  void dispose() {
    _nameController.dispose();
    _cpfController.dispose();
    _phoneController.dispose();
    _cnhNumberController.dispose();
    _cnhCategoryController.dispose();
    _cnhExpiryController.dispose();
    _vehiclePlateController.dispose();
    _vehicleModelController.dispose();
    _vehicleYearController.dispose();
    _vehicleColorController.dispose();
    _bankNameController.dispose();
    _bankAgencyController.dispose();
    _bankAccountController.dispose();
    _pixKeyController.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == _providerCategoriesStepIndex && !_isDriver) {
      if (_selectedCategories.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione pelo menos uma categoria')),
        );
        return;
      }
      if (_step < _totalSteps - 1) {
        setState(() => _step++);
      } else {
        widget.onComplete(widget.providerType);
      }
      return;
    }
    if (_formKey.currentState?.validate() ?? false) {
      if (_step < _totalSteps - 1) {
        setState(() => _step++);
      } else {
        widget.onComplete(widget.providerType);
      }
    }
  }

  int get _providerCategoriesStepIndex => _isDriver ? -1 : 1;

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: _back,
        ),
        title: Text(
          'Registo - ${_stepTitles[_step]}',
          style: const TextStyle(
            fontFamily: 'OutfitBlack',
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildProgressBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(key: _formKey, child: _buildCurrentStep()),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: List.generate(_totalSteps, (i) {
          return Expanded(
            child: Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: i <= _step
                    ? AppColors.highlight
                    : AppColors.highlight.withValues(alpha: 0.2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep() {
    if (_isDriver) {
      return switch (_step) {
        0 => _buildPersonalStep(),
        1 => _buildCnhStep(),
        2 => _buildVehicleStep(),
        3 => _buildBankStep(),
        _ => const SizedBox.shrink(),
      };
    }
    return switch (_step) {
      0 => _buildPersonalStep(),
      1 => _buildServiceCategoriesStep(),
      2 => _buildBankStep(),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildPersonalStep() {
    return Column(
      children: [
        _field(_nameController, 'Nome completo', Icons.person_outline),
        const SizedBox(height: 16),
        _field(
          _cpfController,
          'BI / NIF',
          Icons.badge_outlined,
          formatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 -]')),
            LengthLimitingTextInputFormatter(18),
          ],
          validator: _validated(isValidBiNif, 'BI ou NIF inválido'),
        ),
        const SizedBox(height: 16),
        _field(
          _phoneController,
          'Telemóvel',
          Icons.phone_outlined,
          keyboard: TextInputType.phone,
          prefixText: '$kAngolaDialCode ',
          formatters: [PhoneInputFormatter()],
          validator: _validated(isValidAngolaPhone, 'Telemóvel inválido'),
        ),
      ],
    );
  }

  Widget _buildCnhStep() {
    return Column(
      children: [
        _field(
          _cnhNumberController,
          'Número da carta de condução',
          Icons.credit_card_outlined,
          keyboard: TextInputType.number,
        ),
        const SizedBox(height: 16),
        _field(
          _cnhCategoryController,
          'Categoria (A, B, C, D, E)',
          Icons.category_outlined,
        ),
        const SizedBox(height: 16),
        _field(
          _cnhExpiryController,
          'Validade (MM/AAAA)',
          Icons.calendar_today_outlined,
          keyboard: TextInputType.datetime,
        ),
      ],
    );
  }

  Widget _buildVehicleStep() {
    return Column(
      children: [
        _field(_vehiclePlateController, 'Matrícula', Icons.pin_outlined),
        const SizedBox(height: 16),
        _field(
          _vehicleModelController,
          'Modelo',
          Icons.directions_car_outlined,
        ),
        const SizedBox(height: 16),
        _field(
          _vehicleYearController,
          'Ano',
          Icons.date_range_outlined,
          keyboard: TextInputType.number,
        ),
        const SizedBox(height: 16),
        _field(_vehicleColorController, 'Cor', Icons.palette_outlined),
      ],
    );
  }

  static const _serviceCategories = [
    'Eletricista',
    'Canalizador',
    'Pintor',
    'Limpeza geral',
    'Montador de Móveis',
    'Técnico de Informática',
    'Jardineiro',
    'Pedreiro',
    'Chaveiro',
    'Ar condicionado',
    'Carpinteiro',
    'Vidraceiro',
    'Serralheiro',
    'Controlo de pragas',
  ];

  Widget _buildServiceCategoriesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selecione as suas especialidades',
          style: TextStyle(
            fontFamily: 'OutfitBlack',
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Escolha uma ou mais categorias de serviço',
          style: TextStyle(
            fontFamily: 'QuasimodoSemiBold',
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _serviceCategories.map((cat) {
            final isSelected = _selectedCategories.contains(cat);
            return GestureDetector(
              onTap: () => setState(() {
                if (isSelected) {
                  _selectedCategories.remove(cat);
                } else {
                  _selectedCategories.add(cat);
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.highlight : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.highlight
                        : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  cat,
                  style: TextStyle(
                    fontFamily: 'QuasimodoSemiBold',
                    fontSize: 13,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBankStep() {
    return Column(
      children: [
        _field(_bankNameController, 'Banco', Icons.account_balance_outlined),
        const SizedBox(height: 16),
        _field(
          _bankAgencyController,
          'Agência',
          Icons.numbers_outlined,
          keyboard: TextInputType.number,
        ),
        const SizedBox(height: 16),
        _field(
          _bankAccountController,
          'Conta',
          Icons.account_box_outlined,
          keyboard: TextInputType.number,
        ),
        const SizedBox(height: 16),
        _field(
          _pixKeyController,
          'IBAN',
          Icons.account_balance_wallet_outlined,
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    FormFieldValidator<String>? validator,
    String? prefixText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      inputFormatters: formatters,
      validator:
          validator ??
          (v) => (v == null || v.isEmpty) ? 'Campo obrigatório' : null,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefixText,
        prefixIcon: Icon(icon, color: AppColors.textSecondary),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final isLast = _step == _totalSteps - 1;
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: ElevatedButton(
        onPressed: _next,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.highlight,
          foregroundColor: AppColors.onHighlight,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontFamily: 'OutfitBlack', fontSize: 16),
        ),
        child: Text(isLast ? 'Concluir registo' : 'Próximo'),
      ),
    );
  }
}
