import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:html' as html;

// Firebase 클라우드 DB 연동 설정
const String firestoreProjectId = "ktng-schedule";
const String firestoreApiKey = "AIzaSyCqq2-pNm6e4z4nq0ijX3ZI4bGsxY0w75Q";
const String firestoreBaseUrl =
    "https://firestore.googleapis.com/v1/projects/$firestoreProjectId/databases/(default)/documents/app_data";

// 전역 상태 데이터
Map<String, List<Map<String, String>>> globalScheduleMap = {};
List<Map<String, String>> globalApprovalRequests = [];
List<Map<String, dynamic>> globalAttendanceRecords = [];
Map<String, Map<String, String>> globalUsers = {};

String getCurrentDateTimeString() {
  final now = DateTime.now();
  final y = now.year;
  final m = now.month.toString().padLeft(2, '0');
  final d = now.day.toString().padLeft(2, '0');
  final h = now.hour.toString().padLeft(2, '0');
  final min = now.minute.toString().padLeft(2, '0');
  return "$y-$m-$d $h:$min";
}

// 스마트폰 고용량 사진 압축 최적화
Future<String> compressAndConvertImage(html.File file) async {
  final reader = html.FileReader();
  reader.readAsDataUrl(file);
  await reader.onLoadEnd.first;
  final rawDataUrl = reader.result as String;

  final img = html.ImageElement();
  img.src = rawDataUrl;
  await img.onLoad.first;

  int width = img.width ?? 800;
  int height = img.height ?? 600;
  const maxDim = 800;

  if (width > maxDim || height > maxDim) {
    if (width > height) {
      height = (height * maxDim / width).round();
      width = maxDim;
    } else {
      width = (width * maxDim / height).round();
      height = maxDim;
    }
  }

  final canvas = html.CanvasElement(width: width, height: height);
  final ctx = canvas.context2D;
  ctx.drawImageScaled(img, 0, 0, width, height);

  return canvas.toDataUrl('image/jpeg', 0.6);
}

Future<void> saveBoardAndNoticeToServer(String notice, List<Map<String, dynamic>> posts) async {
  try {
    final postsJson = jsonEncode(posts);
    html.window.localStorage['ktng_notice'] = notice;
    html.window.localStorage['ktng_bulletin_posts'] = postsJson;

    await html.HttpRequest.request(
      '$firestoreBaseUrl/board?key=$firestoreApiKey',
      method: 'PATCH',
      requestHeaders: {'Content-Type': 'application/json'},
      sendData: jsonEncode({
        'fields': {
          'notice': {'stringValue': notice},
          'posts': {'stringValue': postsJson},
        }
      }),
    );
  } catch (e) {
    debugPrint("게시판 서버 저장 오류: $e");
  }
}

Future<void> saveAllData() async {
  try {
    final schedJson = jsonEncode(globalScheduleMap);
    final appJson = jsonEncode(globalApprovalRequests);
    final attJson = jsonEncode(globalAttendanceRecords);
    final usersJson = jsonEncode(globalUsers);

    html.window.localStorage['ktng_schedule_data'] = schedJson;
    html.window.localStorage['ktng_approval_data'] = appJson;
    html.window.localStorage['ktng_attendance_data'] = attJson;
    html.window.localStorage['ktng_users_data'] = usersJson;

    await html.HttpRequest.request(
      '$firestoreBaseUrl/schedules?key=$firestoreApiKey',
      method: 'PATCH',
      requestHeaders: {'Content-Type': 'application/json'},
      sendData: jsonEncode({
        'fields': {
          'data': {'stringValue': schedJson}
        }
      }),
    );

    await html.HttpRequest.request(
      '$firestoreBaseUrl/approvals?key=$firestoreApiKey',
      method: 'PATCH',
      requestHeaders: {'Content-Type': 'application/json'},
      sendData: jsonEncode({
        'fields': {
          'data': {'stringValue': appJson}
        }
      }),
    );

    await html.HttpRequest.request(
      '$firestoreBaseUrl/attendance?key=$firestoreApiKey',
      method: 'PATCH',
      requestHeaders: {'Content-Type': 'application/json'},
      sendData: jsonEncode({
        'fields': {
          'data': {'stringValue': attJson}
        }
      }),
    );

    await html.HttpRequest.request(
      '$firestoreBaseUrl/users?key=$firestoreApiKey',
      method: 'PATCH',
      requestHeaders: {'Content-Type': 'application/json'},
      sendData: jsonEncode({
        'fields': {
          'data': {'stringValue': usersJson}
        }
      }),
    );
  } catch (e) {
    debugPrint("서버 저장 오류: $e");
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WorkScheduleApp());
}

class WorkScheduleApp extends StatelessWidget {
  const WorkScheduleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = html.window.localStorage['is_logged_in'] == 'true';
    final savedEmpId = html.window.localStorage['last_emp_id'] ?? '';
    final savedName = html.window.localStorage['last_name'] ?? '';
    final savedAdmin = html.window.localStorage['is_admin'] == 'true';

    final Widget initialHome =
        (isLoggedIn && savedEmpId.isNotEmpty && savedName.isNotEmpty)
            ? MainScheduleScreen(
                employeeId: savedEmpId,
                userName: savedName,
                isAdmin: savedAdmin,
              )
            : const SplashScreen();

    return MaterialApp(
      title: 'KT&G 근무 스케줄 관리',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B365D)),
        useMaterial3: true,
      ),
      home: initialHome,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
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
                style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF333333)),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '근무 스케줄 관리 시스템',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B365D),
                  letterSpacing: 1.2),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                  strokeWidth: 3, color: Color(0xFFE35205)),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isSignUpMode = false;
  final _empIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _pwController = TextEditingController();
  final _confirmPwController = TextEditingController();
  final _adminCodeController = TextEditingController();
  bool _isAdminMode = false;
  static const String correctAdminCode = "ktngsj";

  @override
  void initState() {
    super.initState();
    _loadUsersData();
  }

  Future<void> _loadUsersData() async {
    try {
      final local = html.window.localStorage['ktng_users_data'];
      if (local != null && local.isNotEmpty) {
        final decoded = jsonDecode(local) as Map<String, dynamic>;
        globalUsers = decoded
            .map((k, v) => MapEntry(k, Map<String, String>.from(v as Map)));
      }

      final res = await html.HttpRequest.request(
        '$firestoreBaseUrl/users?key=$firestoreApiKey',
        method: 'GET',
      );
      if (res.status == 200 && res.responseText != null) {
        final body = jsonDecode(res.responseText!);
        final jsonStr = body['fields']?['data']?['stringValue'];
        if (jsonStr != null && jsonStr.isNotEmpty) {
          final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
          globalUsers = decoded
              .map((k, v) => MapEntry(k, Map<String, String>.from(v as Map)));
          html.window.localStorage['ktng_users_data'] = jsonStr;
        }
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
        const SnackBar(
            content: Text('사번, 성명, 비밀번호를 모두 입력해주세요.'),
            backgroundColor: Colors.redAccent),
      );
      return;
    }

    if (_isSignUpMode) {
      if (pw != _confirmPwController.text.trim()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('비밀번호가 일치하지 않습니다.'),
              backgroundColor: Colors.redAccent),
        );
        return;
      }
      if (globalUsers.containsKey(empId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('이미 등록된 사번입니다.'),
              backgroundColor: Colors.redAccent),
        );
        return;
      }
      globalUsers[empId] = {'name': name, 'password': pw};
      saveAllData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('회원가입 완료! 로그인해주세요.'),
            backgroundColor: Colors.green),
      );
      setState(() {
        _isSignUpMode = false;
        _pwController.clear();
        _confirmPwController.clear();
      });
    } else {
      if (_isAdminMode && _adminCodeController.text.trim() != correctAdminCode) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('관리자 비밀코드가 올바르지 않습니다.'),
              backgroundColor: Colors.redAccent),
        );
        return;
      }
      if (!_isAdminMode) {
        if (!globalUsers.containsKey(empId)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('등록되지 않은 사번입니다.'),
                backgroundColor: Colors.redAccent),
          );
          return;
        }
        final user = globalUsers[empId]!;
        if (user['name'] != name || user['password'] != pw) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('사번, 성명 또는 비밀번호가 일치하지 않습니다.'),
                backgroundColor: Colors.redAccent),
          );
          return;
        }
      }

      try {
        html.window.localStorage['is_logged_in'] = 'true';
        html.window.localStorage['last_emp_id'] = empId;
        html.window.localStorage['last_name'] = name;
        html.window.localStorage['is_admin'] = _isAdminMode.toString();
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
                BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4)),
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
                      style:
                          TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _isSignUpMode ? '신규 사원 계정 등록 (회원가입)' : '근무 스케줄 관리 시스템',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B365D)),
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
                                    color: !_isSignUpMode
                                        ? const Color(0xFF1B365D)
                                        : Colors.transparent,
                                    width: 2.5)),
                          ),
                          child: Text('로그인',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: !_isSignUpMode
                                      ? const Color(0xFF1B365D)
                                      : Colors.grey)),
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
                                    color: _isSignUpMode
                                        ? const Color(0xFF1B365D)
                                        : Colors.transparent,
                                    width: 2.5)),
                          ),
                          child: Text('회원가입',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _isSignUpMode
                                      ? const Color(0xFF1B365D)
                                      : Colors.grey)),
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
                    hintText: '사번을 입력하세요',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '성명 (Name)',
                    hintText: '이름을 입력하세요',
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
                    hintText: '비밀번호를 입력하세요',
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
                      hintText: '비밀번호를 다시 입력하세요',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.check_circle_outline),
                    ),
                  ),
                ],
                if (!_isSignUpMode) ...[
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('관리자 모드로 로그인',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
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
                        hintText: '관리자 코드를 입력하세요',
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(_isSignUpMode ? '신규 계정 회원가입 완료' : '로그인',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
  String _notice =
      "📢 [공지] 오늘부터 3주(21일간) 이내 일정은 통으로 잠금 처리되어 관리자 승인이 필요하며, 4주차부터는 자유롭게 신청/삭제 가능합니다.";
  bool _isSyncing = false;
  List<Map<String, dynamic>> _posts = [];
  DateTime _currentMonth = DateTime.now();
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadLocalStoredData();
    _syncFromFirebase();
  }

  void _loadLocalStoredData() {
    try {
      final savedNotice = html.window.localStorage['ktng_notice'];
      if (savedNotice != null && savedNotice.isNotEmpty) _notice = savedNotice;

      final savedPosts = html.window.localStorage['ktng_bulletin_posts'];
      if (savedPosts != null && savedPosts.isNotEmpty) {
        final decodedPosts = jsonDecode(savedPosts) as List;
        _posts = decodedPosts
            .map((p) => Map<String, dynamic>.from(p as Map))
            .toList();
      }

      final savedData = html.window.localStorage['ktng_schedule_data'];
      if (savedData != null && savedData.isNotEmpty) {
        final decoded = jsonDecode(savedData) as Map<String, dynamic>;
        globalScheduleMap = decoded.map((key, value) {
          final list = (value as List)
              .map((item) => Map<String, String>.from(item as Map))
              .toList();
          return MapEntry(key, list);
        });
      }

      final savedApproval = html.window.localStorage['ktng_approval_data'];
      if (savedApproval != null && savedApproval.isNotEmpty) {
        final decodedApp = jsonDecode(savedApproval) as List;
        globalApprovalRequests = decodedApp
            .map((item) => Map<String, String>.from(item as Map))
            .toList();
      }

      final savedAtt = html.window.localStorage['ktng_attendance_data'];
      if (savedAtt != null && savedAtt.isNotEmpty) {
        final decodedAtt = jsonDecode(savedAtt) as List;
        globalAttendanceRecords = decodedAtt
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }

      final savedUsers = html.window.localStorage['ktng_users_data'];
      if (savedUsers != null && savedUsers.isNotEmpty) {
        final decodedUsers = jsonDecode(savedUsers) as Map<String, dynamic>;
        globalUsers = decodedUsers
            .map((k, v) => MapEntry(k, Map<String, String>.from(v as Map)));
      }

      setState(() {});
    } catch (_) {}
  }

  Future<void> _syncFromFirebase() async {
    setState(() => _isSyncing = true);
    try {
      final schedReq = await html.HttpRequest.request(
        '$firestoreBaseUrl/schedules?key=$firestoreApiKey',
        method: 'GET',
      );
      if (schedReq.status == 200 && schedReq.responseText != null) {
        final body = jsonDecode(schedReq.responseText!);
        final jsonStr = body['fields']?['data']?['stringValue'];
        if (jsonStr != null && jsonStr.isNotEmpty) {
          final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
          globalScheduleMap = decoded.map((k, v) {
            final l = (v as List)
                .map((e) => Map<String, String>.from(e as Map))
                .toList();
            return MapEntry(k, l);
          });
          html.window.localStorage['ktng_schedule_data'] = jsonStr;
        }
      }

      final boardReq = await html.HttpRequest.request(
        '$firestoreBaseUrl/board?key=$firestoreApiKey',
        method: 'GET',
      );
      if (boardReq.status == 200 && boardReq.responseText != null) {
        final body = jsonDecode(boardReq.responseText!);
        final noticeStr = body['fields']?['notice']?['stringValue'];
        final postsStr = body['fields']?['posts']?['stringValue'];

        if (noticeStr != null && noticeStr.isNotEmpty) {
          _notice = noticeStr;
          html.window.localStorage['ktng_notice'] = noticeStr;
        }
        if (postsStr != null && postsStr.isNotEmpty) {
          final decoded = jsonDecode(postsStr) as List;
          _posts = decoded
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          html.window.localStorage['ktng_bulletin_posts'] = postsStr;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isSyncing = false);
  }

  void _confirmDeletePost(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('게시글 삭제 확인'),
        content: const Text('해당 게시글/근무표를 정말로 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                _posts.removeAt(index);
              });
              saveBoardAndNoticeToServer(_notice, _posts);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('게시글이 삭제되었습니다.'), backgroundColor: Colors.redAccent),
              );
            },
            child: const Text('삭제'),
          ),
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

  bool _isWithinThreeWeeks(DateTime targetDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final diffDays = target.difference(today).inDays;
    return diffDays >= 0 && diffDays <= 21;
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
              hintText: '공지할 내용을 작성하세요.', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              final newNotice = controller.text.trim();
              setState(() => _notice = newNotice);
              saveBoardAndNoticeToServer(_notice, _posts);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('공지사항이 중앙 서버에 저장되었습니다.')));
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _openUserManagerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('사원 계정 관리 및 비번 초기화'),
        content: SizedBox(
          width: 400,
          child: globalUsers.isEmpty
              ? const Text('가입된 사원이 없습니다.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: globalUsers.length,
                  itemBuilder: (context, index) {
                    final empId = globalUsers.keys.elementAt(index);
                    final userData = globalUsers[empId]!;
                    return ListTile(
                      title: Text('${userData['name']} ($empId)'),
                      subtitle: Text('비밀번호: ${userData['password']}'),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
        ],
      ),
    );
  }

  void _openCreatePostDialog() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    List<String> selectedImages = [];
    bool isProcessingImages = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('게시글 및 근무표 등록'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                      labelText: '제목', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: contentCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: '내용', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_a_photo),
                  label: Text(selectedImages.isNotEmpty
                      ? '사진 ${selectedImages.length}장 첨부됨'
                      : '사진 첨부하기'),
                  onPressed: isProcessingImages
                      ? null
                      : () {
                          final uploadInput = html.FileUploadInputElement();
                          uploadInput.accept = 'image/*';
                          uploadInput.multiple = true;
                          uploadInput.click();

                          uploadInput.onChange.listen((e) async {
                            final files = uploadInput.files;
                            if (files != null && files.isNotEmpty) {
                              setDialogState(() => isProcessingImages = true);
                              for (var file in files) {
                                try {
                                  final compressed = await compressAndConvertImage(file);
                                  selectedImages.add(compressed);
                                } catch (_) {}
                              }
                              setDialogState(() => isProcessingImages = false);
                            }
                          });
                        },
                ),
                if (isProcessingImages)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ElevatedButton(
              onPressed: isProcessingImages
                  ? null
                  : () {
                      final t = titleCtrl.text.trim();
                      final c = contentCtrl.text.trim();
                      if (t.isEmpty && selectedImages.isEmpty) return;

                      final newPost = {
                        'id': DateTime.now().millisecondsSinceEpoch.toString(),
                        'title': t.isNotEmpty ? t : '근무표 공지',
                        'content': c,
                        'author': widget.userName,
                        'image': selectedImages.isNotEmpty ? selectedImages.first : '',
                        'images': selectedImages,
                        'date':
                            '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
                      };

                      setState(() {
                        _posts.insert(0, newPost);
                      });
                      saveBoardAndNoticeToServer(_notice, _posts);
                      Navigator.pop(ctx);
                    },
              child: const Text('등록'),
            ),
          ],
        ),
      ),
    );
  }

  void _openBulletinScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => BulletinBoardScreen(
          isAdmin: widget.isAdmin,
          userName: widget.userName,
          posts: _posts,
          onPostsUpdated: (updatedPosts) {
            setState(() => _posts = updatedPosts);
            saveBoardAndNoticeToServer(_notice, _posts);
          },
          sendNotification: _sendWebNotification,
        ),
      ),
    );
  }

  void _openVacationMonthlyOverviewScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => MonthlyVacationListScreen(scheduleMap: globalScheduleMap),
      ),
    );
  }

  void _openAttendanceScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => AttendanceManagementScreen(
          isAdmin: widget.isAdmin,
          currentUserName: widget.userName,
          currentEmpId: widget.employeeId,
          onUpdated: () => setState(() {}),
        ),
      ),
    );
  }

  void _openEmergencyApprovalHistoryScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => EmergencyApprovalHistoryScreen(
          isAdmin: widget.isAdmin,
          onUpdated: () {
            setState(() {});
            saveAllData();
          },
          sendNotification: _sendWebNotification,
        ),
      ),
    );
  }

  void _handleDeleteItem(
      String dateKey, Map<String, String> item, bool isLockedThreeWeeks) {
    if (widget.isAdmin || !isLockedThreeWeeks) {
      setState(() => globalScheduleMap[dateKey]?.remove(item));
      saveAllData();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('일정이 삭제되었습니다.')));
    } else {
      final deleteReasonController = TextEditingController();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('🔒 3주 잠금기간 일정 삭제 승인 요청'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: deleteReasonController,
                decoration: const InputDecoration(
                    labelText: '삭제/취소 사유 (필수)', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
            ElevatedButton(
              onPressed: () {
                if (deleteReasonController.text.trim().isEmpty) return;
                final req = {
                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                  'actionType': '삭제요청',
                  'date': dateKey,
                  'empId': widget.employeeId,
                  'empName': widget.userName,
                  'type': item['type'] ?? '삭제',
                  'content': item['content'] ?? '',
                  'reason': deleteReasonController.text.trim(),
                  'requestTime': getCurrentDateTimeString(),
                  'status': '대기중',
                };
                setState(() => globalApprovalRequests.insert(0, req));
                saveAllData();
                Navigator.pop(ctx);
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
          title: Text('지난 근무 기록 ($dateKey)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: shiftTime,
                items: const [
                  DropdownMenuItem(value: "오전 근무", child: Text("오전 근무")),
                  DropdownMenuItem(value: "오후 근무", child: Text("오후 근무")),
                  DropdownMenuItem(value: "주간 근무", child: Text("주간 근무")),
                  DropdownMenuItem(value: "휴무", child: Text("휴무")),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => shiftTime = val);
                },
              ),
              TextField(
                controller: overtimeController,
                decoration: const InputDecoration(labelText: '메모'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ElevatedButton(
              onPressed: () {
                final record = {
                  'empId': widget.employeeId,
                  'empName': widget.userName,
                  'type': '(실제기록)',
                  'content': '$shiftTime ${overtimeController.text}',
                };
                setState(() {
                  globalScheduleMap
                      .putIfAbsent(dateKey, () => [])
                      .removeWhere((item) => item['empId'] == widget.employeeId);
                  globalScheduleMap[dateKey]!.add(record);
                });
                saveAllData();
                Navigator.pop(ctx);
              },
              child: const Text('저장'),
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

    final isWeekend = _selectedDate!.weekday == DateTime.saturday ||
        _selectedDate!.weekday == DateTime.sunday;
    final dateKey = _formatDateKey(_selectedDate!);
    final bool isLockedThreeWeeks = _isWithinThreeWeeks(_selectedDate!);
    final bool requiresApproval = !widget.isAdmin && isLockedThreeWeeks;
    final approvalReasonController = TextEditingController();

    if (isWeekend) {
      String weekendOption = "근무 가능";
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
                  items: const [
                    DropdownMenuItem(value: "근무 가능", child: Text("근무 가능")),
                    DropdownMenuItem(value: "근무 불가능", child: Text("근무 불가능")),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => weekendOption = val);
                  },
                ),
                if (requiresApproval)
                  TextField(
                    controller: approvalReasonController,
                    decoration: const InputDecoration(labelText: '신청 사유 (필수)'),
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
              ElevatedButton(
                onPressed: () {
                  if (requiresApproval && approvalReasonController.text.trim().isEmpty) return;
                  final contentStr = '주말 $weekendOption';
                  if (requiresApproval) {
                    final req = {
                      'id': DateTime.now().millisecondsSinceEpoch.toString(),
                      'actionType': '신청요청',
                      'date': dateKey,
                      'empId': widget.employeeId,
                      'empName': widget.userName,
                      'type': '주말설정',
                      'content': contentStr,
                      'reason': approvalReasonController.text.trim(),
                      'requestTime': getCurrentDateTimeString(),
                      'status': '대기중',
                    };
                    setState(() => globalApprovalRequests.insert(0, req));
                    saveAllData();
                  } else {
                    final record = {
                      'empId': widget.employeeId,
                      'empName': widget.userName,
                      'type': '주말설정',
                      'content': contentStr
                    };
                    setState(() {
                      globalScheduleMap
                          .putIfAbsent(dateKey, () => [])
                          .removeWhere((item) => item['empId'] == widget.employeeId);
                      globalScheduleMap[dateKey]!.add(record);
                    });
                    saveAllData();
                  }
                  Navigator.pop(ctx);
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
      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('근무/휴가 신청 ($dateKey)'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  items: const [
                    DropdownMenuItem(value: "연차", child: Text("연차")),
                    DropdownMenuItem(value: "체력단련", child: Text("체력단련")),
                    DropdownMenuItem(value: "가족사랑", child: Text("가족사랑")),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedCategory = val);
                  },
                ),
                if (requiresApproval)
                  TextField(
                    controller: approvalReasonController,
                    decoration: const InputDecoration(labelText: '신청 사유 (필수)'),
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
              ElevatedButton(
                onPressed: () {
                  if (requiresApproval && approvalReasonController.text.trim().isEmpty) return;
                  final details = "$selectedCategory ($selectedLeaveTime)";
                  if (requiresApproval) {
                    final req = {
                      'id': DateTime.now().millisecondsSinceEpoch.toString(),
                      'actionType': '신청요청',
                      'date': dateKey,
                      'empId': widget.employeeId,
                      'empName': widget.userName,
                      'type': selectedCategory,
                      'content': details,
                      'reason': approvalReasonController.text.trim(),
                      'requestTime': getCurrentDateTimeString(),
                      'status': '대기중',
                    };
                    setState(() => globalApprovalRequests.insert(0, req));
                    saveAllData();
                  } else {
                    final record = {
                      'empId': widget.employeeId,
                      'empName': widget.userName,
                      'type': selectedCategory,
                      'content': details
                    };
                    setState(() {
                      globalScheduleMap
                          .putIfAbsent(dateKey, () => [])
                          .removeWhere((item) => item['empId'] == widget.employeeId);
                      globalScheduleMap[dateKey]!.add(record);
                    });
                    saveAllData();
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('신청'),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildGroupSection({
    required String title,
    required Color color,
    required IconData icon,
    required List<Map<String, String>> items,
    required String selectedKey,
    required bool isLockedThreeWeeks,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(9), topRight: Radius.circular(9))),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: color)),
                ),
              ],
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, idx) {
              final item = items[idx];
              return ListTile(
                dense: true,
                title: Text('${item['empName']} - ${item['content']}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  onPressed: () => _handleDeleteItem(selectedKey, item, isLockedThreeWeeks),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showImageZoomDialog(List<String> images, int initialIndex, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            PageView.builder(
              controller: PageController(initialPage: initialIndex),
              itemCount: images.length,
              itemBuilder: (context, idx) {
                return InteractiveViewer(
                  child: Center(
                    child: Image.network(images[idx], fit: BoxFit.contain),
                  ),
                );
              },
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _extractImagesFromPost(Map<String, dynamic> post) {
    List<String> list = [];
    if (post['images'] != null && post['images'] is List) {
      list = List<String>.from(post['images']);
    } else if (post['image'] != null && (post['image'] as String).isNotEmpty) {
      list.add(post['image']);
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final selectedKey =
        _selectedDate != null ? _formatDateKey(_selectedDate!) : '';
    final rawList = globalScheduleMap[selectedKey] ?? [];
    final displayList = widget.isAdmin
        ? rawList
        : rawList.where((item) => item['empId'] == widget.employeeId).toList();

    final bool isPast =
        _selectedDate != null ? _isPastDate(_selectedDate!) : false;
    final bool isLockedThreeWeeks =
        _selectedDate != null && _isWithinThreeWeeks(_selectedDate!);

    final annualLeaveList =
        displayList.where((i) => i['type'] == '연차').toList();
    final healthTrainList =
        displayList.where((i) => i['type'] == '체력단련').toList();
    final familyLoveList =
        displayList.where((i) => i['type'] == '가족사랑').toList();
    final weekendList =
        displayList.where((i) => i['type'] == '주말설정').toList();
    final othersList = displayList
        .where((i) =>
            i['type'] != '연차' &&
            i['type'] != '체력단련' &&
            i['type'] != '가족사랑' &&
            i['type'] != '주말설정')
        .toList();

    final pendingApprovals = globalApprovalRequests
        .where((r) => r['status'] == '대기중')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.userName} (${widget.isAdmin ? "관리자" : "사원"})'),
        backgroundColor: widget.isAdmin ? Colors.indigo : const Color(0xFF1B365D),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              icon: const Icon(Icons.sync),
              tooltip: '서버 동기화',
              onPressed: _syncFromFirebase),
          IconButton(
              icon: const Icon(Icons.access_time_filled),
              tooltip: '근태 관리',
              onPressed: _openAttendanceScreen),
          IconButton(
              icon: const Icon(Icons.dynamic_feed),
              tooltip: '게시판',
              onPressed: _openBulletinScreen),
          IconButton(
              icon: const Icon(Icons.logout),
              tooltip: '로그아웃',
              onPressed: () {
                html.window.localStorage.remove('is_logged_in');
                Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()));
              }),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.isAdmin && pendingApprovals.isNotEmpty)
              Card(
                color: Colors.deepOrange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('🚨 미처리 긴급승인 (${pendingApprovals.length}건)',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                      TextButton(
                        onPressed: _openEmergencyApprovalHistoryScreen,
                        child: const Text('전체보기'),
                      ),
                    ],
                  ),
                ),
              ),
            Card(
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('📢 공지사항',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        if (widget.isAdmin)
                          IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: _showEditNoticeDialog),
                      ],
                    ),
                    Text(_notice, style: const TextStyle(fontSize: 13, height: 1.35)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('📋 사내 게시판 & 근무표',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: _openBulletinScreen,
                          child: const Text('전체보기 >', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const Divider(height: 12),
                    if (_posts.isEmpty)
                      const Text('등록된 게시글이 없습니다.', style: TextStyle(color: Colors.grey))
                    else
                      ...List.generate(_posts.length > 2 ? 2 : _posts.length, (idx) {
                        final post = _posts[idx];
                        final postImages = _extractImagesFromPost(post);
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text('• ${post['title']}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text('${post['author']} | ${post['date']}',
                              style: const TextStyle(fontSize: 12)),
                          trailing: widget.isAdmin
                              ? IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                  onPressed: () => _confirmDeletePost(idx),
                                )
                              : null,
                          onTap: () {
                            if (postImages.isNotEmpty) {
                              _showImageZoomDialog(postImages, 0, post['title'] ?? '근무표');
                            } else {
                              _openBulletinScreen();
                            }
                          },
                        );
                      }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(() => _currentMonth =
                        DateTime(_currentMonth.year, _currentMonth.month - 1, 1))),
                Text('${_currentMonth.year}년 ${_currentMonth.month}월',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setState(() => _currentMonth =
                        DateTime(_currentMonth.year, _currentMonth.month + 1, 1))),
              ],
            ),
            const SizedBox(height: 6),
            _buildCalendarGrid(),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(widget.isAdmin ? '👥 $selectedKey 전체 사원' : '📅 $selectedKey 내 신청',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: isPast ? _showPastWorkRecordDialog : _showAddWorkDialog,
                      icon: Icon(isPast ? Icons.edit_calendar : Icons.add_task),
                      label: Text(isPast ? '지난 근무 기록' : '근무 / 휴가 신청하기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPast ? Colors.blueGrey : const Color(0xFF1B365D),
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const Divider(height: 24),
                    _buildGroupSection(
                        title: '🌴 연차',
                        color: Colors.blue.shade700,
                        icon: Icons.beach_access,
                        items: annualLeaveList,
                        selectedKey: selectedKey,
                        isLockedThreeWeeks: isLockedThreeWeeks),
                    _buildGroupSection(
                        title: '❤️ 가족사랑',
                        color: Colors.purple.shade600,
                        icon: Icons.family_restroom,
                        items: familyLoveList,
                        selectedKey: selectedKey,
                        isLockedThreeWeeks: isLockedThreeWeeks),
                    _buildGroupSection(
                        title: '💪 체력단련',
                        color: Colors.teal.shade700,
                        icon: Icons.fitness_center,
                        items: healthTrainList,
                        selectedKey: selectedKey,
                        isLockedThreeWeeks: isLockedThreeWeeks),
                    _buildGroupSection(
                        title: '🗓️ 주말설정',
                        color: Colors.indigo.shade700,
                        icon: Icons.weekend,
                        items: weekendList,
                        selectedKey: selectedKey,
                        isLockedThreeWeeks: isLockedThreeWeeks),
                    _buildGroupSection(
                        title: '📝 기타/기록',
                        color: Colors.blueGrey.shade700,
                        icon: Icons.history_edu,
                        items: othersList,
                        selectedKey: selectedKey,
                        isLockedThreeWeeks: isLockedThreeWeeks),
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
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekLabels
                .map((w) => Expanded(
                    child: Center(
                        child: Text(w,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: w == '일' ? Colors.red : (w == '토' ? Colors.blue : Colors.black87))))))
                .toList(),
          ),
          const Divider(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7, childAspectRatio: 1.1),
            itemCount: startWeekday + daysInMonth,
            itemBuilder: (context, index) {
              if (index < startWeekday) return const SizedBox.shrink();
              final dayNum = index - startWeekday + 1;
              final cellDate = DateTime(_currentMonth.year, _currentMonth.month, dayNum);
              final cellKey = _formatDateKey(cellDate);
              final isSelected = _selectedDate != null &&
                  _selectedDate!.year == cellDate.year &&
                  _selectedDate!.month == cellDate.month &&
                  _selectedDate!.day == cellDate.day;
              final allList = globalScheduleMap[cellKey] ?? [];
              final filteredList = widget.isAdmin
                  ? allList
                  : allList.where((item) => item['empId'] == widget.employeeId).toList();
              final isPast = _isPastDate(cellDate);

              return InkWell(
                onTap: () => setState(() => _selectedDate = cellDate),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF1B365D).withOpacity(0.15)
                        : (isPast ? Colors.grey.shade100 : Colors.transparent),
                    border: isSelected
                        ? Border.all(color: const Color(0xFF1B365D), width: 1.5)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$dayNum',
                          style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isPast
                                  ? Colors.grey
                                  : (cellDate.weekday == 7
                                      ? Colors.red
                                      : (cellDate.weekday == 6 ? Colors.blue : Colors.black87)))),
                      if (filteredList.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                              color: const Color(0xFFE35205),
                              borderRadius: BorderRadius.circular(10)),
                          child: Text(widget.isAdmin ? '${filteredList.length}건' : '●',
                              style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
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

class EmergencyApprovalHistoryScreen extends StatefulWidget {
  final bool isAdmin;
  final VoidCallback onUpdated;
  final Function(String title, String body) sendNotification;

  const EmergencyApprovalHistoryScreen(
      {super.key,
      required this.isAdmin,
      required this.onUpdated,
      required this.sendNotification});

  @override
  State<EmergencyApprovalHistoryScreen> createState() => _EmergencyApprovalHistoryScreenState();
}

class _EmergencyApprovalHistoryScreenState extends State<EmergencyApprovalHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('🚨 긴급승인 요청 및 이력 관리'),
          backgroundColor: Colors.deepOrange,
          foregroundColor: Colors.white),
      body: globalApprovalRequests.isEmpty
          ? const Center(child: Text('승인 요청 내역이 없습니다.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: globalApprovalRequests.length,
              itemBuilder: (ctx, idx) {
                final req = globalApprovalRequests[idx];
                final status = req['status'] ?? '대기중';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text('${req['empName']} (${req['empId']}) - [${req['actionType']}]',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('대상: ${req['date']} | 내용: ${req['content']}\n사유: ${req['reason']}'),
                    trailing: Text(status,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: status == '승인완료' ? Colors.green : Colors.orange)),
                  ),
                );
              },
            ),
    );
  }
}

class AttendanceManagementScreen extends StatefulWidget {
  final bool isAdmin;
  final String currentUserName;
  final String currentEmpId;
  final VoidCallback onUpdated;

  const AttendanceManagementScreen(
      {super.key,
      required this.isAdmin,
      required this.currentUserName,
      required this.currentEmpId,
      required this.onUpdated});

  @override
  State<AttendanceManagementScreen> createState() => _AttendanceManagementScreenState();
}

class _AttendanceManagementScreenState extends State<AttendanceManagementScreen> {
  String _searchNameQuery = "";

  void _confirmDeleteAttendance(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('근태 기록 삭제'),
        content: const Text('선택한 사원의 근태 기록을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                globalAttendanceRecords.removeAt(index);
              });
              saveAllData();
              widget.onUpdated();
              Navigator.pop(ctx);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> records = List.from(globalAttendanceRecords);
    if (_searchNameQuery.isNotEmpty) {
      records = records
          .where((r) =>
              (r['name'] ?? '').toString().contains(_searchNameQuery) ||
              (r['empId'] ?? '').toString().contains(_searchNameQuery))
          .toList();
    }
    return Scaffold(
      appBar: AppBar(
          title: const Text('⏰ 근태기록 관리 및 조회'),
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                  hintText: '사원 이름/사번 검색...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder()),
              onChanged: (val) => setState(() => _searchNameQuery = val.trim()),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: records.length,
              itemBuilder: (ctx, idx) {
                final r = records[idx];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text('${r['name']} (${r['empId']}) - ${r['date']}'),
                    subtitle: Text('${r['shiftDetail']} | 메모: ${r['extraNote']}'),
                    trailing: widget.isAdmin
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () => _confirmDeleteAttendance(idx),
                          )
                        : null,
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

class MonthlyVacationListScreen extends StatelessWidget {
  final Map<String, List<Map<String, String>>> scheduleMap;
  const MonthlyVacationListScreen({super.key, required this.scheduleMap});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('🌴 전체 연차/휴가자 월별 현황'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: scheduleMap.entries.map((entry) {
          final list = entry.value;
          if (list.isEmpty) return const SizedBox.shrink();
          return Card(
            child: ExpansionTile(
              title: Text('${entry.key} 휴가 현황 (${list.length}명)',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              children: list.map((item) {
                return ListTile(
                  dense: true,
                  title: Text('${item['empName']} (${item['empId']}) - ${item['type']}'),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class BulletinBoardScreen extends StatefulWidget {
  final bool isAdmin;
  final String userName;
  final List<Map<String, dynamic>> posts;
  final Function(List<Map<String, dynamic>>) onPostsUpdated;
  final Function(String, String) sendNotification;

  const BulletinBoardScreen(
      {super.key,
      required this.isAdmin,
      required this.userName,
      required this.posts,
      required this.onPostsUpdated,
      required this.sendNotification});

  @override
  State<BulletinBoardScreen> createState() => _BulletinBoardScreenState();
}

class _BulletinBoardScreenState extends State<BulletinBoardScreen> {
  void _confirmDeletePostInBulletin(int idx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('게시글 삭제'),
        content: const Text('정말 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              final updated = List<Map<String, dynamic>>.from(widget.posts)..removeAt(idx);
              widget.onPostsUpdated(updated);
              Navigator.pop(ctx);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _showImageZoomDialog(List<String> images, int initialIndex, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            PageView.builder(
              controller: PageController(initialPage: initialIndex),
              itemCount: images.length,
              itemBuilder: (context, idx) {
                return InteractiveViewer(
                  child: Center(
                    child: Image.network(images[idx], fit: BoxFit.contain),
                  ),
                );
              },
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _extractImages(Map<String, dynamic> post) {
    List<String> list = [];
    if (post['images'] != null && post['images'] is List) {
      list = List<String>.from(post['images']);
    } else if (post['image'] != null && (post['image'] as String).isNotEmpty) {
      list.add(post['image']);
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('📋 사내 게시판 & 근무표'),
          backgroundColor: const Color(0xFF1B365D),
          foregroundColor: Colors.white),
      body: widget.posts.isEmpty
          ? const Center(child: Text('등록된 게시글이 없습니다.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: widget.posts.length,
              itemBuilder: (ctx, idx) {
                final post = widget.posts[idx];
                final postImages = _extractImages(post);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(post['title'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            if (widget.isAdmin)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                onPressed: () => _confirmDeletePostInBulletin(idx),
                              ),
                          ],
                        ),
                        Text('${post['author']} | ${post['date']}',
                            style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        if ((post['content'] ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(post['content'] ?? ''),
                          ),
                        if (postImages.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: SizedBox(
                              height: 150,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: postImages.length,
                                itemBuilder: (context, imgIdx) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: InkWell(
                                      onTap: () => _showImageZoomDialog(postImages, imgIdx, post['title'] ?? ''),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.network(postImages[imgIdx], width: 150, fit: BoxFit.cover),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
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

class AllEmployeesOverviewScreen extends StatelessWidget {
  final Map<String, List<Map<String, String>>> scheduleMap;
  final VoidCallback onScheduleUpdated;
  const AllEmployeesOverviewScreen(
      {super.key,
      required this.scheduleMap,
      required this.onScheduleUpdated});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('👥 전체 사원 종합 현황'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: scheduleMap.entries.map((e) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📅 ${e.key}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Divider(),
                  ...e.value.map((item) => Text('• [${item['empName']}] ${item['type']}: ${item['content']}')),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}