enum ProviderType { driver, serviceProvider }

class MockProvider {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? avatarUrl;
  final String cpf;
  final String? cnhNumber;
  final String? cnhExpiry;
  final String? vehiclePlate;
  final String? vehicleModel;
  final int? vehicleYear;
  final String? vehicleColor;
  final double rating;
  final int completedTrips;
  final double profileCompletion;
  final bool isOnline;
  final double balance;
  final String? cnhCategory;
  final String memberSince;
  final String bankName;
  final String bankAgency;
  final String bankAccount;
  final String pixKey;
  final ProviderType providerType;
  final List<String> serviceCategories;
  final String password;

  const MockProvider({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.cpf,
    required this.rating,
    required this.completedTrips,
    required this.profileCompletion,
    required this.isOnline,
    required this.balance,
    required this.memberSince,
    required this.bankName,
    required this.bankAgency,
    required this.bankAccount,
    required this.pixKey,
    required this.providerType,
    required this.password,
    this.cnhNumber,
    this.cnhExpiry,
    this.cnhCategory,
    this.vehiclePlate,
    this.vehicleModel,
    this.vehicleYear,
    this.vehicleColor,
    this.avatarUrl,
    this.serviceCategories = const [],
  });

  bool get isDriver => providerType == ProviderType.driver;
  bool get isServiceProvider => providerType == ProviderType.serviceProvider;

  static final MockProvider driverSample = MockProvider(
    id: 'provider_1',
    name: 'João Silva',
    email: 'joao.silva@email.com',
    phone: '+244 923 456 789',
    cpf: 'BI *****90',
    cnhNumber: '01234567890',
    cnhExpiry: '15/08/2028',
    cnhCategory: 'B',
    vehiclePlate: 'ABC-1D23',
    vehicleModel: 'Toyota Corolla',
    vehicleYear: 2023,
    vehicleColor: 'Prata',
    rating: 4.9,
    completedTrips: 312,
    profileCompletion: 0.92,
    isOnline: true,
    balance: 4280.50,
    memberSince: '2024',
    bankName: 'Nubank',
    bankAgency: '0001',
    bankAccount: '****5678',
    pixKey: 'joao.silva@email.com',
    providerType: ProviderType.driver,
    password: '123456',
  );

  static final MockProvider providerSample = MockProvider(
    id: 'provider_2',
    name: 'Maria Fernanda Santos',
    email: 'maria.santos@email.com',
    phone: '+244 924 567 890',
    cpf: 'BI *****45',
    rating: 4.7,
    completedTrips: 89,
    profileCompletion: 0.88,
    isOnline: true,
    balance: 2150.00,
    memberSince: '2025',
    bankName: 'Inter',
    bankAgency: '0001',
    bankAccount: '****1234',
    pixKey: 'maria.santos@email.com',
    providerType: ProviderType.serviceProvider,
    password: '654321',
    serviceCategories: ['Eletricista', 'Canalizador'],
  );

  static final MockProvider sample = driverSample;
}
