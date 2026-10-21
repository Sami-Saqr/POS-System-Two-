import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';
import '../models/sale_models.dart';

class SalesRepository {
  Future<SaleResult> submitSale(SaleDraft draft) async {
    try {
      final response = await supabase
          .rpc('create_sale', params: {'p': draft.toJson()})
          .timeout(const Duration(seconds: 20));
      return SaleResult.fromJson(response as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } on SocketException catch (_) {
      throw Exception(
        'تعذر الاتصال بالإنترنت، لم يتم حفظ الفاتورة، حاول مرة أخرى',
      );
    } on TimeoutException catch (_) {
      throw Exception(
        'تعذر الاتصال بالإنترنت، لم يتم حفظ الفاتورة، حاول مرة أخرى',
      );
    } catch (e) {
      if (e.toString().contains('ClientException')) {
        throw Exception(
          'تعذر الاتصال بالإنترنت، لم يتم حفظ الفاتورة، حاول مرة أخرى',
        );
      }
      throw Exception('حدث خطأ أثناء حفظ الفاتورة');
    }
  }
}
