import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ollama Chat',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: const ChatScreen(),
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
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  // 1. IP Lokal (WiFi) - Ganti dengan IPv4 laptop Anda (contoh: 192.168.1.15)
  final String _localUrl = "http://192.168.1.27:11434/api/chat";
  
  // 2. URL Internet - Ganti dengan domain Cloudflare Anda
  final String _publicUrl = "https://ollama.zarai.my.id/api/chat";
  
  // 3. Nama model Ollama yang sudah dibuat
  final String _modelName = "gemma4-chatollama";

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final userText = _controller.text;
    _controller.clear();

    setState(() {
      _messages.add({"role": "user", "content": userText});
      _isLoading = true;
    });

    final payload = jsonEncode({
      "model": _modelName,
      "messages": _messages,
      "stream": false,
    });

    try {
      http.Response response;
      try {
        // Percobaan 1: Jaringan WiFi lokal (Batas waktu 3 detik)
        response = await http.post(
          Uri.parse(_localUrl),
          headers: {"Content-Type": "application/json"},
          body: payload,
        ).timeout(const Duration(seconds: 3));
      } catch (e) {
        // Percobaan 2: Fallback ke jaringan internet umum jika WiFi lokal gagal
        response = await http.post(
          Uri.parse(_publicUrl),
          headers: {"Content-Type": "application/json"},
          body: payload,
        );
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final botReply = data['message']['content'];

        setState(() {
          _messages.add({"role": "assistant", "content": botReply});
        });
      } else {
        setState(() {
          _messages.add({
            "role": "assistant",
            "content": "Error: Gagal terhubung ke server (${response.statusCode})"
          });
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({
          "role": "assistant",
          "content": "Error koneksi total. Pastikan laptop menyala dan Ollama aktif."
        });
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundImage: AssetImage('assets/profile.png'), 
            ),
            const SizedBox(width: 10),
            const Text('Asisten AI Lokal'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.deepPurple[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(msg['content'] ?? ''),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Ketik pesan...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.deepPurple),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
