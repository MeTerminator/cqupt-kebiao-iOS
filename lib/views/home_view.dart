import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/schedule_model.dart';
import '../view_models/schedule_view_model.dart';
import '../widgets/header_view.dart';
import '../widgets/schedule_grid.dart';
import '../widgets/course_detail_view.dart';
import '../widgets/user_detail_view.dart';
import '../widgets/toast_view.dart';
import 'login_view.dart';

class HomeView extends StatefulWidget {
  final ScheduleViewModel viewModel;

  const HomeView({super.key, required this.viewModel});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  CourseInstance? _selectedCourse;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.viewModel,
      child: Consumer<ScheduleViewModel>(
        builder: (context, viewModel, child) {
          return Stack(
            children: [
              Scaffold(
                body: Column(
                  children: [
                    HeaderView(
                      viewModel: viewModel,
                      onUserTap: () {
                        _showUserSheet(context, viewModel);
                      },
                    ),
                    Expanded(
                      child: PageView.builder(
                        itemCount: 21,
                        controller: PageController(
                          initialPage: viewModel.selectedWeek,
                        ),
                        onPageChanged: (index) {
                          viewModel.selectedWeek = index;
                          viewModel.notifyListeners();
                        },
                        itemBuilder: (context, index) {
                          return ScheduleGrid(
                            viewModel: viewModel,
                            weekToShow: index,
                            onCourseTap: (course) {
                              setState(() {
                                _selectedCourse = course;
                              });
                              _showCourseDetail(context, course, viewModel);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (viewModel.showToast)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedSlide(
                    offset: viewModel.showToast
                        ? Offset.zero
                        : const Offset(0, -1),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    child: Center(
                      child: ToastView(message: viewModel.toastMessage),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showCourseDetail(
    BuildContext context,
    CourseInstance course,
    ScheduleViewModel viewModel,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          CourseDetailView(course: course, viewModel: viewModel),
    );
  }

  void _showUserSheet(BuildContext context, ScheduleViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UserDetailView(
        viewModel: viewModel,
        onLogout: () {
          viewModel.currentId = '';
          viewModel.scheduleData = null;
          viewModel.notifyListeners();
        },
      ),
    );
  }
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final ScheduleViewModel _viewModel = ScheduleViewModel();
  String? _savedId;
  bool _isLoggedIn = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedId();
  }

  Future<void> _loadSavedId() async {
    final prefs = await _viewModel.loadCustomCourses();
    final savedId = await _getSavedId();
    setState(() {
      _savedId = savedId;
      _isLoggedIn = savedId != null && savedId.isNotEmpty;
      _isLoading = false;
    });

    if (_isLoggedIn && _savedId != null) {
      _viewModel.startup(_savedId!);
    }
  }

  Future<String?> _getSavedId() async {
    return null;
  }

  Future<void> _saveId(String id) async {}

  void _handleLogin(String id) {
    setState(() {
      _isLoggedIn = true;
      _savedId = id;
    });
    _saveId(id);
    _viewModel.startup(id);
  }

  void _handleLogout() {
    setState(() {
      _isLoggedIn = false;
      _savedId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromRGBO(0, 122, 89, 1),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromRGBO(0, 122, 89, 1),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        home: _isLoggedIn
            ? HomeView(viewModel: _viewModel)
            : LoginView(onLogin: _handleLogin),
      ),
    );
  }
}
