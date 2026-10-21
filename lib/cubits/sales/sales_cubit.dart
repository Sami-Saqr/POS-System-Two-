import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/sale_models.dart';
import '../../repositories/sales_repository.dart';

abstract class SalesState extends Equatable {
  const SalesState();

  @override
  List<Object?> get props => [];
}

class SalesInitial extends SalesState {}

class SalesSubmitting extends SalesState {}

class SalesSuccess extends SalesState {
  final SaleResult result;

  const SalesSuccess(this.result);

  @override
  List<Object?> get props => [result];
}

class SalesFailure extends SalesState {
  final String errorMessage;

  const SalesFailure(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}

class SalesCubit extends Cubit<SalesState> {
  final SalesRepository repository;
  String? _currentClientId;

  SalesCubit(this.repository) : super(SalesInitial());

  void submitSale(SaleDraft draft) async {
    _currentClientId ??= _generateUuidV4Formatted();

    final draftWithClientId = SaleDraft(
      clientId: _currentClientId!,
      branchId: draft.branchId,
      shift: draft.shift,
      paymentMethod: draft.paymentMethod,
      localNumber: draft.localNumber,
      discountAmount: draft.discountAmount,
      discountPercent: draft.discountPercent,
      vatRate: draft.vatRate,
      vatAmount: draft.vatAmount,
      total: draft.total,
      notes: draft.notes,
      items: draft.items,
    );

    emit(SalesSubmitting());
    try {
      final result = await repository.submitSale(draftWithClientId);
      _currentClientId = null; // Reset for next sale
      emit(SalesSuccess(result));
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      emit(SalesFailure(msg));
    }
  }

  void reset() {
    emit(SalesInitial());
  }

  String _generateUuidV4Formatted() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (i) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();
    return '${hex.sublist(0, 4).join()}-${hex.sublist(4, 6).join()}-${hex.sublist(6, 8).join()}-${hex.sublist(8, 10).join()}-${hex.sublist(10, 16).join()}';
  }
}
