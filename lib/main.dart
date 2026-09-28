import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';

// Firebase Firestore 설정
const String firestoreBaseUrl =
    'https://firestore.googleapis.com/v1/projects/ktng-schedule-app/databases/(default)/documents';
const String firestoreApiKey = 'AIzaSyDummyKeyReplaceIfConfigured';

// 전역 사용자 계정 및 근무 데이터 저장소
Map<String, Map<String, String>> globalUsers = {
  '20190416': {'name': '김수완', 'password': '1234'},
};

// 근무 기록 데이터 (사번 -> 날짜 문자열(YYYY-MM-DD) -> 근무 타입)
Map<String, Map<String, String>> globalShifts = {};

// 관리자 공지 및 게시글 데이터 목록
List<Map<String, String>> globalPosts = [
  {
    'id': '1',
    'title': 'KT&G 근무 스케줄 관리 시스템 안내',
    'content': '근무 등록 시 오전, 오후, 야간, 주간(08:30~17:30)을 정확히 선택해 주시기 바랍니다.',
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

// 데이터 저장 헬퍼 함수
void saveAllData() {
  try {
    html.window.localStorage['ktng_users_data'] = jsonEncode(globalUsers);
    html.window.localStorage['ktng_shifts_data'] = jsonEncode(globalShifts);
    html.window.localStorage['ktng_posts_data'] = jsonEncode(globalPosts);
  } catch (_) {}
}

// -------------------------------------------------------------
// 1. 보안 로그인 & 회원가입 화면
// -------------------------------------------------------------
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

// -------------------------------------------------------------
// 2. 메인 스케줄 & 게시글 관리 화면
// -------------------------------------------------------------
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
  DateTime _focusedDate = DateTime.now();

  // 근무 유형 목록 (요청 반영: '종일' 제거)
  final List<String> _shiftTypes = [
    '주간 (08:30 - 17:30)',
    '오전 (06:30 - 14:30)',
    '오후 (14:30 - 22:30)',
    '야간 (22:30 - 06:30)',
  ];

  // 관리자 전용 게시글 등록 다이얼로그 (요청 반영: 기능 복구)
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

  // 근태 기록 등록 다이얼로그 (종일 제외된 4개 선택지)
  void _showAddShiftDialog(DateTime date) {
    String selectedShift = _shiftTypes[0];
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('$dateStr 근무 등록', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _shiftTypes.map((type) {
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
            }).toList(),
          ),
          actions: [
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
                  const SnackBar(content: Text('근무가 등록되었습니다.'), backgroundColor: Colors.green),
                );
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userShifts = globalShifts[widget.employeeId] ?? {};

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isAdmin ? 'KT&G 근무관리 [관리자 모드]' : 'KT&G 근무관리 (${widget.userName} 님)',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1B365D),
        actions: [
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
      // 관리자 모드일 때만 게시글 등록 플로팅 액션 버튼 노출 (복구 완료)
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 공지사항 및 게시글 영역
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '📢 사내 공지 및 게시판',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B365D)),
                ),
                if (widget.isAdmin)
                  TextButton.icon(
                    onPressed: _showCreatePostDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('새 글 작성'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (globalPosts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Text('등록된 공지사항이 없습니다.'),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: globalPosts.length,
                itemBuilder: (ctx, idx) {
                  final post = globalPosts[idx];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(post['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${post['author']} | ${post['date']}\n${post['content']}'),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            const Divider(height: 36, thickness: 1.5),

            // 캘린더 및 근무 등록 영역
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '📅 ${_focusedDate.year}년 ${_focusedDate.month}월 근무 일정',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B365D)),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddShiftDialog(_focusedDate),
                  icon: const Icon(Icons.access_time, size: 16),
                  label: const Text('오늘 근태 등록'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B365D),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 간이 일정 뷰어 카드
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: List.generate(7, (index) {
                    final day = DateTime.now().add(Duration(days: index));
                    final dayStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                    final shift = userShifts[dayStr] ?? '미등록';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: shift == '미등록' ? Colors.grey.shade200 : const Color(0xFF1B365D).withOpacity(0.1),
                        child: Text('${day.day}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      title: Text('$dayStr 근무'),
                      trailing: Chip(
                        label: Text(shift, style: TextStyle(color: shift == '미등록' ? Colors.grey : const Color(0xFF1B365D))),
                      ),
                      onTap: () => _showAddShiftDialog(day),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}