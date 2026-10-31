import 'package:flutter_bloc/flutter_bloc.dart';

class HomeCubit extends Cubit<int> {
  HomeCubit() : super(0);

  void selectTab(int index) {
    if (index >= 0 && index < 4) emit(index);
  }
}
