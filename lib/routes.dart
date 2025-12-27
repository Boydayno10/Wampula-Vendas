import 'package:flutter/material.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/welcome/welcome_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/otp_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/profile/edit_profile_screen.dart';

class Routes {
  static const splash = '/';
  static const welcome = '/welcome';
  static const login = '/login';
  static const otp = '/otp';
  static const home = '/home';
  static const editProfile = '/edit-profile';
}

final Map<String, WidgetBuilder> appRoutes = {
  Routes.splash: (_) => const SplashScreen(),
  Routes.welcome: (_) => const WelcomeScreen(),
  Routes.login: (_) => const LoginScreen(),
  Routes.otp: (_) => const OtpScreen(),
  Routes.home: (_) => const HomeScreen(),
  Routes.editProfile: (_) => const EditProfileScreen(),
};
