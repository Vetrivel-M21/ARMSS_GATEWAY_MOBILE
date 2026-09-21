import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/mobile_installer_verification_service.dart';

class MobileInstallerVerificationScreen extends StatefulWidget {
  final VoidCallback onVerified;

  const MobileInstallerVerificationScreen({
    super.key,
    required this.onVerified,
  });

  @override
  State<MobileInstallerVerificationScreen> createState() =>
      _MobileInstallerVerificationScreenState();
}

enum _Step { identity, otp, password }

class _MobileInstallerVerificationScreenState
    extends State<MobileInstallerVerificationScreen> {
  final _service = MobileInstallerVerificationService();

  _Step _currentStep = _Step.identity;
  bool _isLoading = false;
  String? _errorMessage;

  // Step 1 controllers
  final _usernameController = TextEditingController();
  final _deptController = TextEditingController();
  final _branchController = TextEditingController();

  // Step 2 controllers
  final _otpController = TextEditingController();
  String? _requestId;

  // Step 3 controllers
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  int? _verifiedUserId;

  @override
  void dispose() {
    _usernameController.dispose();
    _deptController.dispose();
    _branchController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRequestOtp() async {
    final username = _usernameController.text.trim();
    final dept = _deptController.text.trim();
    final branch = _branchController.text.trim();

    if (username.isEmpty || dept.isEmpty || branch.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill in all fields (User, Department, Branch).';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final reqId = await _service.requestOtp(
        username: username,
        department: dept,
        branch: branch,
      );
      setState(() {
        _requestId = reqId;
        _currentStep = _Step.otp;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _handleVerifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length < 6) {
      setState(() {
        _errorMessage = 'Please enter the complete 6-digit OTP.';
      });
      return;
    }

    if (_requestId == null) {
      setState(() {
        _currentStep = _Step.identity;
        _errorMessage = 'Session expired. Please request OTP again.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final valid = await _service.verifyOtp(
        requestId: _requestId!,
        otp: otp,
      );

      if (valid) {
        setState(() {
          _currentStep = _Step.password;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Invalid OTP code. Please check and try again.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _handleVerifyPassword() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the installer password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = await _service.verifyPassword(password: password);
      _verifiedUserId = userId;

      // Complete installation & self-register device
      await _service.completeVerification(userId: _verifiedUserId);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      // Show success snackbar and trigger callback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF059669),
          content: Text('Installation successfully verified! Welcome to ARMSS Gateway.'),
        ),
      );

      widget.onVerified();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF0F4F8),
              Color(0xFFE2E8F0),
              Color(0xFFF8FAFC),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Brand Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                            blurRadius: 20,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/login_logo.png',
                        height: 70,
                        width: 70,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'ARMSS Gateway',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'First-Time Installation Security Gate',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Step Indicator Row
                    _buildStepIndicator(),
                    const SizedBox(height: 20),

                    // Active Step Card
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: AppColors.surfacePanel,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        border: Border.all(
                          color: AppColors.lineHairline,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_currentStep == _Step.identity) _buildIdentityStep(),
                          if (_currentStep == _Step.otp) _buildOtpStep(),
                          if (_currentStep == _Step.password) _buildPasswordStep(),

                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded,
                                      color: Color(0xFFEF4444), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: Color(0xFFDC2626),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepBadge(1, 'Identity', _currentStep == _Step.identity, _currentStep != _Step.identity),
        _buildStepLine(_currentStep != _Step.identity),
        _buildStepBadge(2, 'OTP', _currentStep == _Step.otp, _currentStep == _Step.password),
        _buildStepLine(_currentStep == _Step.password),
        _buildStepBadge(3, 'Password', _currentStep == _Step.password, false),
      ],
    );
  }

  Widget _buildStepBadge(int number, String label, bool isActive, bool isDone) {
    final color = isDone
        ? const Color(0xFF059669)
        : (isActive ? const Color(0xFF0284C7) : const Color(0xFF9CA3AF));

    return Column(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: color,
          child: isDone
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : Text(
                  '$number',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(bool isDone) {
    return Container(
      width: 32,
      height: 2,
      margin: const EdgeInsets.only(bottom: 16, left: 6, right: 6),
      color: isDone ? const Color(0xFF059669) : AppColors.lineHairline,
    );
  }

  Widget _buildIdentityStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '1. Device Setup Identity',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'An email OTP will be sent to the company administrator to authorize this mobile installation.',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 20),

        TextField(
          controller: _usernameController,
          decoration: InputDecoration(
            labelText: 'Installing User / Employee Name',
            prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF0284C7)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 14),

        TextField(
          controller: _deptController,
          decoration: InputDecoration(
            labelText: 'Department',
            prefixIcon: const Icon(Icons.business_outlined, color: Color(0xFF0284C7)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 14),

        TextField(
          controller: _branchController,
          decoration: InputDecoration(
            labelText: 'Branch',
            prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFF0284C7)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 24),

        ElevatedButton(
          onPressed: _isLoading ? null : _handleRequestOtp,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _isLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Request Admin Email OTP', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '2. Verify Email OTP',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Enter the 6-digit OTP code sent to the company administrator email.',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 20),

        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            counterText: '',
            hintText: '000000',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 20),

        ElevatedButton(
          onPressed: _isLoading ? null : _handleVerifyOtp,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _isLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Verify OTP Code', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ),
        const SizedBox(height: 12),

        TextButton(
          onPressed: _isLoading ? null : () => setState(() => _currentStep = _Step.identity),
          child: const Text('Back to Identity Details'),
        ),
      ],
    );
  }

  Widget _buildPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '3. Installer Password',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Enter the company centralized installer password to authorize and register this device.',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 20),

        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Installer Password',
            prefixIcon: const Icon(Icons.security_rounded, color: Color(0xFF0284C7)),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 24),

        ElevatedButton(
          onPressed: _isLoading ? null : _handleVerifyPassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF059669),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _isLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Authorize & Activate Device', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ),
      ],
    );
  }
}
