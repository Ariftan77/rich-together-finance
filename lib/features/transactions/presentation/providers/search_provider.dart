import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/database/database.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/profile_provider.dart';

final transactionSearchQueryProvider = StateProvider<String>((ref) => '');
final transactionTypeFilterProvider = StateProvider<TransactionType?>((ref) => null);
final dateFromFilterProvider = StateProvider<DateTime?>((ref) => null);
final dateToFilterProvider = StateProvider<DateTime?>((ref) => null);
final transactionAccountFilterProvider = StateProvider<int?>((ref) => null);

final transactionLimitProvider = StateProvider<int>((ref) => 20);

final filteredTransactionsProvider = StreamProvider.autoDispose<List<Transaction>>((ref) {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) {
    return Stream.value([]);
  }
  
  final query = ref.watch(transactionSearchQueryProvider);
  final type = ref.watch(transactionTypeFilterProvider);
  final dateFrom = ref.watch(dateFromFilterProvider);
  final dateTo = ref.watch(dateToFilterProvider);
  final accountId = ref.watch(transactionAccountFilterProvider);
  final limit = ref.watch(transactionLimitProvider);
  final dao = ref.watch(transactionDaoProvider);

  return dao.watchFilteredTransactions(
    profileId: profileId,
    limit: limit,
    searchQuery: query,
    accountId: accountId,
    type: type,
    dateFrom: dateFrom,
    dateTo: dateTo,
  );
}, dependencies: [
  activeProfileIdProvider,
  transactionSearchQueryProvider,
  transactionTypeFilterProvider,
  dateFromFilterProvider,
  dateToFilterProvider,
  transactionAccountFilterProvider,
  transactionLimitProvider,
  transactionDaoProvider,
]);
