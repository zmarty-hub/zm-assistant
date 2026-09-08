import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ollama Chat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  String _ipAddress = ""; 
  String? _userAvatarBase64;
  final String _modelName = "gemma4-chatollama";

  @override
  void initState() {
    super.initState();
    _loadSettingsAndHistory();
  }

  Future<void> _loadSettingsAndHistory() async {
    final prefs = await SharedPreferences.getInstance();
    
    final String? savedIp = prefs.getString('ollama_ip');
    if (savedIp != null && savedIp.isNotEmpty) {
      setState(() {
        _ipAddress = savedIp;
      });
    }

    final String? savedAvatar = prefs.getString('user_avatar');
    if (savedAvatar != null && savedAvatar.isNotEmpty) {
      setState(() {
        _userAvatarBase64 = savedAvatar;
      });
    }

    final String? historyString = prefs.getString('chat_history');
    if (historyString != null) {
      final List<dynamic> decoded = jsonDecode(historyString);
      setState(() {
        _messages = decoded.map((item) => Map<String, String>.from(item)).toList();
      });
    }
  }

  Future<void> _saveIpAddress(String newIp) async {
    final cleanedIp = newIp
        .replaceAll('http://', '')
        .replaceAll('https://', '')
        .replaceAll('/', '')
        .trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ollama_ip', cleanedIp);
    setState(() {
      _ipAddress = cleanedIp;
    });
  }

  Future<void> _pickAndSaveAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      final base64String = base64Encode(bytes);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_avatar', base64String);
      setState(() {
        _userAvatarBase64 = base64String;
      });
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_history', jsonEncode(_messages));
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('chat_history');
    setState(() {
      _messages.clear();
    });
  }

  void _showIpDialog() {
    final TextEditingController ipController = TextEditingController(text: _ipAddress);
    bool isTesting = false;
    String testStatus = "";
    Color statusColor = Colors.grey;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Atur & Tes IP Laptop'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: ipController,
                decoration: const InputDecoration(
                  hintText: 'Contoh: 192.168.1.15',
                  labelText: 'IPv4 Address Laptop',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 12),
              if (testStatus.isNotEmpty)
                Row(
                  children: [
                    Icon(
                      testStatus.contains('Sukses') ? Icons.check_circle : Icons.error,
                      color: statusColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        testStatus,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              if (isTesting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
           OutlinedButton.icon(
      onPressed: isTesting ? null : () async {
        final rawIp = ipController.text.trim();
        final ip = rawIp
            .replaceAll('http://', '')
            .replaceAll('https://', '')
            .replaceAll('/', '')
            .trim();
            
        if (ip.isEmpty) return;

        setDialogState(() {
          isTesting = true;
          testStatus = "Menghubungkan ke $ip...";
          statusColor = Colors.blue;
        });

        try {
          final response = await http.get(
            Uri.parse('http://$ip:11434/api/tags'),
          ).timeout(const Duration(seconds: 4));

                  if (response.statusCode == 200) {
                    setDialogState(() {
                      testStatus = "Koneksi Sukses! Ollama Aktif ✅";
                      statusColor = Colors.green;
                    });
                  } else {
                    setDialogState(() {
                      testStatus = "Gagal: Kode status ${response.statusCode}";
                      statusColor = Colors.orange;
                    });
                  }
                } catch (e) {
                  setDialogState(() {
                    testStatus = "Koneksi Gagal ❌ (Cek IP, Wi-Fi, atau Firewall)";
                    statusColor = Colors.red;
                  });
                } finally {
                  setDialogState(() {
                    isTesting = false;
                  });
                }
              },
              icon: const Icon(Icons.wifi_find, size: 16),
              label: const Text('Uji Koneksi'),
            ),
            ElevatedButton(
              onPressed: () {
                final newIp = ipController.text.trim();
                if (newIp.isNotEmpty) {
                  _saveIpAddress(newIp);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('IP berhasil disimpan: $newIp')),
                  );
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_ipAddress.isEmpty) {
      _showIpDialog();
      return;
    }

    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    setState(() {
      _messages.add({"role": "user", "content": text});
      _isLoading = true;
    });
    _saveHistory();
    _scrollToBottom();

    final url = "http://$_ipAddress:11434/api/chat";

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "model": _modelName,
          "messages": _messages,
          "stream": false,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final botReply = data['message']['content'] ?? "Tidak ada respons.";
        setState(() {
          _messages.add({"role": "assistant", "content": botReply});
        });
      } else {
        setState(() {
          _messages.add({"role": "assistant", "content": "Error server: ${response.statusCode}"});
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({
          "role": "assistant", 
          "content": "Sistem Error: $e" // <--- Ini akan mencetak alasan pasti kenapa koneksi ditolak
        });
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _saveHistory();
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _pickAndSaveAvatar,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.deepPurple.shade100,
                    backgroundImage: _userAvatarBase64 != null
                        ? MemoryImage(base64Decode(_userAvatarBase64!))
                        : null,
                    child: _userAvatarBase64 == null
                        ? const Icon(Icons.person, color: Colors.deepPurple)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.deepPurple,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, size: 10, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ollama AI Chat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  _ipAddress.isEmpty ? 'Atur IP via ikon ⚙️' : 'IP: $_ipAddress',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Atur IP Laptop',
            onPressed: _showIpDialog,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Hapus Riwayat Chat',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Hapus Riwayat'),
                  content: const Text('Apakah Anda yakin ingin menghapus semua riwayat chat?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () {
                        _clearHistory();
                        Navigator.pop(context);
                      },
                      child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Belum ada percakapan.\nAtur IP laptop Anda via ikon Pengaturan (⚙️) di atas.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _showIpDialog,
                            icon: const Icon(Icons.settings),
                            label: const Text('Set IP Sekarang'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUser = msg['role'] == 'user';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isUser) ...[
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.deepPurple.shade700,
                                child: const Icon(Icons.smart_toy, size: 14, color: Colors.white),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isUser ? Colors.deepPurple : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  msg['content'] ?? '',
                                  style: TextStyle(
                                    color: isUser ? Colors.white : Colors.black87,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            if (isUser) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _pickAndSaveAvatar,
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.deepPurple.shade100,
                                  backgroundImage: _userAvatarBase64 != null
                                      ? MemoryImage(base64Decode(_userAvatarBase64!))
                                      : null,
                                  child: _userAvatarBase64 == null
                                      ? const Icon(Icons.person, size: 14, color: Colors.deepPurple)
                                      : null,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Ketik pesan...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.deepPurple,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
