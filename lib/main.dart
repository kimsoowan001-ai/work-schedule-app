import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '근무 스케줄 관리',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

// ----------------------
// 로그인 화면 (사번/이름/관리자코드)
// ----------------------
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
  final String _correctAdminCode = "ktngsj"; // 관리자 전용 접속 코드

  void _handleLogin() {
    final empId = _employeeIdController.text.trim();
    final name = _nameController.text.trim();

    if (empId.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사번과 이름을 모두 입력해 주세요.')),
      );
      return;
    }

    if (_isAdminMode) {
      if (_adminCodeController.text.trim() != _correctAdminCode) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('관리자 코드가 일치하지 않습니다.')),
        );
        return;
      }
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MainScheduleScreen(
          employeeId: empId,
          userName: name,
          userRole: _isAdminMode ? 'ADMIN' : 'USER',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo.shade50,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_month, size: 64, color: Colors.indigo),
                  const SizedBox(height: 12),
                  const Text('근무 스케줄 관리', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _employeeIdController,
                    decoration: const InputDecoration(
                      labelText: '사번',
                      prefixIcon: Icon(Icons.badge),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '이름',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('관리자로 접속'),
                    value: _isAdminMode,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setState(() {
                        _isAdminMode = val ?? false;
                      });
                    },
                  ),
                  if (_isAdminMode) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _adminCodeController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: '관리자 전용 코드',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(_isAdminMode ? '관리자 로그인' : '사용자 로그인', style: const TextStyle(fontSize: 16)),
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
}

// ----------------------
// 메인 스케줄 화면
// ----------------------
class ScheduleItem {
  final String employeeId;
  final String userName;
  final String type;
  final int leaveMinutes;
  final bool isApproved;

  ScheduleItem({
    required this.employeeId,
    required this.userName,
    required this.type,
    this.leaveMinutes = 0,
    required this.isApproved,
  });
}

class MainScheduleScreen extends StatefulWidget {
  final String employeeId;
  final String userName;
  final String userRole;

  const MainScheduleScreen({
    super.key,
    required this.employeeId,
    required this.userName,
    required this.userRole,
  });

  @override
  State<MainScheduleScreen> createState() => _MainScheduleScreenState();
}

class _MainScheduleScreenState extends State<MainScheduleScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  final Map<String, List<ScheduleItem>> _scheduleDatabase = {};

  bool _isAfterTwoWeeks(DateTime targetDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return targetDate.difference(today).inDays >= 14;
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });

    if (widget.userRole == 'ADMIN') {
      _showAdminDialog(selectedDay);
    } else {
      if (selectedDay.weekday == DateTime.saturday) {
        _showSaturdayDialog(selectedDay);
      } else if (selectedDay.weekday == DateTime.sunday) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('일요일은 일정을 입력할 수 없습니다.')),
        );
      } else {
        _showWeekdayDialog(selectedDay);
      }
    }
  }

  void _showSaturdayDialog(DateTime date) {
    final isPending = _isAfterTwoWeeks(date);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${date.month}월 ${date.day}일 (토) 근무 가능 여부', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            if (isPending)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('⚠️ 2주 뒤 일정은 관리자 승인 후 최종 반영됩니다.', style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.check_circle_outline, color: Colors.blue),
              title: const Text('근무 가능'),
              onTap: () => _saveSchedule(date, '근무가능', 0, !isPending),
            ),
            ListTile(
              leading: const Icon(Icons.cancel_outlined, color: Colors.grey),
              title: const Text('근무 불가'),
              onTap: () => _saveSchedule(date, '근무불가', 0, !isPending),
            ),
          ],
        ),
      ),
    );
  }

  void _showWeekdayDialog(DateTime date) {
    final isPending = _isAfterTwoWeeks(date);
    double leaveHours = 8.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${date.month}월 ${date.day}일 일정 선택', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              if (isPending)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('⚠️ 2주 뒤 일정은 관리자 승인 후 최종 반영됩니다.', style: TextStyle(color: Colors.red, fontSize: 12)),
                ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.fitness_center, color: Colors.orange),
                title: const Text('체력단련'),
                onTap: () => _saveSchedule(date, '체력단련', 0, !isPending),
              ),
              ListTile(
                leading: const Icon(Icons.favorite, color: Colors.pink),
                title: const Text('가족사랑'),
                onTap: () => _saveSchedule(date, '가족사랑', 0, !isPending),
              ),
              const Divider(),
              const Text('연차 신청 (0분 ~ 8시간)', style: TextStyle(fontWeight: FontWeight.bold)),
              Slider(
                value: leaveHours,
                min: 0.0,
                max: 8.0,
                divisions: 16,
                label: '${leaveHours.toStringAsFixed(1)}시간 (${(leaveHours * 60).toInt()}분)',
                onChanged: (val) {
                  setModalState(() => leaveHours = val);
                },
              ),
              Center(
                child: Text('선택한 연차 시간: ${leaveHours.toStringAsFixed(1)}시간 (${(leaveHours * 60).toInt()}분)', style: const TextStyle(color: Colors.indigo)),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _saveSchedule(date, '연차', (leaveHours * 60).toInt(), !isPending),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                  child: const Text('연차 등록하기'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showAdminDialog(DateTime date) {
    final key = _formatDate(date);
    final items = _scheduleDatabase[key] ?? [];

    Map<String, List<ScheduleItem>> categorized = {
      '연차': [],
      '체력단련': [],
      '가족사랑': [],
      '근무가능': [],
      '근무불가': [],
    };

    for (var item in items) {
      if (categorized.containsKey(item.type)) {
        categorized[item.type]!.add(item);
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$key 인원 현황'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: categorized.entries.map((entry) {
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text('${entry.key} (${entry.value.length}명)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: entry.value.isEmpty
                      ? const Text('등록된 인원 없음', style: TextStyle(color: Colors.grey, fontSize: 12))
                      : Text(
                          entry.value.map((e) {
                            final status = e.isApproved ? '' : ' [승인대기]';
                            if (e.type == '연차') {
                              return '${e.userName}(${e.employeeId}, ${(e.leaveMinutes / 60).toStringAsFixed(1)}h)$status';
                            }
                            return '${e.userName}(${e.employeeId})$status';
                          }).join(', '),
                          style: const TextStyle(fontSize: 13),
                        ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
        ],
      ),
    );
  }

  void _saveSchedule(DateTime date, String type, int minutes, bool isApproved) {
    final key = _formatDate(date);
    setState(() {
      _scheduleDatabase.putIfAbsent(key, () => []);
      _scheduleDatabase[key]!.removeWhere((item) => item.employeeId == widget.employeeId);
      _scheduleDatabase[key]!.add(
        ScheduleItem(
          employeeId: widget.employeeId,
          userName: widget.userName,
          type: type,
          leaveMinutes: minutes,
          isApproved: isApproved,
        ),
      );
    });

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isApproved ? '[$type] 등록이 완료되었습니다.' : '[$type] 관리자 승인 요청되었습니다.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userRole == 'ADMIN' ? '관리자 모드' : '${widget.userName} (${widget.employeeId})'),
        backgroundColor: widget.userRole == 'ADMIN' ? Colors.orange.shade100 : Colors.indigo.shade50,
        actions: [
          IconButton(
            icon: const Icon(Icons.campaign, color: Colors.deepOrange),
            tooltip: '근무표 및 공지사항',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NoticeScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            color: Colors.amber.shade100,
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '📌 안내: 다음 달 근무일정은 당월 2째주 안으로 입력을 완료해 주세요.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TableCalendar(
              firstDay: DateTime.utc(2025, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: _onDaySelected,
              calendarStyle: const CalendarStyle(
                weekendTextStyle: TextStyle(color: Colors.red),
                todayDecoration: BoxDecoration(color: Colors.indigoAccent, shape: BoxShape.circle),
                selectedDecoration: BoxDecoration(color: Colors.indigo, shape: BoxShape.circle),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------
// 공지사항 화면
// ----------------------
class NoticeScreen extends StatelessWidget {
  const NoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('공지사항 및 근무표')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📢 이번 달 최종 근무표', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Container(
                    height: 200,
                    width: double.infinity,
                    color: Colors.grey.shade300,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('업로드된 근무표 이미지가 표시됩니다.'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}