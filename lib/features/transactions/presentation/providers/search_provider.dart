import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/database/database.dart';
import '../../../../core/providers/database_providers.dart';

final transactionSearchQueryProvider = StateProvider<String>((ref) => '');
final transactionTypeFilterProvider = StateProvider<TransactionType?>((ref) => null);
final dateFromFilterProvider = StateProvider<DateTime?>((ref) => null);
final dateToFilterProvider = StateProvider<DateTime?>((ref) => null);

final filteredTransactionsProvider = StreamProvider.autoDispose<List<Transaction>>((ref) async* {
  final query = ref.watch(transactionSearchQueryProvider).toLowerCase();
  final type = ref.watch(transactionTypeFilterProvider);
  final dateFrom = ref.watch(dateFromFilterProvider);
  final dateTo = ref.watch(dateToFilterProvider);
  final dao = ref.watch(transactionDaoProvider);
  final accountDao = ref.watch(accountDaoProvider);
  final categoryDao = ref.watch(categoryDaoProvider);

  // Get all accounts and categories for search
  final accounts = await accountDao.getAllAccounts();
  final categories = await categoryDao.getAllCategories();
  
  // Create lookup maps
  final accountMap = {for (var a in accounts) a.id: a.name};
  final categoryMap = {for (var c in categories) c.id: c.name};

  await for (final transactions in dao.watchAllTransactions()) {
    print('🔄 filteredTransactionsProvider processing ${transactions.length} transactions');
    
    if (transactions.isEmpty) {
      yield [];
      continue;
    }

    final filtered = transactions.where((t) {
      // Filter by Type
      if (type != null && t.type != type) return false;

      // Filter by Date Range
      if (dateFrom != null) {
        final transactionDate = DateTime(t.date.year, t.date.month, t.date.day);
        final fromDate = DateTime(dateFrom.year, dateFrom.month, dateFrom.day);
        if (transactionDate.isBefore(fromDate)) return false;
      }
      
      if (dateTo != null) {
        final transactionDate = DateTime(t.date.year, t.date.month, t.date.day);
        final toDate = DateTime(dateTo.year, dateTo.month, dateTo.day);
        if (transactionDate.isAfter(toDate)) return false;
      }

      // Enhanced Search: title, account name, category name, notes, amount
      if (query.isNotEmpty) {
        final title = t.title?.toLowerCase() ?? '';
        final note = t.note?.toLowerCase() ?? '';
        final amount = t.amount.toString();
        final accountName = accountMap[t.accountId]?.toLowerCase() ?? '';
        final categoryName = t.categoryId != null ? (categoryMap[t.categoryId]?.toLowerCase() ?? '') : '';
        
        return title.contains(query) ||
               note.contains(query) ||
               amount.contains(query) ||
               accountName.contains(query) ||
               categoryName.contains(query);
      }
      
      return true;
    }).toList();
    
    print('✅ Filtered to ${filtered.length} transactions');
    yield filtered;
  }
});
