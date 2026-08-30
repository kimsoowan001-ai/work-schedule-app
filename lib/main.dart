import 'dart:convert';
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

// 1. KT&G 스플래시 인트로 화면
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () {
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
                style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: Color(0xFF333333)),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '근무 스케줄 관리 시스템',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B365D), letterSpacing: 1.2),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 30,
              height: 30,
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

  @override
  void initState() {
    super.initState();
    try {
      final savedEmpId = html.window.localStorage['last_emp_id'] ?? '';
      final savedName = html.window.localStorage['last_name'] ?? '';
      if (savedEmpId.isNotEmpty) _employeeIdController.text = savedEmpId;
      if (savedName.isNotEmpty) _nameController.text = savedName;
    } catch (_) {}
  }

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

    try {
      html.window.localStorage['last_emp_id'] = empId;
      html.window.localStorage['last_name'] = name;
    } catch (_) {}

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
                BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4)),
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

// 3. 메인 스케줄 화면
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
  String _notice = "📢 당일 기준 2주(14일) 이내 변경/신청/삭제는 관리자 승인이 필요하며, 2주 이후 일정은 자유롭게 신청/삭제 가능합니다.";
  bool _notificationGranted = false;

  String? _rosterImageBase64;
  String? _rosterUploadTime;

  DateTime _currentMonth = DateTime.now();
  DateTime? _selectedDate;

  static Map<String, List<Map<String, String>>> _globalScheduleMap = {};
  static List<Map<String, String>> _approvalRequests = [];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadStoredData();
    _safeCheckNotificationPermission();
  }

  void _loadStoredData() {
    try {
      final savedNotice = html.window.localStorage['ktng_notice'];
      if (savedNotice != null && savedNotice.isNotEmpty) _notice = savedNotice;

      _rosterImageBase64 = html.window.localStorage['ktng_roster_image'];
      _rosterUploadTime = html.window.localStorage['ktng_roster_time'];

      final savedData = html.window.localStorage['ktng_schedule_data'];
      if (savedData != null && savedData.isNotEmpty) {
        final decoded = jsonDecode(savedData) as Map<String, dynamic>;
        _globalScheduleMap = decoded.map((key, value) {
          final list = (value as List).map((item) => Map<String, String>.from(item as Map)).toList();
          final Map<String, Map<String, String>> uniqueByEmp = {};
          for (var entry in list) {
            final emp = entry['empId'] ?? '';
            uniqueByEmp[emp] = entry;
          }
          return MapEntry(key, uniqueByEmp.values.toList());
        });
      }

      final savedApproval = html.window.localStorage['ktng_approval_data'];
      if (savedApproval != null && savedApproval.isNotEmpty) {
        final decodedApp = jsonDecode(savedApproval) as List;
        _approvalRequests = decodedApp.map((item) => Map<String, String>.from(item as Map)).toList();
      }

      setState(() {});
    } catch (e) {
      debugPrint("데이터 로드 오류: $e");
    }
  }

  static void saveAllData() {
    try {
      html.window.localStorage['ktng_schedule_data'] = jsonEncode(_globalScheduleMap);
      html.window.localStorage['ktng_approval_data'] = jsonEncode(_approvalRequests);
    } catch (e) {
      debugPrint("데이터 저장 오류: $e");
    }
  }

  void _saveNotice(String newNotice) {
    try {
      html.window.localStorage['ktng_notice'] = newNotice;
    } catch (_) {}
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
      }
    } catch (_) {}
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

  bool _isWithinTwoWeeks(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;
    return diff >= 0 && diff <= 14;
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
              _saveNotice(newNotice);
              Navigator.pop(ctx);

              _sendWebNotification("📢 [KT&G 공지사항]", newNotice);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('공지사항이 수정 및 저장되었습니다.')),
              );
            },
            child: const Text('저장 및 알림 전송'),
          ),
        ],
      ),
    );
  }

  void _openRosterImageScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => RosterImageScreen(
          isAdmin: widget.isAdmin,
          currentImageBase64: _rosterImageBase64,
          uploadTime: _rosterUploadTime,
          onImageUploaded: (newImageBase64, timeStr) {
            setState(() {
              _rosterImageBase64 = newImageBase64;
              _rosterUploadTime = timeStr;
            });
            _sendWebNotification("📸 [새 근무표 등록]", "새로운 근무표 사진이 등록되었습니다.");
          },
        ),
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

  void _handleDeleteItem(String dateKey, Map<String, String> item, bool isWithin2Weeks) {
    if (widget.isAdmin) {
      setState(() {
        _globalScheduleMap[dateKey]?.remove(item);
      });
      saveAllData();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('일정이 삭제되었습니다.')));
      return;
    }

    if (!isWithin2Weeks) {
      setState(() {
        _globalScheduleMap[dateKey]?.remove(item);
      });
      saveAllData();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('2주 이후 일정이 즉시 삭제되었습니다.')));
    } else {
      final deleteReasonController = TextEditingController();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('🔒 2주 이내 일정 삭제 승인 요청'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('당일 기준 2주 이내 일정의 취소/삭제는 관리자 승인이 필요합니다.', style: TextStyle(fontSize: 13, color: Colors.deepOrange)),
              const SizedBox(height: 12),
              Text('삭제 대상: ${item['content']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 14),
              TextField(
                controller: deleteReasonController,
                decoration: const InputDecoration(
                  labelText: '삭제/취소 사유 (필수)',
                  hintText: '취소 사유를 입력해주세요',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
              onPressed: () {
                if (deleteReasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('삭제 사유를 입력해주세요.')));
                  return;
                }

                _approvalRequests.removeWhere((r) => r['date'] == dateKey && r['empId'] == widget.employeeId);

                final req = {
                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                  'actionType': '삭제요청',
                  'date': dateKey,
                  'empId': widget.employeeId,
                  'empName': widget.userName,
                  'type': item['type'] ?? '삭제',
                  'content': item['content'] ?? '',
                  'reason': deleteReasonController.text.trim(),
                  'requestTime': DateTime.now().toString().substring(0, 16),
                };

                setState(() {
                  _approvalRequests.add(req);
                });
                saveAllData();

                _sendWebNotification("⚡ [삭제 승인 요청]", "${widget.userName}님이 $dateKey 일정 삭제를 승인 요청했습니다.");

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('관리자에게 삭제 승인 요청이 전송되었습니다.')),
                );
              },
              child: const Text('삭제 승인 요청'),
            ),
          ],
        ),
      );
    }
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
          title: Text('지난 근무 확인 및 기록 ($dateKey)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('⚠️ 지난 날짜는 실제 근무(오전/오후) 및 연장근무 기록용으로 작성됩니다.',
                    style: TextStyle(fontSize: 12, color: Colors.brown)),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: shiftTime,
                  decoration: const InputDecoration(labelText: '근무 시간대 선택', border: OutlineInputBorder()),
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
                const SizedBox(height: 14),
                TextField(
                  controller: overtimeController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '연장 근무 및 비고 메모',
                    hintText: '예: 연장근무 2시간 진행 (18:00~20:00)',
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
                final note = overtimeController.text.trim();
                final record = {
                  'empId': widget.employeeId,
                  'empName': widget.userName,
                  'type': '(실제기록)',
                  'content': '$shiftTime ${note.isNotEmpty ? ' | 연장/메모: $note' : ''}',
                };

                setState(() {
                  _globalScheduleMap.putIfAbsent(dateKey, () => []).removeWhere((item) => item['empId'] == widget.employeeId);
                  _globalScheduleMap[dateKey]!.add(record);
                });
                saveAllData();

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('지난 근무 기록이 저장되었습니다.')),
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
    final bool isWithin2Weeks = _isWithinTwoWeeks(_selectedDate!);
    final bool requiresApproval = !widget.isAdmin && isWithin2Weeks;

    final approvalReasonController = TextEditingController();

    if (isWeekend) {
      String weekendOption = "근무 가능";
      final weekendNoteController = TextEditingController();

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('주말 근무 설정 ($dateKey)'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (requiresApproval)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                      child: const Row(
                        children: [
                          Icon(Icons.lock_clock, color: Colors.deepOrange, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '🔒 당일 기준 2주 이내 날짜입니다.\n관리자의 승인이 완료된 후 최종 등록됩니다.',
                              style: TextStyle(fontSize: 12, color: Colors.deepOrange, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '🔓 2주 이후 날짜는 승인 없이 즉시 등록 및 삭제가 가능합니다.',
                              style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                    decoration: const InputDecoration(labelText: '비고/메모 (선택)', border: OutlineInputBorder()),
                  ),
                  if (requiresApproval) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: approvalReasonController,
                      decoration: const InputDecoration(
                        labelText: '2주 이내 변경/신청 사유 (필수)',
                        hintText: '사유를 구체적으로 입력하세요',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.rate_review, color: Colors.deepOrange),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: requiresApproval ? Colors.deepOrange : const Color(0xFF1B365D)),
                onPressed: () {
                  if (requiresApproval && approvalReasonController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('2주 이내 긴급 신청 사유를 입력해주세요.')),
                    );
                    return;
                  }

                  final note = weekendNoteController.text.trim();
                  final contentStr = '주말 $weekendOption ${note.isNotEmpty ? '($note)' : ''}';

                  if (requiresApproval) {
                    _approvalRequests.removeWhere((r) => r['date'] == dateKey && r['empId'] == widget.employeeId);

                    final req = {
                      'id': DateTime.now().millisecondsSinceEpoch.toString(),
                      'actionType': '신청요청',
                      'date': dateKey,
                      'empId': widget.employeeId,
                      'empName': widget.userName,
                      'type': '주말설정',
                      'content': contentStr,
                      'reason': approvalReasonController.text.trim(),
                      'requestTime': DateTime.now().toString().substring(0, 16),
                    };
                    setState(() {
                      _approvalRequests.add(req);
                    });
                    saveAllData();

                    _sendWebNotification("⚡ [승인 요청] 2주 이내 주말 근무", "${widget.userName}님이 $dateKey 주말 설정을 승인 요청했습니다.");

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('관리자에게 승인 요청이 전송되었습니다. 승인 후 캘린더에 반영됩니다.')),
                    );
                  } else {
                    final record = {
                      'empId': widget.employeeId,
                      'empName': widget.userName,
                      'type': '주말설정',
                      'content': contentStr,
                    };
                    setState(() {
                      _globalScheduleMap.putIfAbsent(dateKey, () => []).removeWhere((item) => item['empId'] == widget.employeeId);
                      _globalScheduleMap[dateKey]!.add(record);
                    });
                    saveAllData();

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('주말 일정이 정상 등록되었습니다.')),
                    );
                  }
                },
                child: Text(requiresApproval ? '승인 요청' : '즉시 등록', style: const TextStyle(color: Colors.white)),
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
                  if (requiresApproval)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                      child: const Row(
                        children: [
                          Icon(Icons.lock_clock, color: Colors.deepOrange, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '🔒 당일 기준 2주 이내 날짜입니다.\n관리자의 승인이 완료된 후 최종 등록됩니다.',
                              style: TextStyle(fontSize: 12, color: Colors.deepOrange, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '🔓 2주 이후 날짜는 승인 없이 즉시 등록 및 삭제가 가능합니다.',
                              style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                      decoration: const InputDecoration(labelText: '비고/메모 (선택)', border: OutlineInputBorder()),
                    ),
                  if (requiresApproval) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: approvalReasonController,
                      decoration: const InputDecoration(
                        labelText: '2주 이내 긴급 신청 사유 (필수)',
                        hintText: '사유를 작성해주세요',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.rate_review, color: Colors.deepOrange),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: requiresApproval ? Colors.deepOrange : const Color(0xFF1B365D)),
                onPressed: () {
                  if (selectedCategory == "기타" && customNoteController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('기타 사유를 입력해주세요.')));
                    return;
                  }
                  if (requiresApproval && approvalReasonController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('2주 이내 긴급 사유를 입력해주세요.')));
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

                  if (requiresApproval) {
                    _approvalRequests.removeWhere((r) => r['date'] == dateKey && r['empId'] == widget.employeeId);

                    final req = {
                      'id': DateTime.now().millisecondsSinceEpoch.toString(),
                      'actionType': '신청요청',
                      'date': dateKey,
                      'empId': widget.employeeId,
                      'empName': widget.userName,
                      'type': selectedCategory,
                      'content': details,
                      'reason': approvalReasonController.text.trim(),
                      'requestTime': DateTime.now().toString().substring(0, 16),
                    };
                    setState(() {
                      _approvalRequests.add(req);
                    });
                    saveAllData();

                    _sendWebNotification("⚡ [승인 요청] 2주 이내 휴가/근무", "${widget.userName}님이 $dateKey '$details' 건에 대한 승인을 요청했습니다.");

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('관리자에게 승인 요청이 전송되었습니다. 관리자 승인 후 캘린더에 표시됩니다.')),
                    );
                  } else {
                    final record = {
                      'empId': widget.employeeId,
                      'empName': widget.userName,
                      'type': selectedCategory,
                      'content': details,
                    };
                    setState(() {
                      _globalScheduleMap.putIfAbsent(dateKey, () => []).removeWhere((item) => item['empId'] == widget.employeeId);
                      _globalScheduleMap[dateKey]!.add(record);
                    });
                    saveAllData();

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('신청이 정상 등록되었습니다.')),
                    );
                  }
                },
                child: Text(requiresApproval ? '승인 요청' : '즉시 신청', style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _openApprovalManagementScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => AdminApprovalScreen(
          approvalRequests: _approvalRequests,
          scheduleMap: _globalScheduleMap,
          onUpdated: () {
            setState(() {});
            saveAllData();
          },
          sendNotification: _sendWebNotification,
        ),
      ),
    );
  }

  void _openAllEmployeesOverviewScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => AllEmployeesOverviewScreen(
          scheduleMap: _globalScheduleMap,
          onScheduleUpdated: () {
            setState(() {});
            saveAllData();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedKey = _selectedDate != null ? _formatDateKey(_selectedDate!) : '';
    final rawList = _globalScheduleMap[selectedKey] ?? [];

    final displayList = widget.isAdmin
        ? rawList
        : rawList.where((item) => item['empId'] == widget.employeeId).toList();

    final myPendingList = _approvalRequests
        .where((req) => req['date'] == selectedKey && (widget.isAdmin || req['empId'] == widget.employeeId))
        .toList();

    final bool isPast = _selectedDate != null ? _isPastDate(_selectedDate!) : false;
    final bool isWithin2Weeks = _selectedDate != null && _isWithinTwoWeeks(_selectedDate!);

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
            if (widget.isAdmin)
              ListTile(
                leading: const Icon(Icons.assignment_turned_in, color: Colors.deepOrange),
                title: const Text('긴급 신청/삭제 결재함', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                subtitle: Text('승인 대기 요청: ${_approvalRequests.length}건'),
                trailing: _approvalRequests.isNotEmpty
                    ? CircleAvatar(radius: 12, backgroundColor: Colors.red, child: Text('${_approvalRequests.length}', style: const TextStyle(fontSize: 11, color: Colors.white)))
                    : const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.pop(context);
                  _openApprovalManagementScreen();
                },
              ),
            ListTile(
              leading: const Icon(Icons.image, color: Colors.indigo),
              title: Text(widget.isAdmin ? '근무표 사진 등록/관리' : '이달의 근무표 사진 보기',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
              subtitle: Text(widget.isAdmin ? '근무표 이미지 업로드' : '등록된 근무표 사진 확인'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {
                Navigator.pop(context);
                _openRosterImageScreen();
              },
            ),
            if (widget.isAdmin)
              ListTile(
                leading: const Icon(Icons.people_alt, color: Colors.teal),
                title: const Text('전체 사원 신청 종합현황', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
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
        title: Text('${widget.userName} (${widget.isAdmin ? "관리자 모드" : "사원"})'),
        backgroundColor: widget.isAdmin ? Colors.indigo : const Color(0xFF1B365D),
        foregroundColor: Colors.white,
        actions: [
          if (widget.isAdmin)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.approval),
                  tooltip: '긴급 결재함',
                  onPressed: _openApprovalManagementScreen,
                ),
                if (_approvalRequests.isNotEmpty)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: CircleAvatar(
                      radius: 8,
                      backgroundColor: Colors.red,
                      child: Text('${_approvalRequests.length}', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  )
              ],
            ),
          IconButton(
            icon: const Icon(Icons.photo_library),
            tooltip: '근무표 사진 보기',
            onPressed: _openRosterImageScreen,
          ),
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.people_alt),
              tooltip: '전체 사원 종합 현황표',
              onPressed: _openAllEmployeesOverviewScreen,
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
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.indigo),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '• 2주 이내: 변경/신청/삭제 시 관리자 승인 필요\n• 2주 이후: 승인 없이 즉시 신청 및 [삭제] 가능',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1B365D)),
                    ),
                  ),
                ],
              ),
            ),
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
            _buildCalendarGrid(),
            const SizedBox(height: 16),
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
                              widget.isAdmin ? '👥 $selectedKey 전체 사원 신청 현황' : '📅 $selectedKey 내 신청 내역',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            if (isPast)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                                child: const Text('지난 날짜', style: TextStyle(fontSize: 11, color: Colors.black54)),
                              )
                            else if (isWithin2Weeks && !widget.isAdmin)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                                child: const Text('🔒 2주 이내 (승인필요)', style: TextStyle(fontSize: 11, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                              )
                            else if (!isWithin2Weeks && !widget.isAdmin)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(4)),
                                child: Text('🔓 2주 이후 (자유 신청/삭제)', style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: isPast ? _showPastWorkRecordDialog : _showAddWorkDialog,
                          icon: Icon(isPast ? Icons.edit_calendar : (isWithin2Weeks && !widget.isAdmin ? Icons.lock_clock : Icons.add_task), size: 18),
                          label: Text(isPast ? '지난 근무 기록' : (isWithin2Weeks && !widget.isAdmin ? '승인 요청' : '근무/휴가 신청')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isPast
                                ? Colors.blueGrey
                                : (isWithin2Weeks && !widget.isAdmin ? Colors.deepOrange : (widget.isAdmin ? Colors.indigo : const Color(0xFF1B365D))),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    if (myPendingList.isNotEmpty) ...[
                      const Text('⏳ 관리자 승인 대기 건', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                      const SizedBox(height: 6),
                      ...myPendingList.map((req) => Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.shade200)),
                            child: Row(
                              children: [
                                const Icon(Icons.hourglass_top, color: Colors.deepOrange, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text('[${req['empName']}] [${req['actionType'] ?? '신청'}] ${req['content']} (사유: ${req['reason']})',
                                      style: const TextStyle(fontSize: 13, color: Colors.brown, fontWeight: FontWeight.w600)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.deepOrange, borderRadius: BorderRadius.circular(10)),
                                  child: const Text('승인대기', style: TextStyle(color: Colors.white, fontSize: 11)),
                                ),
                              ],
                            ),
                          )),
                      const SizedBox(height: 10),
                    ],
                    if (displayList.isEmpty && myPendingList.isEmpty)
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
                          final isActual = item['type'] == '(실제기록)';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isActual ? Colors.grey.shade100 : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isActual ? Colors.blueGrey : const Color(0xFF1B365D),
                                child: Icon(
                                  isActual ? Icons.history : Icons.event_available,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                '[${item['empName']}(${item['empId']})] ${item['content']}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              subtitle: Text('구분: ${item['type']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                tooltip: widget.isAdmin
                                    ? '관리자 삭제'
                                    : (isWithin2Weeks ? '삭제 승인 요청' : '즉시 삭제'),
                                onPressed: () => _handleDeleteItem(selectedKey, item, isWithin2Weeks),
                              ),
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
              final isWithin2Weeks = _isWithinTwoWeeks(cellDate);

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
                        )
                      else if (isWithin2Weeks && !isPast)
                        Container(
                          margin: const EdgeInsets.only(top: 3),
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Colors.orange,
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

// 4. [관리자 전용] 결재함
class AdminApprovalScreen extends StatefulWidget {
  final List<Map<String, String>> approvalRequests;
  final Map<String, List<Map<String, String>>> scheduleMap;
  final VoidCallback onUpdated;
  final Function(String title, String body) sendNotification;

  const AdminApprovalScreen({
    super.key,
    required this.approvalRequests,
    required this.scheduleMap,
    required this.onUpdated,
    required this.sendNotification,
  });

  @override
  State<AdminApprovalScreen> createState() => _AdminApprovalScreenState();
}

class _AdminApprovalScreenState extends State<AdminApprovalScreen> {
  void _approveRequest(int index) {
    final req = widget.approvalRequests[index];
    final dateKey = req['date']!;
    final actionType = req['actionType'] ?? '신청요청';

    setState(() {
      if (actionType == '삭제요청') {
        widget.scheduleMap[dateKey]?.removeWhere((element) => element['empId'] == req['empId']);
      } else {
        final record = {
          'empId': req['empId']!,
          'empName': req['empName']!,
          'type': req['type']!,
          'content': req['content']!,
        };
        widget.scheduleMap.putIfAbsent(dateKey, () => []).removeWhere((element) => element['empId'] == req['empId']);
        widget.scheduleMap[dateKey]!.add(record);
      }
      widget.approvalRequests.removeAt(index);
    });
    widget.onUpdated();

    widget.sendNotification(
      "✅ [결재 승인 완료]",
      "${req['empName']}님의 $dateKey [$actionType] 건이 승인 처리되었습니다.",
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${req['empName']}님의 [$actionType] 건이 승인되었습니다.')),
    );
  }

  void _rejectRequest(int index) {
    final req = widget.approvalRequests[index];
    final actionType = req['actionType'] ?? '신청요청';
    final targetDate = req['date'] ?? '';

    setState(() {
      widget.approvalRequests.removeAt(index);
    });
    widget.onUpdated();

    widget.sendNotification(
      "❌ [결재 반려]",
      "${req['empName']}님의 $targetDate [$actionType] 건이 반려되었습니다.",
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('해당 요청이 반려되었습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('📌 2주 이내 긴급 신청/삭제 결재함 (${widget.approvalRequests.length}건)'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: widget.approvalRequests.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text('승인 대기 중인 결재 요청이 없습니다.', style: TextStyle(fontSize: 16, color: Colors.black54)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.approvalRequests.length,
              itemBuilder: (ctx, idx) {
                final req = widget.approvalRequests[idx];
                final isDeleteReq = req['actionType'] == '삭제요청';

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '📅 ${req['date']} [${isDeleteReq ? '삭제요청' : req['type']}]',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDeleteReq ? Colors.red : Colors.deepOrange),
                            ),
                            Text('신청일시: ${req['requestTime']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('👤 신청자: ${req['empName']} (${req['empId']})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text('📝 대상 내용: ${req['content']}', style: const TextStyle(fontSize: 14)),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                          child: Text('💡 사유: ${req['reason']}', style: const TextStyle(fontSize: 13, color: Colors.brown)),
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _rejectRequest(idx),
                              icon: const Icon(Icons.close, color: Colors.red),
                              label: const Text('반려', style: TextStyle(color: Colors.red)),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: () => _approveRequest(idx),
                              icon: const Icon(Icons.check),
                              label: Text(isDeleteReq ? '삭제 승인' : '신청 승인'),
                              style: ElevatedButton.styleFrom(backgroundColor: isDeleteReq ? Colors.red : Colors.deepOrange, foregroundColor: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// 5. 근무표 사진 뷰어
class RosterImageScreen extends StatefulWidget {
  final bool isAdmin;
  final String? currentImageBase64;
  final String? uploadTime;
  final Function(String newImageBase64, String timeStr) onImageUploaded;

  const RosterImageScreen({
    super.key,
    required this.isAdmin,
    this.currentImageBase64,
    this.uploadTime,
    required this.onImageUploaded,
  });

  @override
  State<RosterImageScreen> createState() => _RosterImageScreenState();
}

class _RosterImageScreenState extends State<RosterImageScreen> {
  String? _imagePreview;
  String? _timeStr;

  @override
  void initState() {
    super.initState();
    _imagePreview = widget.currentImageBase64;
    _timeStr = widget.uploadTime;
  }

  void _pickAndUploadImage() {
    final uploadInput = html.FileUploadInputElement()..accept = 'image/*';
    uploadInput.click();

    uploadInput.onChange.listen((e) {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        final file = files[0];
        final reader = html.FileReader();

        reader.readAsDataUrl(file);
        reader.onLoadEnd.listen((e) {
          final result = reader.result as String?;
          if (result != null) {
            final now = DateTime.now();
            final nowStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

            setState(() {
              _imagePreview = result;
              _timeStr = nowStr;
            });

            html.window.localStorage['ktng_roster_image'] = result;
            html.window.localStorage['ktng_roster_time'] = nowStr;

            widget.onImageUploaded(result, nowStr);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('근무표 사진이 성공적으로 등록되었습니다!')),
            );
          }
        });
      }
    });
  }

  void _deleteImage() {
    setState(() {
      _imagePreview = null;
      _timeStr = null;
    });
    html.window.localStorage.remove('ktng_roster_image');
    html.window.localStorage.remove('ktng_roster_time');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('근무표 사진이 삭제되었습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: Text(widget.isAdmin ? '근무표 사진 관리 (관리자)' : '공식 근무표 사진'),
        backgroundColor: widget.isAdmin ? Colors.indigo : const Color(0xFF1B365D),
        foregroundColor: Colors.white,
        actions: [
          if (widget.isAdmin) ...[
            IconButton(icon: const Icon(Icons.upload_file), tooltip: '새 사진 등록/교체', onPressed: _pickAndUploadImage),
            if (_imagePreview != null) IconButton(icon: const Icon(Icons.delete), tooltip: '사진 삭제', onPressed: _deleteImage),
          ],
        ],
      ),
      body: _imagePreview == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.image_not_supported_outlined, size: 72, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('등록된 근무표 사진이 없습니다.', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  if (widget.isAdmin) ...[
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _pickAndUploadImage,
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('근무표 사진 업로드'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                    ),
                  ],
                ],
              ),
            )
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.black54,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_timeStr != null ? '등록일시: $_timeStr' : '공식 근무표', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      const Text('💡 두 손가락 또는 마우스 휠로 확대 가능', style: TextStyle(color: Colors.amberAccent, fontSize: 12)),
                    ],
                  ),
                ),
                Expanded(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 5.0,
                    child: Center(
                      child: Image.memory(
                        base64Decode(_imagePreview!.split(',').last),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// 6. 전체 사원 종합 현황표
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

    flattenedList.sort((a, b) => b['date']!.compareTo(a['date']!));

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
                            backgroundColor: item['type'] == '(실제기록)' ? Colors.blueGrey : Colors.teal,
                            child: Text(item['empName']!.isNotEmpty ? item['empName']![0] : 'U', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                                widget.scheduleMap[date]?.removeWhere((element) => element['empId'] == item['empId']);
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