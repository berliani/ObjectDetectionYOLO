import 'package:get/get.dart';
import 'package:yolodetection/app/modules/home/views/landing_page_view.dart';
import '../modules/home/bindings/home_binding.dart';


part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = Routes.HOME;

  static final routes = [
    GetPage(
      name: _Paths.HOME,
      page: () =>  LandingPage(),
      binding: HomeBinding(),
    ),
  ];
}
