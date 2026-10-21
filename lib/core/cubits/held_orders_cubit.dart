import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/held_order.dart';

class HeldOrdersCubit extends Cubit<List<HeldOrder>> {
  HeldOrdersCubit() : super([]);

  void holdOrder(HeldOrder order) {
    final newList = List<HeldOrder>.from(state)..add(order);
    emit(newList);
  }

  void removeOrder(String id) {
    final newList = List<HeldOrder>.from(state)..removeWhere((o) => o.id == id);
    emit(newList);
  }
}
