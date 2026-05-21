import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

extension ThemeColors on BuildContext {
  AppColors get appColors => Provider.of<ThemeProvider>(this, listen: false).colors;
  AppColors watchColors() => Provider.of<ThemeProvider>(this, listen: true).colors;
}
