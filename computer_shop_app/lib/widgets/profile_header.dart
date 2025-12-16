import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileHeader extends StatefulWidget {
  const ProfileHeader({super.key});

  @override
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader> {
  String _username = "Guest";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Get token
    final token = prefs.getString('access'); 
    
    // 2. Load username immediately from local storage if available
    final savedName = prefs.getString('user_username');
    if (savedName != null && savedName.isNotEmpty) {
      if (mounted) {
        setState(() {
          _username = savedName;
          _isLoading = false; 
        });
      }
    }

    if (token == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Use 127.0.0.1 for Web, 10.0.2.2 for Android Emulator
      final url = Uri.parse('http://127.0.0.1:8000/api/profile-data/');
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token', 
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _username = data['username'] ?? "User";
            _isLoading = false;
          });
        }
      } else {
        print("DEBUG: Failed to fetch profile. Code: ${response.statusCode}");
      }
    } catch (e) {
      print("DEBUG: Error fetching profile: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access');
    await prefs.remove('refresh');
    await prefs.remove('user_username');
    await prefs.remove('user_email');
    
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // If loading and we don't have a local name yet, show spinner
    if (_isLoading && _username == "Guest") {
      return const Padding(
        padding: EdgeInsets.only(right: 16.0),
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF003399)))),
      );
    }

    return PopupMenuButton<String>(
      offset: const Offset(0, 45),
      color: Colors.white, // <--- Set Dropdown Background to White
      onSelected: (value) {
        if (value == 'logout') {
          _logout();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF003399), // <--- Set Button Background to Blue
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              _username,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 18),
          ],
        ),
      ),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        // "Signed in as" section
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Signed in as", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 2),
              Text(
                _username, 
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16)
              ),
              const Divider(),
            ],
          ),
        ),
        // Logout Button
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, color: Colors.red),
              SizedBox(width: 10),
              Text("Logout", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}