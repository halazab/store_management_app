import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({Key? key, required this.email}) : super(key: key);

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final List<TextEditingController> _codeControllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  final AuthService _authService = AuthService();

  bool _isVerifying = false;
  bool _isResending = false;
  int _remainingSeconds = 600; // 10 minutes
  Timer? _timer;

  double _yOffset = 80;
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();

    // Animation
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() {
        _yOffset = 0;
        _opacity = 1;
      });
    });

    // Auto-focus and auto-advance logic
    for (int i = 0; i < _codeControllers.length; i++) {
      _codeControllers[i].addListener(() {
        if (_codeControllers[i].text.isNotEmpty && i < _focusNodes.length - 1) {
          FocusScope.of(context).requestFocus(_focusNodes[i + 1]);
        }
      });
    }

    // Auto-focus first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).requestFocus(_focusNodes[0]);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _codeControllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  String _getEnteredCode() {
    return _codeControllers.map((c) => c.text).join();
  }

  void _showSnackBar(String msg, {Color background = Colors.redAccent}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: background),
    );
  }

  Future<void> _verifyEmail() async {
    final otp = _getEnteredCode();
    if (otp.length < 4) {
      _showSnackBar('Please enter all 4 digits');
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final success = await _authService.verifyEmail(widget.email, otp);
      if (!mounted) return;

      if (success) {
        _showSnackBar('Email verified successfully! You can now log in.', background: Colors.green);
        // Navigate to login screen
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } else {
        _showSnackBar('Invalid or expired code. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Verification failed: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resendCode() async {
    setState(() => _isResending = true);

    try {
      final success = await _authService.resendVerificationCode(widget.email);
      if (!mounted) return;

      if (success) {
        _showSnackBar('New code sent! Please check your email.', background: Colors.green);
        // Reset timer
        setState(() => _remainingSeconds = 600);
        _timer?.cancel();
        _startTimer();
        // Clear input fields
        for (var controller in _codeControllers) {
          controller.clear();
        }
        FocusScope.of(context).requestFocus(_focusNodes[0]);
      } else {
        _showSnackBar('Failed to resend code. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cardWidth = MediaQuery.of(context).size.width < 420
        ? MediaQuery.of(context).size.width * 0.92
        : 380.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _yOffset, 0),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 600),
            opacity: _opacity,
            child: Container(
              width: cardWidth,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 15,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                    color: Colors.black.withOpacity(0.08),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Verify your email',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF003399),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'We sent a code to ${widget.email}',
                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // OTP Input boxes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      4,
                      (i) => SizedBox(
                        width: 60,
                        height: 60,
                        child: TextField(
                          controller: _codeControllers[i],
                          focusNode: _focusNodes[i],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            counterText: "",
                            fillColor: Colors.grey[100],
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFF003399),
                                width: 2,
                              ),
                            ),
                          ),
                          onChanged: (value) {
                            if (value.isNotEmpty && i < _focusNodes.length - 1) {
                              FocusScope.of(context).requestFocus(_focusNodes[i + 1]);
                            } else if (value.isEmpty && i > 0) {
                              FocusScope.of(context).requestFocus(_focusNodes[i - 1]);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Timer
                  Text(
                    'Code expires in ${_formatTime(_remainingSeconds)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: _remainingSeconds < 60 ? Colors.red : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Verify button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (_isVerifying || _remainingSeconds == 0) ? null : _verifyEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF003399),
                        disabledBackgroundColor: const Color(0xFF003399).withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isVerifying
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Verify Email',
                              style: TextStyle(fontSize: 16, color: Colors.white),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Resend code link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Didn't receive the code?"),
                      TextButton(
                        onPressed: _isResending ? null : _resendCode,
                        child: _isResending
                            ? const SizedBox(
                                height: 12,
                                width: 12,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
                                "Resend",
                                style: TextStyle(color: Color(0xFF003399)),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Back to login
                  TextButton(
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (route) => false,
                    ),
                    child: const Text(
                      "Back to login",
                      style: TextStyle(color: Color(0xFF003399)),
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
