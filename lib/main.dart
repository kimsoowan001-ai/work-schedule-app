import 'package:flutter/material.dart';
import 'dart:html' as html;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WorkScheduleApp());
}

class WorkScheduleApp extends StatelessWidget {
  const WorkScheduleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KT&G 근무 스케줄 관리',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B365D)),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

// 1. KT&G 인트로 화면
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(
              'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c5/KT%26G_Logo.svg/512px-KT%26G_Logo.svg.png',
              width: 200,
              errorBuilder: (context, error, stackTrace) => const Text(
                'KT&G',
                style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: 2, color: Color(0xFF333333)),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '근무 스케줄 관리 시스템',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B365D), letterSpacing: 1.2),
            ),
            const SizedBox(height: 36),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFFE35205)),
            ),
          ],
        ),
      ),
    );
  }
}

// 2. 로그인 화면 (관리자 비밀코드: ktngsj)
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

  static const String correctAdminCode = "ktngsj";

  void _login() {
    final empId = _employeeIdController.text.trim();
    final name = _nameController.text.trim();

    if (empId.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사번과 성명을 모두 입력해주세요.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    if (_isAdminMode && _adminCodeController.text.trim() != correctAdminCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('관리자 비밀코드가 올바르지 않습니다. (ktngsj)'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MainScheduleScreen(
          employeeId: empId,
          userName: name,
          isAdmin: _isAdminMode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(28.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Image.network(
                    'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c5/KT%26G_Logo.svg/512px-KT%26G_Logo.svg.png',
                    width: 140,
                    errorBuilder: (context, error, stackTrace) => const Text(
                      'KT&G',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '근무 스케줄 관리',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _employeeIdController,
                  decoration: const InputDecoration(
                    labelText: '사번 (Employee ID)',
                    hintText: '사번을 입력하세요',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '성명 (Name)',
                    hintText: '이름을 입력하세요',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('관리자 모드로 로그인', style: TextStyle(fontWeight: FontWeight.bold)),
                  value: _isAdminMode,
                  onChanged: (val) => setState(() => _isAdminMode = val),
                ),
                if (_isAdminMode) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _adminCodeController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '관리자 비밀코드',
                      hintText: 'ktngsj',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.security),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B365D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('로그인', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 3. 메인 스케줄 화면 (관리자는 전체 사원 내역 조회 가능)
class MainScheduleScreen extends StatefulWidget {
  final String employeeId;
  final String userName;
  final bool isAdmin;

  const MainScheduleScreen({
    super.key,
    required this.employeeId,
    required this.userName,
    required this.isAdmin,
  });

  @override
  State<MainScheduleScreen> createState() => _MainScheduleScreenState();
}

class _MainScheduleScreenState extends State<MainScheduleScreen> {
  String _notice = "📢 근무 및 휴가 신청은 사전 등록 바랍니다. 지난 날짜는 실제 근무(오전/오후) 및 연장 확인용으로 기록 가능합니다.";
  bool _notificationGranted = false;

  DateTime _currentMonth = DateTime.now();
  DateTime? _selectedDate;

  // 전체 공유 일정 저장소 (날짜 Key : List of entries)
  static final Map<String, List<Map<String, String>>> _globalScheduleMap = {};

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _safeCheckNotificationPermission();
  }

  void _safeCheckNotificationPermission() {
    try {
      if (html.Notification.permission == 'granted') {
        setState(() => _notificationGranted = true);
      }
    } catch (_) {}
  }

  void _requestNotificationExplicitly() async {
    try {
      final permission = await html.Notification.requestPermission();
      if (permission == 'granted') {
        setState(() => _notificationGranted = true);
        _sendWebNotification("🔔 알림 허용 완료", "새로운 공지사항 및 근무표 알림을 수신합니다.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('알림 권한이 허용되었습니다!')),
          );
        }
      } else {
        if (mounted) {
          _showPermissionHelpDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        _showPermissionHelpDialog();
      }
    }
  }

  void _showPermissionHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🔔 알림 권한 안내'),
        content: const Text(
          '브라우저 알림 권한을 확인해주세요.\n\n'
          '📌 PC: 주소창 왼쪽 설정 아이콘 ➔ 알림을 [허용]으로 변경\n'
          '📌 모바일: 브라우저 공유 버튼 ➔ [홈 화면에 추가] 후 실행해야 알림을 정상 수신할 수 있습니다.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('확인')),
        ],
      ),
    );
  }

  String _formatDateKey(DateTime d) {
    return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
  }

  bool _isPastDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return target.isBefore(today);
  }

  void _sendWebNotification(String title, String body) {
    try {
      if (html.Notification.permission == 'granted') {
        html.Notification(title, body: body, icon: 'icons/Icon-192.png');
      }
    } catch (_) {}
  }

  void _showEditNoticeDialog() {
    final controller = TextEditingController(text: _notice);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('📢 공지사항 작성/수정 (관리자 전용)'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: '공지할 내용을 작성하세요.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              final newNotice = controller.text.trim();
              setState(() => _notice = newNotice);
              Navigator.pop(ctx);

              _sendWebNotification(
                "📢 [KT&G 공지사항 등록]",
                newNotice.isNotEmpty ? newNotice : "새로운 공지사항이 등록되었습니다.",
              );

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('공지사항이 수정되었으며 알림이 발송되었습니다.')),
              );
            },
            child: const Text('저장 및 알림 전송'),
          ),
        ],
      ),
    );
  }

  List<String> _generateTimeOptions() {
    List<String> options = [];
    for (int i = 0; i <= 16; i++) {
      int hours = i ~/ 2;
      int minutes = (i % 2) * 30;
      if (hours == 0 && minutes == 0) {
        options.add("0시간 (0분)");
      } else if (minutes == 0) {
        options.add("$hours시간");
      } else if (hours == 0) {
        options.add("$minutes분");
      } else {
        options.add("$hours시간 $minutes분");
      }
    }
    return options;
  }

  void _showPastWorkRecordDialog() {
    if (_selectedDate == null) return;
    final dateKey = _formatDateKey(_selectedDate!);
    String shiftTime = "오전 근무";
    final overtimeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.history, color: Colors.blueGrey),
              const SizedBox(width: 8),
              Expanded(child: Text('지난 근무 확인 및 기록 ($dateKey)', style: const TextStyle(fontSize: 17))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '⚠️ 지난 날짜는 실제 근무(오전/오후) 및 연장근무 기록용으로 작성됩니다.',
                    style: TextStyle(fontSize: 12, color: Colors.brown),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: shiftTime,
                  decoration: const InputDecoration(
                    labelText: '근무 시간대 선택',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.access_time),
                  ),
                  items: const [
                    DropdownMenuItem(value: "오전 근무", child: Text("오전 근무")),
                    DropdownMenuItem(value: "오후 근무", child: Text("오후 근무")),
                    DropdownMenuItem(value: "종일/주간 근무", child: Text("종일/주간 근무")),
                    DropdownMenuItem(value: "야간 근무", child: Text("야간 근무")),
                    DropdownMenuItem(value: "휴무", child: Text("휴무")),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => shiftTime = val);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: overtimeController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '연장 근무 및 비고 메모',
                    hintText: '예: 연장근무 2시간 진행 (18:00~20:00)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit_note),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ElevatedButton(
              onPressed: () {
                final note = overtimeController.text.trim();
                final record = {
                  'empId': widget.employeeId,
                  'empName': widget.userName,
                  'type': '(실제기록)',
                  'content': '$shiftTime ${note.isNotEmpty ? ' | 연장/메모: $note' : ''}',
                };

                setState(() {
                  _globalScheduleMap.putIfAbsent(dateKey, () => []).add(record);
                });

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('지난 근무/연장 확인 기록이 저장되었습니다.')),
                );
              },
              child: const Text('기록 저장'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddWorkDialog() {
    if (_selectedDate == null) return;

    if (_isPastDate(_selectedDate!)) {
      _showPastWorkRecordDialog();
      return;
    }

    final isWeekend = _selectedDate!.weekday == DateTime.saturday || _selectedDate!.weekday == DateTime.sunday;
    final dateKey = _formatDateKey(_selectedDate!);

    if (isWeekend) {
      String weekendOption = "근무 가능";
      final weekendNoteController = TextEditingController();

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('주말 근무 설정 ($dateKey)'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: weekendOption,
                  decoration: const InputDecoration(labelText: '주말 근무 여부', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: "근무 가능", child: Text("근무 가능", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
                    DropdownMenuItem(value: "근무 불가능", child: Text("근무 불가능", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => weekendOption = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: weekendNoteController,
                  decoration: const InputDecoration(
                    labelText: '비고/메모 (선택)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
              ElevatedButton(
                onPressed: () {
                  final note = weekendNoteController.text.trim();
                  final record = {
                    'empId': widget.employeeId,
                    'empName': widget.userName,
                    'type': '주말설정',
                    'content': '주말 $weekendOption ${note.isNotEmpty ? '($note)' : ''}',
                  };

                  setState(() {
                    _globalScheduleMap.putIfAbsent(dateKey, () => []).add(record);
                  });

                  _sendWebNotification(
                    "⚡ 주말 근무 신청",
                    "${widget.userName}님이 $dateKey 주말 '$weekendOption'을 등록했습니다.",
                  );

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('주말 일정이 등록되었습니다.')),
                  );
                },
                child: const Text('등록'),
              ),
            ],
          ),
        ),
      );
    } else {
      String selectedCategory = "연차";
      String selectedLeaveTime = "8시간";
      final timeOptions = _generateTimeOptions();
      final customNoteController = TextEditingController();

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('근무/휴가 신청 ($dateKey)'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(labelText: '신청 항목', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: "연차", child: Text("연차")),
                      DropdownMenuItem(value: "체력단련", child: Text("체력단련")),
                      DropdownMenuItem(value: "가족사랑", child: Text("가족사랑")),
                      DropdownMenuItem(value: "건강검진", child: Text("건강검진")),
                      DropdownMenuItem(value: "기타", child: Text("기타")),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  if (selectedCategory == "연차") ...[
                    DropdownButtonFormField<String>(
                      value: selectedLeaveTime,
                      decoration: const InputDecoration(
                        labelText: '연차 사용 시간 (0분 ~ 8시간)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.timer_outlined),
                      ),
                      items: timeOptions.map((time) => DropdownMenuItem(value: time, child: Text(time))).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedLeaveTime = val);
                      },
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (selectedCategory == "기타") ...[
                    TextField(
                      controller: customNoteController,
                      decoration: const InputDecoration(
                        labelText: '기타 사유 입력 (필수)',
                        hintText: '사유를 구체적으로 입력하세요',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.edit_note),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (selectedCategory != "기타")
                    TextField(
                      controller: customNoteController,
                      decoration: const InputDecoration(
                        labelText: '비고/메모 (선택)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
              ElevatedButton(
                onPressed: () {
                  if (selectedCategory == "기타" && customNoteController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('기타 사유를 입력해주세요.')),
                    );
                    return;
                  }

                  String details = "";
                  if (selectedCategory == "연차") {
                    details = "연차 ($selectedLeaveTime)";
                  } else if (selectedCategory == "기타") {
                    details = "기타 (${customNoteController.text.trim()})";
                  } else {
                    details = selectedCategory;
                  }

                  if (selectedCategory != "기타" && customNoteController.text.trim().isNotEmpty) {
                    details += " - ${customNoteController.text.trim()}";
                  }

                  final record = {
                    'empId': widget.employeeId,
                    'empName': widget.userName,
                    'type': selectedCategory,
                    'content': details,
                  };

                  setState(() {
                    _globalScheduleMap.putIfAbsent(dateKey, () => []).add(record);
                  });

                  _sendWebNotification(
                    "⚡ 휴가/근무 신청 도착",
                    "${widget.userName}님이 $dateKey '$details'을 신청했습니다.",
                  );

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('신청이 완료되었습니다.')),
                  );
                },
                child: const Text('신청'),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _openAdminScheduleRegistrationScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => AdminRosterScreen(
          scheduleMap: _globalScheduleMap,
          onScheduleUpdated: () => setState(() {}),
          sendNotification: _sendWebNotification,
        ),
      ),
    );
  }

  // 관리자 전용 전체 사원 신청/근무 목록 조회 페이지 이동
  void _openAllEmployeesOverviewScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => AllEmployeesOverviewScreen(
          scheduleMap: _globalScheduleMap,
          onScheduleUpdated: () => setState(() {}),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedKey = _selectedDate != null ? _formatDateKey(_selectedDate!) : '';
    final rawList = _globalScheduleMap[selectedKey] ?? [];

    // [핵심 로직]: 관리자면 전체 리스트 노출, 일반 사원이면 본인 사번의 데이터만 필터링
    final displayList = widget.isAdmin
        ? rawList
        : rawList.where((item) => item['empId'] == widget.employeeId).toList();

    final bool isPast = _selectedDate != null ? _isPastDate(_selectedDate!) : false;

    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color: widget.isAdmin ? Colors.indigo : const Color(0xFF1B365D),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  widget.userName.isNotEmpty ? widget.userName[0] : 'U',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: widget.isAdmin ? Colors.indigo : const Color(0xFF1B365D)),
                ),
              ),
              accountName: Text('${widget.userName} (${widget.isAdmin ? "관리자" : "사원"})', style: const TextStyle(fontWeight: FontWeight.bold)),
              accountEmail: Text('사번: ${widget.employeeId}'),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month, color: Color(0xFF1B365D)),
              title: const Text('근무 캘린더 (메인)'),
              onTap: () => Navigator.pop(context),
            ),
            // 관리자 전용 메뉴 1: 전체 사원 근무표 등록
            if (widget.isAdmin)
              ListTile(
                leading: const Icon(Icons.edit_calendar, color: Colors.indigo),
                title: const Text('공식 근무표 배정/등록', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                subtitle: const Text('사원별 근무조 일괄 배정'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.pop(context);
                  _openAdminScheduleRegistrationScreen();
                },
              ),
            // 관리자 전용 메뉴 2: 전체 사원 근무 현황 집계표
            if (widget.isAdmin)
              ListTile(
                leading: const Icon(Icons.people_alt, color: Colors.teal),
                title: const Text('전체 사원 신청/근무 종합현황', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                subtitle: const Text('모든 사원의 신청 내역 통합 관리'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.pop(context);
                  _openAllEmployeesOverviewScreen();
                },
              ),
            ListTile(
              leading: const Icon(Icons.notifications_active, color: Colors.blueAccent),
              title: const Text('알림 권한 설정'),
              subtitle: Text(_notificationGranted ? '알림 활성화됨' : '알림 꺼짐 (클릭하여 켜기)'),
              onTap: () {
                Navigator.pop(context);
                _requestNotificationExplicitly();
              },
            ),
            ListTile(
              leading: const Icon(Icons.campaign, color: Colors.orange),
              title: const Text('공지사항 확인'),
              onTap: () {
                Navigator.pop(context);
                if (widget.isAdmin) {
                  _showEditNoticeDialog();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_notice)),
                  );
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('로그아웃', style: TextStyle(color: Colors.redAccent)),
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              ),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: Text('${widget.userName} (${widget.isAdmin ? "전체 관리자 모드" : "사원"})'),
        backgroundColor: widget.isAdmin ? Colors.indigo : const Color(0xFF1B365D),
        foregroundColor: Colors.white,
        actions: [
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.people_alt),
              tooltip: '전체 사원 종합 현황표',
              onPressed: _openAllEmployeesOverviewScreen,
            ),
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.post_add),
              tooltip: '근무표 등록 바로가기',
              onPressed: _openAdminScheduleRegistrationScreen,
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 공지사항 카드
            Card(
              color: Colors.amber.shade50,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.campaign, color: Colors.orange, size: 24),
                            SizedBox(width: 8),
                            Text('공지사항', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        if (widget.isAdmin)
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blueAccent),
                            tooltip: '공지 수정 및 알림 발송 (관리자 전용)',
                            onPressed: _showEditNoticeDialog,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(_notice, style: const TextStyle(fontSize: 14, height: 1.4)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 월 이동 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() {
                    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
                  }),
                ),
                Text(
                  '${_currentMonth.year}년 ${_currentMonth.month}월',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() {
                    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 캘린더 그리드
            _buildCalendarGrid(),

            const SizedBox(height: 16),

            // 상세 현황 카드 (관리자: 전체 사원 내역 / 일반: 본인 내역)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.isAdmin ? '👥 $selectedKey 전체 사원 근무 현황' : '📅 $selectedKey 내 신청 내역',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            if (isPast)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('지난 날짜', style: TextStyle(fontSize: 11, color: Colors.black54)),
                              ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: isPast ? _showPastWorkRecordDialog : _showAddWorkDialog,
                          icon: Icon(isPast ? Icons.edit_calendar : Icons.add_task, size: 18),
                          label: Text(isPast ? '지난 근무 기록' : '근무/휴가 신청'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isPast ? Colors.blueGrey : (widget.isAdmin ? Colors.indigo : const Color(0xFF1B365D)),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    if (displayList.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: Text(
                            widget.isAdmin ? '해당 날짜에 등록된 전체 사원 내역이 없습니다.' : '해당 날짜에 등록된 내 근무 일정이 없습니다.',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: displayList.length,
                        itemBuilder: (ctx, idx) {
                          final item = displayList[idx];
                          final isOfficial = item['type'] == '공식근무';
                          final isActual = item['type'] == '(실제기록)';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isOfficial ? Colors.indigo.shade50 : (isActual ? Colors.grey.shade100 : Colors.blue.shade50),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isOfficial ? Colors.indigo : (isActual ? Colors.blueGrey : const Color(0xFF1B365D)),
                                child: Icon(
                                  isOfficial ? Icons.assignment_turned_in : (isActual ? Icons.history : Icons.event_available),
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                '[${item['empName']}(${item['empId']})] ${item['content']}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              subtitle: Text(
                                '구분: ${item['type']}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                              trailing: widget.isAdmin
                                  ? IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                      tooltip: '관리자 삭제',
                                      onPressed: () {
                                        setState(() {
                                          _globalScheduleMap[selectedKey]?.remove(item);
                                        });
                                      },
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final startWeekday = firstDayOfMonth.weekday % 7;

    final weekLabels = ['일', '월', '화', '수', '목', '금', '토'];

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekLabels.map((w) {
              return Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: w == '일' ? Colors.red : (w == '토' ? Colors.blue : Colors.black87),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const Divider(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.1,
            ),
            itemCount: startWeekday + daysInMonth,
            itemBuilder: (context, index) {
              if (index < startWeekday) {
                return const SizedBox.shrink();
              }
              final dayNum = index - startWeekday + 1;
              final cellDate = DateTime(_currentMonth.year, _currentMonth.month, dayNum);
              final cellKey = _formatDateKey(cellDate);
              final isSelected = _selectedDate != null &&
                  _selectedDate!.year == cellDate.year &&
                  _selectedDate!.month == cellDate.month &&
                  _selectedDate!.day == cellDate.day;

              final allList = _globalScheduleMap[cellKey] ?? [];
              final filteredList = widget.isAdmin
                  ? allList
                  : allList.where((item) => item['empId'] == widget.employeeId).toList();

              final hasData = filteredList.isNotEmpty;
              final isPast = _isPastDate(cellDate);

              return InkWell(
                onTap: () => setState(() => _selectedDate = cellDate),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isPast ? Colors.blueGrey.withOpacity(0.2) : const Color(0xFF1B365D).withOpacity(0.15))
                        : (isPast ? Colors.grey.shade100 : Colors.transparent),
                    border: isSelected
                        ? Border.all(color: isPast ? Colors.blueGrey : (widget.isAdmin ? Colors.indigo : const Color(0xFF1B365D)), width: 1.5)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNum',
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isPast
                              ? Colors.grey.shade500
                              : (cellDate.weekday == 7 ? Colors.red : (cellDate.weekday == 6 ? Colors.blue : Colors.black87)),
                        ),
                      ),
                      if (hasData)
                        Container(
                          margin: const EdgeInsets.only(top: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: widget.isAdmin ? Colors.indigo : const Color(0xFFE35205),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            widget.isAdmin ? '${filteredList.length}건' : '●',
                            style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// 4. [관리자 전용] 전체 사원 종합 현황표 (모든 날짜, 모든 사원의 근무/신청 내역 요약)
class AllEmployeesOverviewScreen extends StatefulWidget {
  final Map<String, List<Map<String, String>>> scheduleMap;
  final VoidCallback onScheduleUpdated;

  const AllEmployeesOverviewScreen({
    super.key,
    required this.scheduleMap,
    required this.onScheduleUpdated,
  });

  @override
  State<AllEmployeesOverviewScreen> createState() => _AllEmployeesOverviewScreenState();
}

class _AllEmployeesOverviewScreenState extends State<AllEmployeesOverviewScreen> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    // 모든 날짜의 데이터를 리스트로 펼치기
    List<Map<String, String>> flattenedList = [];
    widget.scheduleMap.forEach((date, items) {
      for (var item in items) {
        flattenedList.add({
          'date': date,
          'empId': item['empId'] ?? '',
          'empName': item['empName'] ?? '',
          'type': item['type'] ?? '',
          'content': item['content'] ?? '',
        });
      }
    });

    // 날짜 기준 내림차순 정렬
    flattenedList.sort((a, b) => b['date']!.compareTo(a['date']!));

    // 검색 필터 적용 (성명 또는 사번)
    if (_searchQuery.isNotEmpty) {
      flattenedList = flattenedList.where((item) =>
          item['empName']!.contains(_searchQuery) ||
          item['empId']!.contains(_searchQuery) ||
          item['date']!.contains(_searchQuery) ||
          item['content']!.contains(_searchQuery)).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('👥 전체 사원 근무/신청 종합 현황'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 상단 검색창
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.white,
            child: TextField(
              decoration: InputDecoration(
                hintText: '사원명, 사번, 날짜, 신청 항목 검색...',
                prefixIcon: const Icon(Icons.search, color: Colors.teal),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
          ),
          const Divider(height: 1),
          // 종합 리스트
          Expanded(
            child: flattenedList.isEmpty
                ? const Center(child: Text('등록된 근무/신청 내역이 없습니다.', style: TextStyle(color: Colors.grey, fontSize: 16)))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: flattenedList.length,
                    itemBuilder: (ctx, idx) {
                      final item = flattenedList[idx];
                      return Card(
                        elevation: 1.5,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: item['type'] == '공식근무'
                                ? Colors.indigo
                                : (item['type'] == '(실제기록)' ? Colors.blueGrey : Colors.teal),
                            child: Text(
                              item['empName']!.isNotEmpty ? item['empName']![0] : 'U',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(item['date']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.indigo)),
                              const SizedBox(width: 8),
                              Text('${item['empName']} (${item['empId']})', style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text('${item['content']}', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            tooltip: '삭제',
                            onPressed: () {
                              setState(() {
                                final date = item['date']!;
                                widget.scheduleMap[date]?.removeWhere((element) =>
                                    element['empId'] == item['empId'] &&
                                    element['content'] == item['content']);
                              });
                              widget.onScheduleUpdated();
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// 5. [관리자 전용] 공식 근무표 배정 화면
class AdminRosterScreen extends StatefulWidget {
  final Map<String, List<Map<String, String>>> scheduleMap;
  final VoidCallback onScheduleUpdated;
  final Function(String title, String body) sendNotification;

  const AdminRosterScreen({
    super.key,
    required this.scheduleMap,
    required this.onScheduleUpdated,
    required this.sendNotification,
  });

  @override
  State<AdminRosterScreen> createState() => _AdminRosterScreenState();
}

class _AdminRosterScreenState extends State<AdminRosterScreen> {
  final _empIdController = TextEditingController();
  final _empNameController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _shiftType = "주간 근무 (09:00 - 18:00)";

  final List<String> _shiftOptions = [
    "주간 근무 (09:00 - 18:00)",
    "오전 근무 (09:00 - 14:00)",
    "오후 근무 (14:00 - 19:00)",
    "야간 근무 (18:00 - 09:00)",
    "주말 당직 근무",
    "휴무 (OFF)",
    "연차 / 지정 휴가",
  ];

  String _formatDate(DateTime d) {
    return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
  }

  void _submitRoster() {
    final empId = _empIdController.text.trim();
    final empName = _empNameController.text.trim();
    final note = _noteController.text.trim();

    if (empId.isEmpty || empName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사번과 사원명을 입력해주세요.')),
      );
      return;
    }

    final dateKey = _formatDate(_selectedDate);
    final record = {
      'empId': empId,
      'empName': empName,
      'type': '공식근무',
      'content': '$_shiftType ${note.isNotEmpty ? '($note)' : ''}',
    };

    setState(() {
      widget.scheduleMap.putIfAbsent(dateKey, () => []).add(record);
    });
    widget.onScheduleUpdated();

    widget.sendNotification(
      "📋 [공식 근무표 배정 알림]",
      "$dateKey $empName님의 공식 근무($_shiftType)가 등록되었습니다.",
    );

    _empIdController.clear();
    _empNameController.clear();
    _noteController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('근무표가 등록되었으며 전체 캘린더에 반영되었습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateKey = _formatDate(_selectedDate);
    final currentList = widget.scheduleMap[dateKey] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('공식 근무표 배정/등록 (관리자)'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '➕ 공식 근무표 배정 등록',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      leading: const Icon(Icons.event, color: Colors.indigo),
                      title: Text('배정 날짜: $dateKey', style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: const Text('날짜 변경', style: TextStyle(color: Colors.blueAccent)),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2025),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _empIdController,
                            decoration: const InputDecoration(
                              labelText: '사번 (ID)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _empNameController,
                            decoration: const InputDecoration(
                              labelText: '성명',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _shiftType,
                      decoration: const InputDecoration(
                        labelText: '근무 구분 / 시간',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      items: _shiftOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _shiftType = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        labelText: '비고 / 전달사항 (선택)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.note),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _submitRoster,
                      icon: const Icon(Icons.save),
                      label: const Text('근무표 등록 및 캘린더 반영', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📋 $dateKey 배정 내역 (${currentList.length}건)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const Divider(height: 20),
                    if (currentList.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: Text('해당 날짜에 배정된 근무표가 없습니다.', style: TextStyle(color: Colors.grey))),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: currentList.length,
                        itemBuilder: (ctx, idx) {
                          final item = currentList[idx];
                          return ListTile(
                            leading: const Icon(Icons.check_circle, color: Colors.indigo),
                            title: Text('[${item['empName']}(${item['empId']})] ${item['content']}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              tooltip: '삭제',
                              onPressed: () {
                                setState(() {
                                  currentList.removeAt(idx);
                                });
                                widget.onScheduleUpdated();
                              },
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}