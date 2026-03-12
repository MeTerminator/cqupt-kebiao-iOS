import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LoginView extends StatefulWidget {
  final Function(String) onLogin;

  const LoginView({super.key, required this.onLogin});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController _idController = TextEditingController();

  Color get schoolGreen => const Color.fromRGBO(0, 122, 89, 1);
  bool get isValidId =>
      _idController.text.length == 10 &&
      _idController.text.replaceAll(RegExp(r'[0-9]'), '').isEmpty;

  @override
  void initState() {
    super.initState();
    _idController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputBgColor = isDark ? Colors.grey[850] : Colors.grey[200];

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              const SizedBox(height: 80),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: schoolGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.calendar_today_rounded,
                  size: 60,
                  color: schoolGreen,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                '重邮课表',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 60),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '学号登录',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: inputBgColor,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: TextField(
                  controller: _idController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: InputDecoration(
                    hintText: '请输入10位学号',
                    prefixIcon: Icon(Icons.person_outline, color: schoolGreen),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
              if (_idController.text.isNotEmpty && !isValidId)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '学号应为10位数字',
                      style: TextStyle(fontSize: 12, color: Colors.red[400]),
                    ),
                  ),
                ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: isValidId
                      ? () {
                          HapticFeedback.mediumImpact();
                          widget.onLogin(_idController.text);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isValidId ? schoolGreen : Colors.grey[400],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: isValidId ? 5 : 0,
                    shadowColor: isValidId
                        ? schoolGreen.withOpacity(0.3)
                        : Colors.transparent,
                  ),
                  child: const Text(
                    '进入课表',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
