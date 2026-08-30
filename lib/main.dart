import 'package:flutter/material.dart';
import 'dart:html' as html; // 웹 백그라운드 브라우저 알림

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

// 1. 로그인 화면 (사번 + 성명 + 관리자 코드: ktngsj)
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
        const SnackBar(content: Text('사번과 이름을 모두 입력해주세요.')),
      );
      return;
    }

    if (_isAdminMode && _adminCodeController.text.trim() != correctAdminCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('관리자 인증 코드가 올바르지 않습니다.')),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MainScheduleScreen(
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
      backgroundColor: const Color(0xFFF3F6FA),
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
                const Icon(Icons.calendar_month_rounded, size: 56, color: Colors.blueAccent),
                const SizedBox(height: 12),
                const Text(
                  '근무 스케줄 관리',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _employeeIdController,
                  decoration: const InputDecoration(
                    labelText: '사번 (Employee ID)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '성명 (Name)',
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
                    backgroundColor: Colors.blueAccent,
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

// 2. 메인 스케줄 + 캘린더 화면
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
  String _notice = "📢 근무 및 휴가 신청은 사전 등록 바랍니다. 지난 날짜는 실제 근무/연장 확인용으로 기록 가능합니다.";
  bool _notificationEnabled = false;

  DateTime _currentMonth = DateTime.now();
  DateTime? _selectedDate;

  // 날짜별 일정 리스트
  final Map<String, List<String>> _scheduleMap = {};

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  String _formatDateKey(DateTime d) {
    return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
  }

  // 오늘 날짜인지/지난 날짜인지 판별 (시간 제외)
  bool _isPastDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return target.isBefore(today);
  }

  void _toggleNotification(bool enable) async {
    if (enable) {
      if (html.Notification.permission == 'granted') {
        setState(() => _notificationEnabled = true);
        _sendWebNotification("🔔 알림 설정 완료", "근무 등록 알림이 활성화되었습니다.");
      } else {
        final permission = await html.Notification.requestPermission();
        if (permission == 'granted') {
          setState(() => _notificationEnabled = true);
          _sendWebNotification("🔔 알림 설정 완료", "근무 등록 알림이 활성화되었습니다.");
        } else {
          setState(() => _notificationEnabled = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('브라우저 알림 권한이 차단되었습니다.')),
            );
          }
        }
      }
    } else {
      setState(() => _notificationEnabled = false);
    }
  }

  void _sendWebNotification(String title, String body) {
    if (html.Notification.permission == 'granted') {
      html.Notification(title, body: body, icon: 'icons/Icon-192.png');
    }
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
              setState(() => _notice = controller.text.trim());
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('공지사항이 수정되었습니다.')),
              );
            },
            child: const Text('저장'),
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

  // --- 1. 지난 날짜 근무/연장 확인용 기록 다이얼로그 ---
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
                    '⚠️ 지난 날짜는 사전 신청이 불가능하며, 실제 근무(오전/오후) 및 연장근무 기록용으로만 작성됩니다.',
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
                    labelText: '연장 근무 및 비고 확인용 메모',
                    hintText: '예: 연장근무 2시간 진행 (18:00~20:00) / 특이사항 없음',
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
                final entry = "[${widget.userName}(${widget.employeeId})] (실제기록) $shiftTime ${note.isNotEmpty ? ' | 연장/메모: $note' : ''}";

                setState(() {
                  _scheduleMap.putIfAbsent(dateKey, () => []).add(entry);
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

  // --- 2. 오늘 및 미래 날짜 신청 다이얼로그 (평일/주말) ---
  void _showAddWorkDialog() {
    if (_selectedDate == null) return;

    // 만약 지난 날짜라면 안내 후 지난 근무 기록창으로 연결
    if (_isPastDate(_selectedDate!)) {
      _showPastWorkRecordDialog();
      return;
    }

    final isWeekend = _selectedDate!.weekday == DateTime.saturday || _selectedDate!.weekday == DateTime.sunday;
    final dateKey = _formatDateKey(_selectedDate!);

    if (isWeekend) {
      // 주말 다이얼로그 (근무 가능 / 불가능)
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
                  final entry = "[${widget.userName}(${widget.employeeId})] 주말 $weekendOption ${weekendNoteController.text.isNotEmpty ? '(${weekendNoteController.text})' : ''}";
                  setState(() {
                    _scheduleMap.putIfAbsent(dateKey, () => []).add(entry);
                  });

                  if (_notificationEnabled) {
                    _sendWebNotification(
                      "⚡ 주말 근무 신청",
                      "${widget.userName}님이 $dateKey 주말 '$weekendOption'을 등록했습니다.",
                    );
                  }

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
      // 평일 다이얼로그 (연차, 체력단련, 가족사랑, 건강검진, 기타)
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
                      items: timeOptions.map((time) {
                        return DropdownMenuItem(value: time, child: Text(time));
                      }).toList(),
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

                  final entry = "[${widget.userName}(${widget.employeeId})] $details";

                  setState(() {
                    _scheduleMap.putIfAbsent(dateKey, () => []).add(entry);
                  });

                  if (_notificationEnabled) {
                    _sendWebNotification(
                      "⚡ 휴가/근무 신청 도착",
                      "${widget.userName}님이 $dateKey '$details'을 신청했습니다.",
                    );
                  }

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

  @override
  Widget build(BuildContext context) {
    final selectedKey = _selectedDate != null ? _formatDateKey(_selectedDate!) : '';
    final dayList = _scheduleMap[selectedKey] ?? [];
    final bool isPast = _selectedDate != null ? _isPastDate(_selectedDate!) : false;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.userName} (${widget.isAdmin ? "관리자" : "사원"})'),
        backgroundColor: widget.isAdmin ? Colors.indigo : Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
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
                            tooltip: '공지 수정 (관리자 전용)',
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

            // 관리자 전용 알림
            if (widget.isAdmin) ...[
              Card(
                color: Colors.blue.shade50,
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: SwitchListTile(
                  secondary: Icon(
                    _notificationEnabled ? Icons.notifications_active : Icons.notifications_off,
                    color: _notificationEnabled ? Colors.blueAccent : Colors.grey,
                  ),
                  title: const Text('근무 등록 백그라운드 알림', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('창을 닫거나 다른 작업을 해도 브라우저 팝업 알림 수신'),
                  value: _notificationEnabled,
                  onChanged: _toggleNotification,
                ),
              ),
              const SizedBox(height: 12),
            ],

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

            // 선택 날짜 상세 현황
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
                              '📅 $selectedKey 현황',
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
                        // 지난 날짜면 '지난 근무/연장 기록' 버튼, 오늘/미래면 '신청' 버튼
                        ElevatedButton.icon(
                          onPressed: isPast ? _showPastWorkRecordDialog : _showAddWorkDialog,
                          icon: Icon(isPast ? Icons.edit_calendar : Icons.add_task, size: 18),
                          label: Text(isPast ? '지난 근무/연장 확인 기록' : '근무/휴가 신청'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isPast ? Colors.blueGrey : Colors.blueAccent,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    if (dayList.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: Text('등록된 내역이 없습니다.', style: TextStyle(color: Colors.grey)),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: dayList.length,
                        itemBuilder: (ctx, idx) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: dayList[idx].contains("(실제기록)") ? Colors.blueGrey : Colors.blueAccent,
                            child: Icon(dayList[idx].contains("(실제기록)") ? Icons.history : Icons.event_note, color: Colors.white, size: 18),
                          ),
                          title: Text(dayList[idx], style: const TextStyle(fontWeight: FontWeight.w500)),
                        ),
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
              final hasData = (_scheduleMap[cellKey]?.isNotEmpty ?? false);
              final isPast = _isPastDate(cellDate);

              return InkWell(
                onTap: () => setState(() => _selectedDate = cellDate),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isPast ? Colors.blueGrey.withOpacity(0.2) : Colors.blueAccent.withOpacity(0.2))
                        : (isPast ? Colors.grey.shade100 : Colors.transparent),
                    border: isSelected
                        ? Border.all(color: isPast ? Colors.blueGrey : Colors.blueAccent, width: 1.5)
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
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isPast ? Colors.blueGrey : Colors.orange,
                            shape: BoxShape.circle,
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