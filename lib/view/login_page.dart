import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'common/api_client.dart';
import 'common/app_config.dart';
import 'common/app_theme.dart';
import 'company/company_home_page.dart';
import 'store/store_home_page.dart';

// 로그인 화면: 본사 로그인 / 대리점 로그인 선택
// 본사/대리점 구분은 서버가 직원의 부서(e_team)로 검증하므로 맞지 않는 로그인은 거부됨
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _idController = TextEditingController();
  final _pwController = TextEditingController();
  bool _isStore = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // 태블릿 전용 앱이라 가로 화면으로 고정
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    AppConfig.load().catchError((_) {
      if (mounted) setState(() => _error = '앱 설정 파일(assets/app.env)을 불러오지 못했습니다.');
    });
  }

  @override
  void dispose() {
    _idController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final id = _idController.text.trim();
    final pw = _pwController.text;
    if (id.isEmpty || pw.isEmpty) {
      setState(() => _error = '아이디와 비밀번호를 입력해 주세요.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AppConfig.load();
      final res = await Api.postForm(
        _isStore ? '/employee/login/store' : '/employee/login/hq',
        {'e_id': id, 'password': pw},
      );
      Session.token = res['token'] as String;
      Session.kind = res['kind'] as String;
      Session.employee = Map<String, dynamic>.from(res['employee'] as Map);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => _isStore ? const StoreHomePage() : const CompanyHomePage(),
        ),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = '로그인 중 문제가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.theme,
      child: Scaffold(
        backgroundColor: AppColors.sidebar,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'FITPICK',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('Tablet Admin', style: TextStyle(color: AppColors.mint, fontSize: 14)),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(child: _tab('본사 로그인', !_isStore, () => _selectMode(false))),
                            const SizedBox(width: 10),
                            Expanded(child: _tab('대리점 로그인', _isStore, () => _selectMode(true))),
                          ],
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _idController,
                          enabled: !_loading,
                          decoration: const InputDecoration(
                            labelText: '직원 ID',
                            hintText: 'ex) DEV-001',
                            border: OutlineInputBorder(),
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _pwController,
                          enabled: !_loading,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: '비밀번호',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _login(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: const TextStyle(color: Color(0xFFB3261E), fontSize: 13)),
                        ],
                        const SizedBox(height: 22),
                        SizedBox(
                          height: 50,
                          child: FilledButton(
                            onPressed: _loading ? null : _login,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.sidebar,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(_isStore ? '대리점 로그인' : '본사 로그인'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _selectMode(bool isStore) {
    if (_loading) return;
    setState(() {
      _isStore = isStore;
      _error = null;
    });
  }

  Widget _tab(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.sidebar : AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.subText,
          ),
        ),
      ),
    );
  }
}
