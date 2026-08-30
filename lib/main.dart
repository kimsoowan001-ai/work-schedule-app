import 'package:flutter/material.dart';
import 'dart:html' as html; // 웹 전용 알림 API 사용

void main() {
  runApp(const WorkScheduleApp());
}

class WorkScheduleApp extends StatelessWidget {
  const WorkScheduleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '근무 스케줄 관리',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

// 1. 로그인 화면
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _employeeIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _adminCodeController = TextEditingController();
  bool _isAdminMode = false;

  // 임시 관리자 비밀코드 (원하는 코드로 변경 가능)
  static const String correctAdminCode = "admin1234";

  void _login() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름을 입력해주세요.')),
      );
      return;
    }

    if (_isAdminMode && _adminCodeController.text != correctAdminCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('관리자 코드가 일치하지 않습니다.')),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MainDashboard(
          userName: _nameController.text.trim(),
          isAdmin: _isAdminMode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('근무 관리 시스템 로그인')),
      body: Center(
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '이름',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('관리자로 로그인'),
                value: _isAdminMode,
                onChanged: (val) => setState(() => _isAdminMode = val),
              ),
              if (_isAdminMode) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _adminCodeController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '관리자 인증 코드',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _login,
                  child: const Text('로그인', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 2. 메인 대시보드 (공지사항 및 알림 제어)
class MainDashboard extends StatefulWidget {
  final String userName;
  final bool isAdmin;

  const MainDashboard({super.key, required this.userName, required this.isAdmin});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  String _notice = "📢 등록된 공지사항이 없습니다.";
  bool _notificationEnabled = false;

  // 브라우저 백그라운드 푸시 알림 권한 요청 및 발송 함수
  void _requestNotificationPermission() async {
    if (html.Notification.permission == 'granted') {
      setState(() => _notificationEnabled = true);
      _sendWebNotification("알림 설정 완료", "관리자 근무 등록 알림이 활성화되었습니다.");
    } else {
      final permission = await html.Notification.requestPermission();
      if (permission == 'granted') {
        setState(() => _notificationEnabled = true);
        _sendWebNotification("알림 설정 완료", "새로운 근무 신청 시 알림을 받습니다.");
      } else {
        setState(() => _notificationEnabled = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('브라우저 알림 권한이 거부되었습니다.')),
          );
        }
      }
    }
  }

  void _sendWebNotification(String title, String body) {
    if (html.Notification.permission == 'granted') {
      html.Notification(title, body: body, icon: 'icons/Icon-192.png');
    }
  }

  // 공지사항 수정 다이얼로그 (관리자 전용)
  void _showEditNoticeDialog() {
    final controller = TextEditingController(text: _notice);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('공지사항 작성/수정 (관리자 전용)'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: '공지할 내용을 입력하세요.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _notice = controller.text);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('공지사항이 업데이트되었습니다.')),
              );
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  // 사용자가 근무 신청을 등록했을 때 실행되는 예시 함수
  void _simulateUserWorkRegistration() {
    // 실제 환경에서는 DB Stream/WebSocket으로 수신
    if (_notificationEnabled) {
      _sendWebNotification(
        "⚡ 새 근무 등록 알림",
        "${widget.userName}님이 새로운 근무 일정을 등록했습니다.",
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('근무 사항이 등록되었습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isAdmin ? '관리자 대시보드' : '근무자 대시보드'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // 공지사항 카드
            Card(
              color: Colors.amber.shade50,
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '📢 공지사항',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        // 관리자만 공지 수정 버튼 노출
                        if (widget.isAdmin)
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blueAccent),
                            tooltip: '공지사항 수정',
                            onPressed: _showEditNoticeDialog,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_notice, style: const TextStyle(fontSize: 15)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 관리자 전용 알림 수신 설정 스위치
            if (widget.isAdmin)
              Card(
                color: Colors.blue.shade50,
                child: SwitchListTile(
                  title: const Text(
                    '근무 등록 백그라운드 알림 받기',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('화면을 나가거나 최소화해도 팝업 알림을 수신합니다.'),
                  secondary: const Icon(Icons.notifications_active, color: Colors.blue),
                  value: _notificationEnabled,
                  onChanged: (val) {
                    if (val) {
                      _requestNotificationPermission();
                    } else {
                      setState(() => _notificationEnabled = false);
                    }
                  },
                ),
              ),

            const SizedBox(height: 24),
            // 근무 등록 액션 (시뮬레이션용)
            Center(
              child: ElevatedButton.icon(
                onPressed: _simulateUserWorkRegistration,
                icon: const Icon(Icons.send),
                label: const Text('근무 사항 등록/제출'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}