import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';

// Firestore 기본 설정
const String firestoreBaseUrl =
    'https://firestore.googleapis.com/v1/projects/ktng-schedule-app/databases/(default)/documents';
const String firestoreApiKey = 'AIzaSyDummyKeyReplaceIfConfigured';

// 1. 전역 계정 저장소 (사번 -> {성명, 비밀번호})
Map<String, Map<String, String>> globalUsers = {
  '20190416': {'name': '김수완', 'password': '1234'},
};

// 2. 전역 근무 기록 저장소 (사번 -> 날짜 -> 근무유형)
Map<String, Map<String, String>> globalShifts = {};

// 3. 관리자 및 공지 게시글 목록
List<Map<String, String>> globalPosts = [
  {
    'id': '1',
    'title': 'KT&G 근무 스케줄 관리 시스템 안내',
    'content': '근무 등록 시 주간, 오전, 오후, 야간을 정확히 선택해 주시기 바랍니다.',
    'author': '관리자',
    'date': '2026-09-28',
  }
];

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KT&G 근무 스케줄 관리',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF1B365D),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B365D)),
        useMaterial3: true,
        fontFamily: 'Pretendard',
      ),
      home: const LoginScreen(),
    );
  }
}

// 브라우저 로컬 저장소 동기화
void saveAllData() {
  try {
    html.window.localStorage['ktng_users_data'] = jsonEncode(globalUsers);
    html.window.localStorage['ktng_shifts_data'] = jsonEncode(globalShifts);
    html.window.localStorage['ktng_posts_data'] = jsonEncode(globalPosts);
  } catch (_) {}
}

// =============================================================
// 로그인 & 회원가입 화면 (비밀번호 검증 및 신규 가입)
// =============================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isSignUpMode = false;

  final _empIdController = TextEditingController(text: '20190416');
  final _nameController = TextEditingController(text: '김수완');
  final _pwController = TextEditingController();
  final _confirmPwController = TextEditingController();
  final _adminCodeController = TextEditingController();

  bool _isAdminMode = false;
  static const String correctAdminCode = "ktngsj";

  @override
  void initState() {
    super.initState();
    _loadStorageData();
  }

  void _loadStorageData() {
    try {
      final usersLocal = html.window.localStorage['ktng_users_data'];
      if (usersLocal != null && usersLocal.isNotEmpty) {
        final decoded = jsonDecode(usersLocal) as Map<String, dynamic>;
        globalUsers = decoded.map((k, v) => MapEntry(k, Map<String, String>.from(v as Map)));
      }

      final shiftsLocal = html.window.localStorage['ktng_shifts_data'];
      if (shiftsLocal != null && shiftsLocal.isNotEmpty) {
        final decoded = jsonDecode(shiftsLocal) as Map<String, dynamic>;
        globalShifts = decoded.map((k, v) => MapEntry(k, Map<String, String>.from(v as Map)));
      }

      final postsLocal = html.window.localStorage['ktng_posts_data'];
      if (postsLocal != null && postsLocal.isNotEmpty) {
        final decoded = jsonDecode(postsLocal) as List;
        globalPosts = decoded.map((e) => Map<String, String>.from(e as Map)).toList();
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _empIdController.dispose();
    _nameController.dispose();
    _pwController.dispose();
    _confirmPwController.dispose();
    _adminCodeController.dispose();
    super.dispose();
  }

  void _submitAuth() {
    final empId = _empIdController.text.trim();
    final name = _nameController.text.trim();
    final pw = _pwController.text.trim();

    if (empId.isEmpty || name.isEmpty || pw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사번, 성명, 비밀번호를 모두 입력해주세요.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    if (_isSignUpMode) {
      final confirmPw = _confirmPwController.text.trim();
      if (pw != confirmPw) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('비밀번호 확인이 일치하지 않습니다.'), backgroundColor: Colors.redAccent),
        );
        return;
      }
      if (globalUsers.containsKey(empId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 등록된 사번입니다. 로그인해주세요.'), backgroundColor: Colors.redAccent),
        );
        return;
      }
      globalUsers[empId] = {'name': name, 'password': pw};
      saveAllData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원가입이 완료되었습니다! 로그인해주세요.'), backgroundColor: Colors.green),
      );
      setState(() {
        _isSignUpMode = false;
        _pwController.clear();
        _confirmPwController.clear();
      });
    } else {
      if (_isAdminMode) {
        if (_adminCodeController.text.trim() != correctAdminCode) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('관리자 비밀코드가 올바르지 않습니다.'), backgroundColor: Colors.redAccent),
          );
          return;
        }
      } else {
        if (!globalUsers.containsKey(empId)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('등록되지 않은 사번입니다. 먼저 회원가입을 해주세요.'), backgroundColor: Colors.redAccent),
          );
          return;
        }
        final user = globalUsers[empId]!;
        if (user['name'] != name) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('사번에 등록된 성명과 일치하지 않습니다.'), backgroundColor: Colors.redAccent),
          );
          return;
        }
        if (user['password'] != pw) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('비밀번호가 일치하지 않습니다.'), backgroundColor: Colors.redAccent),
          );
          return;
        }
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
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
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1B365D)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _isSignUpMode ? '신규 사원 계정 등록 (회원가입)' : '근무 스케줄 관리 시스템',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF1B365D)),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _isSignUpMode = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: !_isSignUpMode ? const Color(0xFF1B365D) : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                          ),
                          child: Text(
                            '로그인',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: !_isSignUpMode ? const Color(0xFF1B365D) : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() {
                          _isSignUpMode = true;
                          _isAdminMode = false;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: _isSignUpMode ? const Color(0xFF1B365D) : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                          ),
                          child: Text(
                            '회원가입',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _isSignUpMode ? const Color(0xFF1B365D) : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _empIdController,
                  decoration: const InputDecoration(
                    labelText: '사번 (Employee ID)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '성명 (Name)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _pwController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '비밀번호 (Password)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                if (_isSignUpMode) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: _confirmPwController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '비밀번호 확인',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.check_circle_outline),
                    ),
                  ),
                ],
                if (!_isSignUpMode) ...[
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('관리자 모드로 로그인', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    value: _isAdminMode,
                    onChanged: (val) {
                      setState(() {
                        _isAdminMode = val;
                        if (!val) _adminCodeController.clear();
                      });
                    },
                  ),
                  if (_isAdminMode) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _adminCodeController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: '관리자 마스터 코드',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.security),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: _submitAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B365D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    _isSignUpMode ? '신규 계정 회원가입 완료' : '로그인',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================
// 메인 화면 (캘린더 + 원래 Drawer 메뉴 + 관리자 기능)
// =============================================================
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
  DateTime _currentMonth = DateTime.now();

  // '종일'이 완전히 삭제된 4대 근무 유형
  final List<String> _shiftTypes = [
    '주간 (08:30 - 17:30)',
    '오전 (06:30 - 14:30)',
    '오후 (14:30 - 22:30)',
    '야간 (22:30 - 06:30)',
  ];

  Color _getShiftColor(String shift) {
    if (shift.contains('주간')) return Colors.blue.shade700;
    if (shift.contains('오전')) return Colors.orange.shade700;
    if (shift.contains('오후')) return Colors.green.shade700;
    if (shift.contains('야간')) return Colors.purple.shade700;
    return Colors.blueGrey;
  }

  // 1. 관리자 전용 사원 관리 & 비밀번호 초기화 다이얼로그
  void _showUserManagerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.manage_accounts, color: Color(0xFF1B365D)),
              SizedBox(width: 8),
              Text('사원 계정 관리 및 정보 수정', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: globalUsers.isEmpty
                ? const Center(child: Text('가입된 사원이 없습니다.'))
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: globalUsers.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final empId = globalUsers.keys.elementAt(index);
                      final userData = globalUsers[empId]!;
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF1B365D),
                          child: Icon(Icons.person, color: Colors.white, size: 20),
                        ),
                        title: Text('${userData['name']} (사번: $empId)', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('비밀번호: ${userData['password']}'),
                        trailing: ElevatedButton.icon(
                          icon: const Icon(Icons.edit, size: 14),
                          label: const Text('수정'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          onPressed: () {
                            _showEditUserDialog(empId, userData['name'] ?? '', userData['password'] ?? '', () {
                              setDialogState(() {});
                              setState(() {});
                            });
                          },
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
          ],
        ),
      ),
    );
  }

  // 사원 정보 수정 모달
  void _showEditUserDialog(String empId, String currentName, String currentPw, VoidCallback onUpdated) {
    final nameEditCtrl = TextEditingController(text: currentName);
    final pwEditCtrl = TextEditingController(text: currentPw);

    showDialog(
      context: context,
      builder: (editCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('사원 정보 수정 ($empId)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameEditCtrl,
              decoration: const InputDecoration(labelText: '성명', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pwEditCtrl,
              decoration: const InputDecoration(
                labelText: '새 비밀번호 (분실 시 변경)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_reset),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(editCtx), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B365D), foregroundColor: Colors.white),
            onPressed: () {
              final newName = nameEditCtrl.text.trim();
              final newPw = pwEditCtrl.text.trim();
              if (newName.isEmpty || newPw.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('성명과 비밀번호를 모두 입력하세요.'), backgroundColor: Colors.redAccent),
                );
                return;
              }
              globalUsers[empId] = {'name': newName, 'password': newPw};
              saveAllData();
              onUpdated();
              Navigator.pop(editCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$empId 사원의 정보가 성공적으로 변경되었습니다.'), backgroundColor: Colors.green),
              );
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  // 2. 관리자 게시글 등록 모달
  void _showCreatePostDialog() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.campaign, color: Color(0xFF1B365D)),
            SizedBox(width: 8),
            Text('공지 및 게시글 등록', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: '게시글 제목', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: contentCtrl,
                maxLines: 4,
                decoration: const InputDecoration(labelText: '공지 내용 작성', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B365D),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final t = titleCtrl.text.trim();
              final c = contentCtrl.text.trim();
              if (t.isEmpty || c.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('제목과 내용을 모두 입력해주세요.'), backgroundColor: Colors.redAccent),
                );
                return;
              }
              setState(() {
                globalPosts.insert(0, {
                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                  'title': t,
                  'content': c,
                  'author': widget.userName,
                  'date': '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
                });
              });
              saveAllData();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('게시글이 성공적으로 등록되었습니다.'), backgroundColor: Colors.green),
              );
            },
            child: const Text('등록 완료'),
          ),
        ],
      ),
    );
  }

  // 3. 근태 기록 모달 ('종일' 없음)
  void _showAddShiftDialog(DateTime date) {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final existingShift = (globalShifts[widget.employeeId] ?? {})[dateStr];
    String selectedShift = existingShift ?? _shiftTypes[0];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('$dateStr 근무 설정', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ..._shiftTypes.map((type) {
                return RadioListTile<String>(
                  title: Text(type, style: const TextStyle(fontSize: 14)),
                  value: type,
                  groupValue: selectedShift,
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedShift = val);
                    }
                  },
                );
              }),
            ],
          ),
          actions: [
            if (existingShift != null)
              TextButton(
                onPressed: () {
                  setState(() {
                    globalShifts[widget.employeeId]?.remove(dateStr);
                  });
                  saveAllData();
                  Navigator.pop(ctx);
                },
                child: const Text('근무 삭제', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B365D),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  globalShifts.putIfAbsent(widget.employeeId, () => {})[dateStr] = selectedShift;
                });
                saveAllData();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('근무가 정상적으로 저장되었습니다.'), backgroundColor: Colors.green),
                );
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  // 캘린더 날짜 생성기
  List<DateTime?> _buildMonthDays(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final startWeekday = firstDay.weekday % 7; // 일(0) ~ 토(6)

    final List<DateTime?> days = [];
    for (int i = 0; i < startWeekday; i++) {
      days.add(null);
    }
    for (int d = 1; d <= lastDay.day; d++) {
      days.add(DateTime(month.year, month.month, d));
    }
    while (days.length % 7 != 0) {
      days.add(null);
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final userShifts = globalShifts[widget.employeeId] ?? {};
    final days = _buildMonthDays(_currentMonth);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isAdmin ? 'KT&G 근무관리 [관리자 모드]' : 'KT&G 근무관리 (${widget.userName} 님)',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1B365D),
        actions: [
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.manage_accounts, color: Colors.white),
              tooltip: '사원 계정 및 비밀번호 관리',
              onPressed: _showUserManagerDialog,
            ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: '로그아웃',
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      // 스크린샷에 있던 원래 좌측 서랍 메뉴(Drawer) 복원
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF1B365D)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 26,
                    child: Icon(Icons.person, color: Color(0xFF1B365D), size: 32),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${widget.userName} ${widget.isAdmin ? "[관리자]" : "사원"}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    '사번: ${widget.employeeId}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.access_time_filled, color: Colors.blueAccent),
              title: Text(widget.isAdmin ? '⏰ 근태기록 관리 및 등록' : '⏰ 근태기록 관리 및 조회'),
              subtitle: const Text('오전, 오후, 야간 및 추가 근무 관리'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {
                Navigator.pop(context);
                _showAddShiftDialog(DateTime.now());
              },
            ),
            if (widget.isAdmin) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: Colors.teal),
                title: const Text('사원 계정 및 비밀번호 관리'),
                subtitle: const Text('가입자 조회 및 분실 비밀번호 초기화'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.pop(context);
                  _showUserManagerDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.campaign, color: Colors.deepOrange),
                title: const Text('공지사항 및 게시글 등록'),
                subtitle: const Text('새로운 전사 공지 등록'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.pop(context);
                  _showCreatePostDialog();
                },
              ),
            ],
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('로그아웃'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),
          ],
        ),
      ),
      // 관리자 모드 전용 플로팅 글쓰기 버튼
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF1B365D),
              icon: const Icon(Icons.edit, color: Colors.white),
              label: const Text('게시글 등록', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: _showCreatePostDialog,
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 관리자 모드일 때만 뜨는 사원 관리 카드
            if (widget.isAdmin) ...[
              Card(
                color: const Color(0xFF1B365D).withOpacity(0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.admin_panel_settings, color: Color(0xFF1B365D), size: 32),
                  title: const Text('사원 계정 관리 및 비밀번호 변경', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('현재 가입된 사원 수: 총 ${globalUsers.length}명'),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B365D), foregroundColor: Colors.white),
                    onPressed: _showUserManagerDialog,
                    child: const Text('사원 관리 열기'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 공지사항 카드
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '📢 사내 공지 및 게시판',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B365D)),
                        ),
                        if (widget.isAdmin)
                          TextButton.icon(
                            onPressed: _showCreatePostDialog,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('새 글 작성'),
                          ),
                      ],
                    ),
                    const Divider(height: 16),
                    if (globalPosts.isEmpty)
                      const Text('등록된 공지사항이 없습니다.')
                    else
                      ...globalPosts.map((post) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('• ${post['title']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text('   ${post['content']}', style: const TextStyle(color: Colors.black87, fontSize: 13)),
                                Text('   ${post['author']} | ${post['date']}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                              ],
                            ),
                          )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 월간 캘린더 네비게이터 및 그리드 카드
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () {
                            setState(() {
                              _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
                            });
                          },
                        ),
                        Text(
                          '${_currentMonth.year}년 ${_currentMonth.month}월',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B365D)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () {
                            setState(() {
                              _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // 요일 헤더
                    Row(
                      children: ['일', '월', '화', '수', '목', '금', '토'].map((day) {
                        Color col = Colors.black87;
                        if (day == '일') col = Colors.red;
                        if (day == '토') col = Colors.blue;
                        return Expanded(
                          child: Center(
                            child: Text(day, style: TextStyle(fontWeight: FontWeight.bold, color: col)),
                          ),
                        );
                      }).toList(),
                    ),
                    const Divider(height: 20),

                    // 월간 캘린더 그리드
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: days.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: 0.85,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      itemBuilder: (context, index) {
                        final date = days[index];
                        if (date == null) {
                          return const SizedBox.shrink();
                        }

                        final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                        final shift = userShifts[dateStr];
                        final isToday = date.year == DateTime.now().year && date.month == DateTime.now().month && date.day == DateTime.now().day;

                        return InkWell(
                          onTap: () => _showAddShiftDialog(date),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isToday ? Colors.blue.withOpacity(0.06) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isToday ? const Color(0xFF1B365D) : Colors.grey.shade200,
                                width: isToday ? 1.5 : 1,
                              ),
                            ),
                            padding: const EdgeInsets.all(4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                    color: date.weekday == DateTime.sunday
                                        ? Colors.red
                                        : (date.weekday == DateTime.saturday ? Colors.blue : Colors.black87),
                                  ),
                                ),
                                const Spacer(),
                                if (shift != null)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                                    decoration: BoxDecoration(
                                      color: _getShiftColor(shift),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      shift.split(' ')[0], // '주간', '오전' 등으로 표시
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}