import 'package:flutter/material.dart';
import '../../../../core/app_data/app_data_service.dart';

class LinearProgress extends StatelessWidget {
  const LinearProgress({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppDataService.instance.isRefreshing,
      builder: (context, isRefreshing, child) {
        return isRefreshing
            ? SizedBox(
          height: 2,
          child: LinearProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
            backgroundColor: Colors.transparent,
          ),
        )
            : const SizedBox(height: 0);
      },
    );
  }
}