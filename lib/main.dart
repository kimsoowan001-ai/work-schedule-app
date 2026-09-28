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

// 웹 파일 리더 헬퍼 함수 (단일 파일을 비동기 Data URL로 확실히 변환)
Future<String?> readFileAsDataUrl(html.File file) {
  final completer = Completer<String?>();
  final reader = html.FileReader();
  reader.onLoadEnd.listen((_) {
    completer.complete(reader.result as String?);
  });
  reader.onError.listen((_) {
    completer.complete(null);
  });
  reader.readAsDataUrl(file);
  return completer.future;
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
      final confirmPw = _confirmPwController.text.trim();
      if (pw != confirmPw) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('비밀번호가 일치하지 않습니다. 다시 확인해주세요.'),
              backgroundColor: Colors.redAccent),
        );
        return;
      }

      if (globalUsers.containsKey(empId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('이미 등록된 사번입니다. 본인 계정으로 로그인해주세요.'),
              backgroundColor: Colors.redAccent),
        );
        return;
      }

      globalUsers[empId] = {'name': name, 'password': pw};
      saveAllData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('회원가입이 완료되었습니다! 로그인해주세요.'),
            backgroundColor: Colors.green),
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
            const SnackBar(
                content: Text('관리자 비밀코드가 올바르지 않습니다.'),
                backgroundColor: Colors.redAccent),
          );
          return;
        }
      } else {
        if (!globalUsers.containsKey(empId)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('등록되지 않은 사번입니다. 먼저 [회원가입]을 진행해주세요.'),
                backgroundColor: Colors.redAccent),
          );
          return;
        }

        final user = globalUsers[empId]!;
        if (user['name'] != name) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('사번에 등록된 성명과 일치하지 않습니다. 도용 방지를 위해 접속이 차단됩니다.'),
                backgroundColor: Colors.redAccent),
          );
          return;
        }

        if (user['password'] != pw) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('비밀번호가 일치하지 않습니다.'),
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
  bool _notificationGranted = false;
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
    _safeCheckNotificationPermission();
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
      } catch (_) {}

      try {
        final appReq = await html.HttpRequest.request(
          '$firestoreBaseUrl/approvals?key=$firestoreApiKey',
          method: 'GET',
        );
        if (appReq.status == 200 && appReq.responseText != null) {
          final body = jsonDecode(appReq.responseText!);
          final jsonStr = body['fields']?['data']?['stringValue'];
          if (jsonStr != null && jsonStr.isNotEmpty) {
            final decoded = jsonDecode(jsonStr) as List;
            globalApprovalRequests = decoded
                .map((e) => Map<String, String>.from(e as Map))
                .toList();
            html.window.localStorage['ktng_approval_data'] = jsonStr;
          }
        }
      } catch (_) {}

      try {
        final attReq = await html.HttpRequest.request(
          '$firestoreBaseUrl/attendance?key=$firestoreApiKey',
          method: 'GET',
        );
        if (attReq.status == 200 && attReq.responseText != null) {
          final body = jsonDecode(attReq.responseText!);
          final jsonStr = body['fields']?['data']?['stringValue'];
          if (jsonStr != null && jsonStr.isNotEmpty) {
            final decoded = jsonDecode(jsonStr) as List;
            globalAttendanceRecords = decoded
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
            html.window.localStorage['ktng_attendance_data'] = jsonStr;
          }
        }
      } catch (_) {}

      try {
        final usersReq = await html.HttpRequest.request(
          '$firestoreBaseUrl/users?key=$firestoreApiKey',
          method: 'GET',
        );
        if (usersReq.status == 200 && usersReq.responseText != null) {
          final body = jsonDecode(usersReq.responseText!);
          final jsonStr = body['fields']?['data']?['stringValue'];
          if (jsonStr != null && jsonStr.isNotEmpty) {
            final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
            globalUsers = decoded
                .map((k, v) => MapEntry(k, Map<String, String>.from(v as Map)));
            html.window.localStorage['ktng_users_data'] = jsonStr;
          }
        }
      } catch (_) {}

      try {
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
    } catch (e) {
      debugPrint("서버 동기화 오류: $e");
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _saveBoardToFirebase() async {
    try {
      final postsJson = jsonEncode(_posts);
      html.window.localStorage['ktng_notice'] = _notice;
      html.window.localStorage['ktng_bulletin_posts'] = postsJson;

      await html.HttpRequest.request(
        '$firestoreBaseUrl/board?key=$firestoreApiKey',
        method: 'PATCH',
        requestHeaders: {'Content-Type': 'application/json'},
        sendData: jsonEncode({
          'fields': {
            'notice': {'stringValue': _notice},
            'posts': {'stringValue': postsJson},
          }
        }),
      );
    } catch (e) {
      debugPrint("게시판 서버 저장 오류: $e");
    }
  }

  void _confirmDeletePost(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('게시글 삭제 확인'),
        content: const Text('해당 게시글/근무표를 정말로 삭제하시겠습니까? 삭제 후에는 복구할 수 없습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                _posts.removeAt(index);
              });
              _saveBoardToFirebase();
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

  void _safeCheckNotificationPermission() {
    try {
      if (html.Notification.permission == 'granted') {
        setState(() => _notificationGranted = true);
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
              _saveBoardToFirebase();
              Navigator.pop(ctx);
              _sendWebNotification("📢 [KT&G 공지사항]", newNotice);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('공지사항이 중앙 서버에 저장되었습니다.')));
            },
            child: const Text('저장 및 알림 전송'),
          ),
        ],
      ),
    );
  }

  void _openUserManagerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.manage_accounts, color: Color(0xFF1B365D)),
              SizedBox(width: 8),
              Expanded(
                child: Text('사원 계정 관리 및 비번 초기화',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
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
                        title: Text('${userData['name']} ($empId)',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('비밀번호: ${userData['password']}'),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                          ),
                          onPressed: () {
                            _showEditUserDialog(
                                empId,
                                userData['name'] ?? '',
                                userData['password'] ?? '', () {
                              setDialogState(() {});
                              setState(() {});
                            });
                          },
                          child: const Text('비번수정', style: TextStyle(fontSize: 12)),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
          ],
        ),
      ),
    );
  }

  void _showEditUserDialog(String empId, String currentName, String currentPw,
      VoidCallback onUpdated) {
    final nameEditCtrl = TextEditingController(text: currentName);
    final pwEditCtrl = TextEditingController(text: currentPw);

    showDialog(
      context: context,
      builder: (editCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('사원 정보 수정 ($empId)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameEditCtrl,
              decoration: const InputDecoration(
                  labelText: '성명', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pwEditCtrl,
              decoration: const InputDecoration(
                labelText: '새 비밀번호',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_reset),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(editCtx), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B365D),
                foregroundColor: Colors.white),
            onPressed: () {
              final newName = nameEditCtrl.text.trim();
              final newPw = pwEditCtrl.text.trim();
              if (newName.isEmpty || newPw.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('성명과 비밀번호를 모두 입력하세요.'),
                      backgroundColor: Colors.redAccent),
                );
                return;
              }
              globalUsers[empId] = {'name': newName, 'password': newPw};
              saveAllData();
              onUpdated();
              Navigator.pop(editCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('$empId 사원의 정보가 성공적으로 변경되었습니다.'),
                    backgroundColor: Colors.green),
              );
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  // 안전하고 확실한 여러 장 사진 첨부 지원 모달 (동시 선택 + 누적 추가)
  void _openCreatePostDialog() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    List<String> selectedImages = [];
    bool isProcessingImages = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.campaign, color: Color(0xFF1B365D)),
              SizedBox(width: 8),
              Expanded(
                child: Text('게시글 및 근무표 등록',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                        labelText: '제목 (예: 10월 근무표 공지)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        labelText: '내용 / 안내사항', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 14),

                  // 비동기 병렬 처리 기반 여러 장 사진 첨부 버튼
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(
                          color: selectedImages.isNotEmpty
                              ? Colors.green
                              : const Color(0xFF1B365D)),
                    ),
                    icon: isProcessingImages
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(
                            selectedImages.isNotEmpty
                                ? Icons.add_photo_alternate
                                : Icons.add_a_photo_outlined,
                            color: selectedImages.isNotEmpty
                                ? Colors.green
                                : const Color(0xFF1B365D),
                          ),
                    label: Text(
                      isProcessingImages
                          ? '사진 불러오는 중...'
                          : (selectedImages.isNotEmpty
                              ? '현재 ${selectedImages.length}장 첨부됨 (+ 사진 계속 추가)'
                              : '📷 사진 / 근무표 첨부 (여러 장 선택 가능)'),
                      style: TextStyle(
                          color: selectedImages.isNotEmpty
                              ? Colors.green.shade800
                              : const Color(0xFF1B365D),
                          fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: isProcessingImages
                        ? null
                        : () {
                            final uploadInput = html.FileUploadInputElement();
                            uploadInput.accept = 'image/*';
                            uploadInput.multiple = true; // 여러 장 동시 선택
                            uploadInput.click();

                            uploadInput.onChange.listen((e) async {
                              final files = uploadInput.files;
                              if (files != null && files.isNotEmpty) {
                                setDialogState(() => isProcessingImages = true);

                                // 모든 파일의 Base64 변환을 병렬로 기다림
                                final futures = files.map((f) => readFileAsDataUrl(f)).toList();
                                final results = await Future.wait(futures);

                                setDialogState(() {
                                  for (var res in results) {
                                    if (res != null && res.isNotEmpty) {
                                      selectedImages.add(res);
                                    }
                                  }
                                  isProcessingImages = false;
                                });
                              }
                            });
                          },
                  ),

                  // 첨부된 모든 사진 목록 (가로 썸네일 스크롤 및 개별 삭제)
                  if (selectedImages.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      height: 105,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: selectedImages.length,
                        itemBuilder: (context, idx) {
                          return Container(
                            margin: const EdgeInsets.only(right: 8),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    selectedImages[idx],
                                    width: 85,
                                    height: 85,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: InkWell(
                                    onTap: () {
                                      setDialogState(() {
                                        selectedImages.removeAt(idx);
                                      });
                                    },
                                    child: const CircleAvatar(
                                      radius: 11,
                                      backgroundColor: Colors.black87,
                                      child: Icon(Icons.close, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 2,
                                  left: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      '${idx + 1}',
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B365D),
                foregroundColor: Colors.white,
              ),
              onPressed: isProcessingImages
                  ? null
                  : () {
                      final t = titleCtrl.text.trim();
                      final c = contentCtrl.text.trim();
                      if (t.isEmpty && selectedImages.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('제목 또는 사진을 등록해주세요.'),
                              backgroundColor: Colors.redAccent),
                        );
                        return;
                      }
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
                      _saveBoardToFirebase();
                      _sendWebNotification("📢 [새 게시글/근무표 등록]", t.isNotEmpty ? t : '새 근무표가 등록되었습니다.');
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('근무표/사진 총 ${selectedImages.length}장이 등록되었습니다.'),
                            backgroundColor: Colors.green),
                      );
                    },
              child: const Text('등록 완료'),
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
            _saveBoardToFirebase();
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
        builder: (ctx) =>
            MonthlyVacationListScreen(scheduleMap: globalScheduleMap),
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
    if (widget.isAdmin) {
      setState(() => globalScheduleMap[dateKey]?.remove(item));
      saveAllData();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('일정이 삭제되었습니다.')));
      return;
    }

    if (!isLockedThreeWeeks) {
      setState(() => globalScheduleMap[dateKey]?.remove(item));
      saveAllData();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('3주 잠금기간 이후 일정이 즉시 삭제되었습니다.')));
    } else {
      final deleteReasonController = TextEditingController();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('🔒 3주 잠금기간 일정 삭제 승인 요청'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  '당일부터 총 3주간(21일 이내) 일정의 취소/삭제는 관리자 승인이 필요합니다.',
                  style: TextStyle(fontSize: 13, color: Colors.deepOrange)),
              const SizedBox(height: 12),
              Text('삭제 대상: ${item['content']}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 14),
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
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white),
              onPressed: () {
                if (deleteReasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('삭제 사유를 입력해주세요.')));
                  return;
                }
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
                _sendWebNotification("⚡ [삭제 승인 요청]",
                    "${widget.userName}님이 $dateKey 일정 삭제를 승인 요청했습니다.");
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('관리자에게 삭제 승인 요청이 전송되었습니다.')));
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
                  decoration: const InputDecoration(
                      labelText: '근무 시간대 선택', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: "오전 근무", child: Text("오전 근무 (07:00-15:00)")),
                    DropdownMenuItem(value: "오후 근무", child: Text("오후 근무 (15:00-23:00 / OT 1)")),
                    DropdownMenuItem(
                        value: "주간 근무", child: Text("주간 근무 (08:30-17:30)")),
                    DropdownMenuItem(value: "야간 근무", child: Text("야간 근무 (23:00-07:00 / OT 7)")),
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
                      labelText: '연장 근무 및 비고 메모', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ElevatedButton(
              onPressed: () {
                final note = overtimeController.text.trim();
                final record = {
                  'empId': widget.employeeId,
                  'empName': widget.userName,
                  'type': '(실제기록)',
                  'content':
                      '$shiftTime ${note.isNotEmpty ? ' | 연장/메모: $note' : ''}',
                };
                setState(() {
                  globalScheduleMap
                      .putIfAbsent(dateKey, () => [])
                      .removeWhere((item) => item['empId'] == widget.employeeId);
                  globalScheduleMap[dateKey]!.add(record);
                });
                saveAllData();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('지난 근무 기록이 저장되었습니다.')));
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

    final isWeekend = _selectedDate!.weekday == DateTime.saturday ||
        _selectedDate!.weekday == DateTime.sunday;
    final dateKey = _formatDateKey(_selectedDate!);
    final bool isLockedThreeWeeks = _isWithinThreeWeeks(_selectedDate!);
    final bool requiresApproval = !widget.isAdmin && isLockedThreeWeeks;
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
                  DropdownButtonFormField<String>(
                    value: weekendOption,
                    decoration: const InputDecoration(
                        labelText: '주말 근무 여부', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(
                          value: "근무 가능",
                          child: Text("근무 가능",
                              style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold))),
                      DropdownMenuItem(
                          value: "근무 불가능",
                          child: Text("근무 불가능",
                              style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold))),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => weekendOption = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                      controller: weekendNoteController,
                      decoration: const InputDecoration(
                          labelText: '비고/메모 (선택)', border: OutlineInputBorder())),
                  if (requiresApproval) ...[
                    const SizedBox(height: 12),
                    TextField(
                        controller: approvalReasonController,
                        decoration: const InputDecoration(
                            labelText: '3주 잠금기간 신청 사유 (필수)',
                            border: OutlineInputBorder())),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: requiresApproval
                        ? Colors.deepOrange
                        : const Color(0xFF1B365D)),
                onPressed: () {
                  if (requiresApproval &&
                      approvalReasonController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('신청 사유를 입력해주세요.')));
                    return;
                  }
                  final note = weekendNoteController.text.trim();
                  final contentStr =
                      '주말 $weekendOption ${note.isNotEmpty ? '($note)' : ''}';

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
                    _sendWebNotification("⚡ [승인 요청] 3주 잠금기간 주말 근무",
                        "${widget.userName}님이 $dateKey 주말 설정을 승인 요청했습니다.");
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('관리자에게 승인 요청이 전송되었습니다.')));
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
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('주말 일정이 등록되었습니다.')));
                  }
                },
                child: Text(requiresApproval ? '승인 요청' : '즉시 등록',
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    } else {
      String selectedCategory = "연차";
      String selectedLeaveTime = "8시간";
      List<String> timeOptions = [];
      for (int i = 0; i <= 16; i++) {
        int hours = i ~/ 2;
        int minutes = (i % 2) * 30;
        if (hours == 0 && minutes == 0) {
          timeOptions.add("0시간 (0분)");
        } else if (minutes == 0) {
          timeOptions.add("$hours시간");
        } else if (hours == 0) {
          timeOptions.add("$minutes분");
        } else {
          timeOptions.add("$hours시간 $minutes분");
        }
      }
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
                    decoration: const InputDecoration(
                        labelText: '신청 항목', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: "연차", child: Text("연차")),
                      DropdownMenuItem(value: "체력단련", child: Text("체력단련")),
                      DropdownMenuItem(value: "가족사랑", child: Text("가족사랑")),
                      DropdownMenuItem(value: "건강검진", child: Text("건강검진")),
                      DropdownMenuItem(value: "기타", child: Text("기타")),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedCategory = val);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  if (selectedCategory == "연차") ...[
                    DropdownButtonFormField<String>(
                      value: selectedLeaveTime,
                      decoration: const InputDecoration(
                          labelText: '연차 사용 시간', border: OutlineInputBorder()),
                      items: timeOptions
                          .map((time) =>
                              DropdownMenuItem(value: time, child: Text(time)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedLeaveTime = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (selectedCategory == "기타") ...[
                    TextField(
                        controller: customNoteController,
                        decoration: const InputDecoration(
                            labelText: '기타 사유 입력 (필수)',
                            border: OutlineInputBorder())),
                    const SizedBox(height: 14),
                  ],
                  if (selectedCategory != "기타")
                    TextField(
                        controller: customNoteController,
                        decoration: const InputDecoration(
                            labelText: '비고/메모 (선택)',
                            border: OutlineInputBorder())),
                  if (requiresApproval) ...[
                    const SizedBox(height: 14),
                    TextField(
                        controller: approvalReasonController,
                        decoration: const InputDecoration(
                            labelText: '3주 잠금기간 신청 사유 (필수)',
                            border: OutlineInputBorder())),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: requiresApproval
                        ? Colors.deepOrange
                        : const Color(0xFF1B365D)),
                onPressed: () {
                  if (selectedCategory == "기타" &&
                      customNoteController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('기타 사유를 입력해주세요.')));
                    return;
                  }
                  if (requiresApproval &&
                      approvalReasonController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('신청 사유를 입력해주세요.')));
                    return;
                  }
                  String details = (selectedCategory == "연차")
                      ? "연차 ($selectedLeaveTime)"
                      : ((selectedCategory == "기타")
                          ? "기타 (${customNoteController.text.trim()})"
                          : selectedCategory);
                  if (selectedCategory != "기타" &&
                      customNoteController.text.trim().isNotEmpty) {
                    details += " - ${customNoteController.text.trim()}";
                  }

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
                    _sendWebNotification("⚡ [승인 요청] 3주 잠금기간 휴가/근무",
                        "${widget.userName}님이 $dateKey '$details' 승인을 요청했습니다.");
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('관리자에게 승인 요청이 전송되었습니다.')));
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
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('신청이 정상 등록되었습니다.')));
                  }
                },
                child: Text(requiresApproval ? '승인 요청' : '즉시 신청',
                    style: const TextStyle(color: Colors.white)),
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
                          color: color),
                      overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(12)),
                  child: Text('총 ${items.length}명',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: Colors.grey.shade200),
            itemBuilder: (context, idx) {
              final item = items[idx];
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: color,
                  child: Text(
                      item['empName']!.isNotEmpty ? item['empName']![0] : 'U',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
                title: Text('${item['empName']} (${item['empId']})',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis),
                subtitle: Text(item['content'] ?? '',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade800),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent, size: 20),
                  onPressed: () => _handleDeleteItem(
                      selectedKey, item, isLockedThreeWeeks),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showImageZoomDialog(String base64Img, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppBar(
              title: Text(title, overflow: TextOverflow.ellipsis),
              backgroundColor: const Color(0xFF1B365D),
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                )
              ],
            ),
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.8,
              maxScale: 4.0,
              child: Image.network(
                base64Img,
                fit: BoxFit.contain,
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
    final checkupList =
        displayList.where((i) => i['type'] == '건강검진').toList();
    final weekendList =
        displayList.where((i) => i['type'] == '주말설정').toList();
    final othersList = displayList
        .where((i) =>
            i['type'] != '연차' &&
            i['type'] != '체력단련' &&
            i['type'] != '가족사랑' &&
            i['type'] != '건강검진' &&
            i['type'] != '주말설정')
        .toList();

    final pendingApprovals = globalApprovalRequests
        .where((r) => r['status'] == '대기중')
        .toList();

    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                  color: widget.isAdmin ? Colors.indigo : const Color(0xFF1B365D)),
              accountName: Text(
                  '${widget.userName} (${widget.isAdmin ? "관리자" : "사원"})',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              accountEmail: Text('사번: ${widget.employeeId}'),
            ),
            ListTile(
                leading: const Icon(Icons.calendar_month),
                title: const Text('근무 캘린더 (메인)'),
                onTap: () => Navigator.pop(context)),
            ListTile(
                leading: const Icon(Icons.access_time_filled,
                    color: Colors.blueAccent),
                title: const Text('⏰ 근태기록 관리 및 조회'),
                onTap: () {
                  Navigator.pop(context);
                  _openAttendanceScreen();
                }),
            ListTile(
                leading: const Icon(Icons.date_range, color: Colors.teal),
                title: const Text('🌴 전체 연차/휴가자 월별 현황'),
                onTap: () {
                  Navigator.pop(context);
                  _openVacationMonthlyOverviewScreen();
                }),
            ListTile(
                leading: const Icon(Icons.dynamic_feed, color: Colors.indigo),
                title: const Text('📋 게시판 & 근무표'),
                onTap: () {
                  Navigator.pop(context);
                  _openBulletinScreen();
                }),
            if (widget.isAdmin) ...[
              const Divider(),
              ListTile(
                  leading: const Icon(Icons.manage_accounts, color: Colors.teal),
                  title: const Text('👥 사원 계정 및 비밀번호 관리'),
                  onTap: () {
                    Navigator.pop(context);
                    _openUserManagerDialog();
                  }),
              ListTile(
                  leading: const Icon(Icons.notification_important,
                      color: Colors.deepOrange),
                  title: const Text('🚨 긴급승인 요청 및 이력'),
                  trailing: pendingApprovals.isNotEmpty
                      ? Badge(label: Text('${pendingApprovals.length}'))
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    _openEmergencyApprovalHistoryScreen();
                  }),
              ListTile(
                  leading: const Icon(Icons.people_alt, color: Colors.indigo),
                  title: const Text('전체 사원 신청 종합현황'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (c) => AllEmployeesOverviewScreen(
                                scheduleMap: globalScheduleMap,
                                onScheduleUpdated: () => setState(() {}))));
                  }),
            ],
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('로그아웃',
                  style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                html.window.localStorage.remove('is_logged_in');
                Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()));
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: Text('${widget.userName} (${widget.isAdmin ? "관리자" : "사원"})',
            overflow: TextOverflow.ellipsis),
        backgroundColor: widget.isAdmin ? Colors.indigo : const Color(0xFF1B365D),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              icon: _isSyncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sync),
              tooltip: '서버 동기화',
              onPressed: _syncFromFirebase),
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.manage_accounts),
              tooltip: '사원 계정 및 비밀번호 관리',
              onPressed: _openUserManagerDialog,
            ),
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
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton.extended(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('근무표/글 등록'),
              onPressed: _openCreatePostDialog,
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.isAdmin) ...[
              if (pendingApprovals.isNotEmpty)
                Card(
                  color: Colors.deepOrange.shade50,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.deepOrange, width: 1.5)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.deepOrange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('🚨 미처리 긴급승인 (${pendingApprovals.length}건)',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange, fontSize: 14),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              onPressed: _openEmergencyApprovalHistoryScreen,
                              child: const Text('전체보기 >'),
                            ),
                          ],
                        ),
                        ...pendingApprovals.take(3).map((req) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text('${req['empName']} (${req['empId']}) - ${req['content']}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text(
                                  '대상: ${req['date']} | 신청: ${req['requestTime'] ?? '미기록'}\n사유: ${req['reason']}',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                  style: const TextStyle(fontSize: 12)),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.check_circle, color: Colors.green, size: 22),
                                    tooltip: '승인',
                                    onPressed: () {
                                      setState(() {
                                        req['status'] = '승인완료';
                                        final dKey = req['date']!;
                                        if (req['actionType'] == '삭제요청') {
                                          globalScheduleMap[dKey]?.removeWhere((i) =>
                                              i['empId'] == req['empId'] &&
                                              i['content'] == req['content']);
                                        } else {
                                          globalScheduleMap.putIfAbsent(dKey, () => []).add({
                                            'empId': req['empId']!,
                                            'empName': req['empName']!,
                                            'type': req['type']!,
                                            'content': req['content']!,
                                          });
                                        }
                                      });
                                      saveAllData();
                                      _sendWebNotification("🎉 [승인 완료]", "${req['empName']}님의 일정이 관리자 승인되었습니다.");
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.cancel, color: Colors.red, size: 22),
                                    tooltip: '반려',
                                    onPressed: () {
                                      setState(() => req['status'] = '반려됨');
                                      saveAllData();
                                      _sendWebNotification("⚠️ [요청 반려]", "${req['empName']}님의 승인 요청이 반려되었습니다.");
                                    },
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                ),
              if (pendingApprovals.isNotEmpty) const SizedBox(height: 8),

              Card(
                color: Colors.indigo.shade50,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.manage_accounts, color: Colors.indigo, size: 16),
                          label: const Text('비번관리', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                          onPressed: _openUserManagerDialog,
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.add_photo_alternate, color: Colors.indigo, size: 16),
                          label: const Text('근무표등록', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                          onPressed: _openCreatePostDialog,
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.people, color: Colors.indigo, size: 16),
                          label: const Text('종합현황', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                          onPressed: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (c) => AllEmployeesOverviewScreen(
                                        scheduleMap: globalScheduleMap,
                                        onScheduleUpdated: () => setState(() {}))));
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

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
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                        if (widget.isAdmin)
                          IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: _showEditNoticeDialog),
                      ],
                    ),
                    Text(_notice,
                        style: const TextStyle(fontSize: 13, height: 1.35)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 메인 화면 고정 사내 게시판
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.dynamic_feed, size: 18, color: Color(0xFF1B365D)),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text('📋 사내 게시판 & 근무표',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (widget.isAdmin)
                          TextButton.icon(
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('등록', style: TextStyle(fontSize: 12)),
                            onPressed: _openCreatePostDialog,
                          ),
                        TextButton(
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                          onPressed: _openBulletinScreen,
                          child: const Text('전체보기 >', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const Divider(height: 12),
                    if (_posts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text('등록된 게시글이 없습니다.', style: TextStyle(color: Colors.grey)),
                      )
                    else
                      ...List.generate(_posts.length > 3 ? 3 : _posts.length, (idx) {
                        final post = _posts[idx];
                        final postImages = _extractImagesFromPost(post);

                        return Container(
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                          ),
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: postImages.isNotEmpty
                                ? InkWell(
                                    onTap: () => _showImageZoomDialog(
                                        postImages.first, post['title'] ?? '근무표'),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Stack(
                                        alignment: Alignment.bottomRight,
                                        children: [
                                          Image.network(
                                            postImages.first,
                                            width: 44,
                                            height: 44,
                                            fit: BoxFit.cover,
                                          ),
                                          if (postImages.length > 1)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                                              color: Colors.black54,
                                              child: Text(
                                                '+${postImages.length}',
                                                style: const TextStyle(color: Colors.white, fontSize: 8),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  )
                                : null,
                            title: Row(
                              children: [
                                if (postImages.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4.0),
                                    child: Icon(
                                      postImages.length > 1 ? Icons.photo_library : Icons.image,
                                      size: 14,
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                Expanded(
                                  child: Text('• ${post['title']}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                            subtitle: Text(
                                '${post['author']} | ${post['date']} ${post['content'].isNotEmpty ? "- " + post['content'] : ""}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12)),
                            trailing: widget.isAdmin
                                ? IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                    tooltip: '삭제',
                                    onPressed: () => _confirmDeletePost(idx),
                                  )
                                : null,
                            onTap: () {
                              if (postImages.isNotEmpty) {
                                _showImageZoomDialog(postImages.first, post['title'] ?? '근무표');
                              } else {
                                _openBulletinScreen();
                              }
                            },
                          ),
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
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                              widget.isAdmin
                                  ? '👥 $selectedKey 전체 사원'
                                  : '📅 $selectedKey 내 신청',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (widget.isAdmin)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.access_time, size: 14),
                            label: const Text('근태 관리', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                            onPressed: _openAttendanceScreen,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: isPast
                          ? _showPastWorkRecordDialog
                          : _showAddWorkDialog,
                      icon: Icon(isPast ? Icons.edit_calendar : Icons.add_task),
                      label: Text(isPast
                          ? '지난 근무 기록'
                          : (isLockedThreeWeeks && !widget.isAdmin
                              ? '🚨 3주 잠금기간 긴급 승인 요청'
                              : '근무 / 휴가 신청하기'),
                          overflow: TextOverflow.ellipsis),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: isPast
                              ? Colors.blueGrey
                              : (isLockedThreeWeeks && !widget.isAdmin
                                  ? Colors.deepOrange
                                  : const Color(0xFF1B365D)),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12)),
                    ),
                    const Divider(height: 24),
                    if (widget.isAdmin) ...[
                      _buildGroupSection(
                          title: '🌴 연차 신청자',
                          color: Colors.blue.shade700,
                          icon: Icons.beach_access,
                          items: annualLeaveList,
                          selectedKey: selectedKey,
                          isLockedThreeWeeks: isLockedThreeWeeks),
                      _buildGroupSection(
                          title: '❤️ 가족사랑의 날',
                          color: Colors.purple.shade600,
                          icon: Icons.family_restroom,
                          items: familyLoveList,
                          selectedKey: selectedKey,
                          isLockedThreeWeeks: isLockedThreeWeeks),
                      _buildGroupSection(
                          title: '💪 체력단련 휴가',
                          color: Colors.teal.shade700,
                          icon: Icons.fitness_center,
                          items: healthTrainList,
                          selectedKey: selectedKey,
                          isLockedThreeWeeks: isLockedThreeWeeks),
                      _buildGroupSection(
                          title: '🩺 건강검진',
                          color: Colors.orange.shade800,
                          icon: Icons.medical_services,
                          items: checkupList,
                          selectedKey: selectedKey,
                          isLockedThreeWeeks: isLockedThreeWeeks),
                      _buildGroupSection(
                          title: '🗓️ 주말 근무/휴무 설정',
                          color: Colors.indigo.shade700,
                          icon: Icons.weekend,
                          items: weekendList,
                          selectedKey: selectedKey,
                          isLockedThreeWeeks: isLockedThreeWeeks),
                      _buildGroupSection(
                          title: '📝 기타 사유 및 근무 기록',
                          color: Colors.blueGrey.shade700,
                          icon: Icons.history_edu,
                          items: othersList,
                          selectedKey: selectedKey,
                          isLockedThreeWeeks: isLockedThreeWeeks),
                    ] else ...[
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: displayList.length,
                        itemBuilder: (ctx, idx) {
                          final item = displayList[idx];
                          return ListTile(
                            title: Text(
                                '[${item['empName']}] ${item['content']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13),
                                overflow: TextOverflow.ellipsis),
                            subtitle: Text('구분: ${item['type']}', style: const TextStyle(fontSize: 12)),
                            trailing: IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.redAccent, size: 20),
                                onPressed: () => _handleDeleteItem(
                                    selectedKey, item, isLockedThreeWeeks)),
                          );
                        },
                      ),
                    ],
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
    final firstDayOfMonth =
        DateTime(_currentMonth.year, _currentMonth.month, 1);
    final daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
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
                                color: w == '일'
                                    ? Colors.red
                                    : (w == '토'
                                        ? Colors.blue
                                        : Colors.black87))))))
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
              final cellDate = DateTime(
                  _currentMonth.year, _currentMonth.month, dayNum);
              final cellKey = _formatDateKey(cellDate);
              final isSelected = _selectedDate != null &&
                  _selectedDate!.year == cellDate.year &&
                  _selectedDate!.month == cellDate.month &&
                  _selectedDate!.day == cellDate.day;
              final allList = globalScheduleMap[cellKey] ?? [];
              final filteredList = widget.isAdmin
                  ? allList
                  : allList
                      .where((item) => item['empId'] == widget.employeeId)
                      .toList();
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
                        ? Border.all(
                            color: const Color(0xFF1B365D), width: 1.5)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$dayNum',
                          style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isPast
                                  ? Colors.grey
                                  : (cellDate.weekday == 7
                                      ? Colors.red
                                      : (cellDate.weekday == 6
                                          ? Colors.blue
                                          : Colors.black87)))),
                      if (filteredList.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                              color: const Color(0xFFE35205),
                              borderRadius: BorderRadius.circular(10)),
                          child: Text(
                              widget.isAdmin
                                  ? '${filteredList.length}건'
                                  : '●',
                              style: const TextStyle(
                                  fontSize: 8,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
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
  State<EmergencyApprovalHistoryScreen> createState() =>
      _EmergencyApprovalHistoryScreenState();
}

class _EmergencyApprovalHistoryScreenState
    extends State<EmergencyApprovalHistoryScreen> {
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
                    title: Text(
                        '${req['empName']} (${req['empId']}) - [${req['actionType']}]',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('대상 근무일: ${req['date']} | 내용: ${req['content']}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text('신청 접수일시: ${req['requestTime'] ?? '시간 기록 없음'}',
                              style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
                          Text('신청 사유: ${req['reason']}', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(status,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: status == '승인완료'
                                    ? Colors.green
                                    : (status == '반려됨'
                                        ? Colors.red
                                        : Colors.orange))),
                        if (widget.isAdmin && status == '대기중') ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.check_circle,
                                color: Colors.green),
                            tooltip: '승인',
                            onPressed: () {
                              setState(() {
                                req['status'] = '승인완료';
                                final dKey = req['date']!;
                                if (req['actionType'] == '삭제요청') {
                                  globalScheduleMap[dKey]?.removeWhere((i) =>
                                      i['empId'] == req['empId'] &&
                                      i['content'] == req['content']);
                                } else {
                                  globalScheduleMap
                                      .putIfAbsent(dKey, () => [])
                                      .add({
                                    'empId': req['empId']!,
                                    'empName': req['empName']!,
                                    'type': req['type']!,
                                    'content': req['content']!,
                                  });
                                }
                              });
                              saveAllData();
                              widget.onUpdated();
                              widget.sendNotification("🎉 [승인 완료]",
                                  "${req['empName']}님의 ${req['date']} 일정이 관리자 승인되었습니다.");
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            tooltip: '반려',
                            onPressed: () {
                              setState(() => req['status'] = '반려됨');
                              saveAllData();
                              widget.onUpdated();
                              widget.sendNotification("⚠️ [요청 반려]",
                                  "${req['empName']}님의 ${req['date']} 승인 요청이 반려되었습니다.");
                            },
                          ),
                        ],
                      ],
                    ),
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
  State<AttendanceManagementScreen> createState() =>
      _AttendanceManagementScreenState();
}

class _AttendanceManagementScreenState
    extends State<AttendanceManagementScreen> {
  String _searchNameQuery = "";

  void _openAddAttendanceDialog() {
    final employeesInputController = TextEditingController();
    final extraNoteController = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now();
    String selectedShift = "주간";

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          String sDateStr =
              "${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}";
          String eDateStr =
              "${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}";
          final isSameDay = startDate.year == endDate.year &&
              startDate.month == endDate.month &&
              startDate.day == endDate.day;

          return AlertDialog(
            title: const Text('⏰ 사원 근태기록 일괄 등록'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                        controller: employeesInputController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                            labelText: '사원 목록 (사번 성명 줄바꿈)',
                            hintText: '예:\n20190416 김수완\n20200101 홍길동',
                            border: OutlineInputBorder())),
                    const SizedBox(height: 14),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('📅 근무 기간 설정 (시작일 ~ 종료일)',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () async {
                              final pickedRange = await showDateRangePicker(
                                context: context,
                                initialDateRange: DateTimeRange(
                                  start: startDate,
                                  end: endDate,
                                ),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                                helpText: '근무 등록 기간을 드래그/선택하세요',
                                saveText: '선택완료',
                              );
                              if (pickedRange != null) {
                                setDialogState(() {
                                  startDate = pickedRange.start;
                                  endDate = pickedRange.end;
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade300),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.date_range,
                                      color: Color(0xFF1B365D), size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      isSameDay
                                          ? '$sDateStr (하루)'
                                          : '$sDateStr ~ $eDateStr',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF1B365D)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Text('날짜선택 >',
                                      style: TextStyle(
                                          color: Colors.blueAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact),
                              icon: const Icon(Icons.today, size: 14),
                              label: const Text('오늘 하루로 맞춤',
                                  style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                final now = DateTime.now();
                                setDialogState(() {
                                  startDate = now;
                                  endDate = now;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    DropdownButtonFormField<String>(
                      value: selectedShift,
                      decoration: const InputDecoration(
                          labelText: '근무 시간대 선택', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(
                            value: "주간",
                            child: Text("주간 (08:30-17:30 / 주간근무)")),
                        DropdownMenuItem(
                            value: "오전", child: Text("오전 (07:00-15:00)")),
                        DropdownMenuItem(
                            value: "오후",
                            child: Text("오후 (15:00-23:00 / OT 1)")),
                        DropdownMenuItem(
                            value: "야간",
                            child: Text("야간 (23:00-07:00 / OT 7)")),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedShift = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                        controller: extraNoteController,
                        decoration: const InputDecoration(
                            labelText: '기타 추가 근무 메모 (선택)',
                            border: OutlineInputBorder())),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B365D),
                    foregroundColor: Colors.white),
                onPressed: () {
                  final rawInput = employeesInputController.text.trim();
                  final note = extraNoteController.text.trim();
                  if (rawInput.isEmpty) return;

                  final lines = rawInput.split(RegExp(r'[\r\n,]+'));
                  final List<Map<String, dynamic>> newEntries = [];
                  DateTime cur =
                      DateTime(startDate.year, startDate.month, startDate.day);
                  final endLimit =
                      DateTime(endDate.year, endDate.month, endDate.day);
                  int counter = 0;

                  while (!cur.isAfter(endLimit)) {
                    final isWeekendDay = cur.weekday == DateTime.saturday ||
                        cur.weekday == DateTime.sunday;
                    final dateKey =
                        "${cur.year}-${cur.month.toString().padLeft(2, '0')}-${cur.day.toString().padLeft(2, '0')}";
                    final actualShift = isWeekendDay ? "주말" : selectedShift;

                    String actualShiftDetail = "";
                    if (isWeekendDay) {
                      actualShiftDetail = "주말근무";
                    } else {
                      if (selectedShift == "주간") {
                        actualShiftDetail = "08:30-17:30 (주간근무)";
                      } else if (selectedShift == "오전") {
                        actualShiftDetail = "07:00-15:00";
                      } else if (selectedShift == "오후") {
                        actualShiftDetail = "15:00-23:00 (OT 1)";
                      } else if (selectedShift == "야간") {
                        actualShiftDetail = "23:00-07:00 (OT 7)";
                      } else {
                        actualShiftDetail = "$selectedShift 근무";
                      }
                    }

                    for (var line in lines) {
                      final tokens = line.trim().split(RegExp(r'\s+'));
                      if (tokens.isNotEmpty && tokens[0].isNotEmpty) {
                        final empId = tokens[0];
                        final name = tokens.length > 1
                            ? tokens.sublist(1).join(' ')
                            : tokens[0];
                        newEntries.add({
                          'id':
                              "${DateTime.now().millisecondsSinceEpoch}_${counter++}",
                          'empId': empId,
                          'name': name,
                          'date': dateKey,
                          'shift': actualShift,
                          'shiftDetail': actualShiftDetail,
                          'extraNote': note,
                        });
                      }
                    }
                    cur = cur.add(const Duration(days: 1));
                  }

                  setState(() => globalAttendanceRecords.addAll(newEntries));
                  saveAllData();
                  widget.onUpdated();
                  Navigator.pop(ctx);
                },
                child: const Text('등록'),
              ),
            ],
          );
        },
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
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton(
              onPressed: _openAddAttendanceDialog,
              child: const Icon(Icons.add))
          : null,
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
                final shift = r['shift'] ?? '주간';
                Color shiftColor = Colors.teal;
                if (shift == "주간") shiftColor = Colors.teal.shade700;
                if (shift == "오전") shiftColor = Colors.orange;
                if (shift == "오후") shiftColor = Colors.purple;
                if (shift == "야간") shiftColor = Colors.indigo;
                if (shift == "주말") shiftColor = Colors.deepOrange;

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: shiftColor,
                      child: Text(
                        shift.length > 2 ? shift.substring(0, 2) : shift,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text('${r['name']} (${r['empId']}) - ${r['date']}',
                        overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                        '${r['shiftDetail']} | 메모: ${r['extraNote']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis),
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
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              title: Text('${entry.key} 휴가 현황 (${list.length}명)',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              children: list.map((item) {
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.person, color: Colors.teal),
                  title: Text('${item['empName']} (${item['empId']})'),
                  subtitle: Text('${item['type']} - ${item['content']}'),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// 7. 게시판 & 근무표 (다중 사진 리스트 및 확대 뷰어 지원)
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
  void _openCreatePostDialog() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    List<String> selectedImages = [];
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.campaign, color: Color(0xFF1B365D)),
              SizedBox(width: 8),
              Text('게시글 및 근무표 등록',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                        labelText: '제목 (예: 10월 근무표 공지)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        labelText: '내용 / 안내사항', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 14),

                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(
                          color: selectedImages.isNotEmpty
                              ? Colors.green
                              : const Color(0xFF1B365D)),
                    ),
                    icon: isProcessing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(
                            selectedImages.isNotEmpty
                                ? Icons.add_photo_alternate
                                : Icons.add_a_photo_outlined,
                            color: selectedImages.isNotEmpty
                                ? Colors.green
                                : const Color(0xFF1B365D),
                          ),
                    label: Text(
                      isProcessing
                          ? '사진 불러오는 중...'
                          : (selectedImages.isNotEmpty
                              ? '현재 ${selectedImages.length}장 첨부됨 (+ 사진 계속 추가)'
                              : '📷 사진 / 근무표 첨부 (여러 장 선택 가능)'),
                      style: TextStyle(
                          color: selectedImages.isNotEmpty
                              ? Colors.green.shade800
                              : const Color(0xFF1B365D),
                          fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: isProcessing
                        ? null
                        : () {
                            final uploadInput = html.FileUploadInputElement();
                            uploadInput.accept = 'image/*';
                            uploadInput.multiple = true;
                            uploadInput.click();

                            uploadInput.onChange.listen((e) async {
                              final files = uploadInput.files;
                              if (files != null && files.isNotEmpty) {
                                setDialogState(() => isProcessing = true);
                                final futures = files.map((f) => readFileAsDataUrl(f)).toList();
                                final results = await Future.wait(futures);

                                setDialogState(() {
                                  for (var res in results) {
                                    if (res != null && res.isNotEmpty) {
                                      selectedImages.add(res);
                                    }
                                  }
                                  isProcessing = false;
                                });
                              }
                            });
                          },
                  ),
                  if (selectedImages.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      height: 105,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: selectedImages.length,
                        itemBuilder: (context, idx) {
                          return Container(
                            margin: const EdgeInsets.only(right: 8),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    selectedImages[idx],
                                    width: 85,
                                    height: 85,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: InkWell(
                                    onTap: () {
                                      setDialogState(() {
                                        selectedImages.removeAt(idx);
                                      });
                                    },
                                    child: const CircleAvatar(
                                      radius: 11,
                                      backgroundColor: Colors.black87,
                                      child: Icon(Icons.close, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 2,
                                  left: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      '${idx + 1}',
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B365D),
                foregroundColor: Colors.white,
              ),
              onPressed: isProcessing
                  ? null
                  : () {
                      final t = titleCtrl.text.trim();
                      final c = contentCtrl.text.trim();
                      if (t.isEmpty && selectedImages.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('제목 또는 사진을 등록해주세요.'),
                              backgroundColor: Colors.redAccent),
                        );
                        return;
                      }
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
                      final updated = List<Map<String, dynamic>>.from(widget.posts)
                        ..insert(0, newPost);
                      widget.onPostsUpdated(updated);
                      widget.sendNotification("📢 [새 게시글/근무표 등록]", t.isNotEmpty ? t : '새 근무표가 등록되었습니다.');
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('근무표/사진 총 ${selectedImages.length}장이 등록되었습니다.'),
                            backgroundColor: Colors.green),
                      );
                    },
              child: const Text('등록 완료'),
            ),
          ],
        ),
      ),
    );
  }

  void _showZoomDialog(String base64Img, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppBar(
              title: Text(title, overflow: TextOverflow.ellipsis),
              backgroundColor: const Color(0xFF1B365D),
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                )
              ],
            ),
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.8,
              maxScale: 4.0,
              child: Image.network(
                base64Img,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePostInBulletin(int idx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('게시글 삭제'),
        content: const Text('해당 게시글/근무표를 정말 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              final updated = List<Map<String, dynamic>>.from(widget.posts)..removeAt(idx);
              widget.onPostsUpdated(updated);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('게시글이 성공적으로 삭제되었습니다.'), backgroundColor: Colors.redAccent),
              );
            },
            child: const Text('삭제'),
          ),
        ],
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
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF1B365D),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('근무표/글 작성'),
              onPressed: _openCreatePostDialog,
            )
          : null,
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
                            Expanded(
                              child: Text(post['title'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (widget.isAdmin)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                                tooltip: '게시글 삭제',
                                onPressed: () => _confirmDeletePostInBulletin(idx),
                              ),
                          ],
                        ),
                        Text('${post['author']} | ${post['date']}',
                            style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        if ((post['content'] ?? '').isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(post['content'] ?? '', style: const TextStyle(fontSize: 14)),
                        ],

                        // 여러 장 사진 렌더링
                        if (postImages.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            height: postImages.length == 1 ? 220 : 160,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: postImages.length,
                              itemBuilder: (context, imgIdx) {
                                return Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  child: InkWell(
                                    onTap: () => _showZoomDialog(
                                        postImages[imgIdx],
                                        '${post['title'] ?? "근무표"} (${imgIdx + 1}/${postImages.length})'),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Stack(
                                        alignment: Alignment.bottomRight,
                                        children: [
                                          Image.network(
                                            postImages[imgIdx],
                                            fit: BoxFit.cover,
                                            height: double.infinity,
                                            errorBuilder: (ctx, err, stack) =>
                                                const SizedBox(
                                                  width: 120,
                                                  child: Center(child: Text('이미지 오류')),
                                                ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                            margin: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.zoom_in, color: Colors.white, size: 12),
                                                SizedBox(width: 2),
                                                Text('확대', style: TextStyle(color: Colors.white, fontSize: 10)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
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
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📅 ${e.key}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const Divider(),
                  ...e.value.map((item) => Text(
                      '• [${item['empName']}] ${item['type']}: ${item['content']}')),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}