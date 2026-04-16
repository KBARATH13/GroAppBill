import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../widgets/vibrant_background.dart';
import '../widgets/glass_container.dart';

enum UserRole { admin, operator }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  UserRole _selectedRole = UserRole.admin;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isLoginTab = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _adminEmailController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields.');
      return;
    }
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await AuthService.signIn(
        email: _emailController.text,
        password: _passwordController.text,
        isAdmin: _selectedRole == UserRole.admin,
        adminEmail: _selectedRole == UserRole.operator ? _adminEmailController.text : null,
      );
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRegister() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields.');
      return;
    }
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await AuthService.signUp(
        email: _emailController.text,
        password: _passwordController.text,
        isAdmin: _selectedRole == UserRole.admin,
        adminEmail: _selectedRole == UserRole.operator ? _adminEmailController.text : null,
      );
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white70),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent, // Required for VibrantBackground
      extendBodyBehindAppBar: true,
      body: VibrantBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  const Icon(Icons.storefront_outlined, size: 64, color: Colors.white),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'AVS Billing',
                      style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // Main Login Form Card
                  GlassContainer(
                    color: Colors.white.withOpacity(0.12),
                    padding: const EdgeInsets.all(24),
                    borderRadius: 24,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Role Toggle using exactly the same logic as Cart Tabs / Categories
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                child: GestureDetector(
                                  onTap: () => setState(() { _selectedRole = UserRole.admin; _errorMessage = null; }),
                                  child: GlassContainer(
                                    color: _selectedRole == UserRole.admin ? scheme.primary.withOpacity(0.4) : Colors.white.withOpacity(0.12),
                                    borderRadius: 12,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    child: Center(
                                      child: Text(
                                        'Admin',
                                        style: TextStyle(
                                          fontWeight: _selectedRole == UserRole.admin ? FontWeight.bold : FontWeight.normal,
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                child: GestureDetector(
                                  onTap: () => setState(() { _selectedRole = UserRole.operator; _errorMessage = null; }),
                                  child: GlassContainer(
                                    color: _selectedRole == UserRole.operator ? scheme.primary.withOpacity(0.4) : Colors.white.withOpacity(0.12),
                                    borderRadius: 12,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    child: Center(
                                      child: Text(
                                        'Operator',
                                        style: TextStyle(
                                          fontWeight: _selectedRole == UserRole.operator ? FontWeight.bold : FontWeight.normal,
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Tab Toggle (Login / Register) with exact same logic
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () => setState(() { _isLoginTab = true; _errorMessage = null; }),
                              child: GlassContainer(
                                color: _isLoginTab ? scheme.primary.withOpacity(0.4) : Colors.white.withOpacity(0.0),
                                borderRadius: 12,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Center(
                                  child: Text(
                                    'Login',
                                    style: TextStyle(
                                      fontWeight: _isLoginTab ? FontWeight.bold : FontWeight.normal,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () => setState(() { _isLoginTab = false; _errorMessage = null; }),
                              child: GlassContainer(
                                color: !_isLoginTab ? scheme.primary.withOpacity(0.4) : Colors.white.withOpacity(0.0),
                                borderRadius: 12,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Center(
                                  child: Text(
                                    'Register',
                                    style: TextStyle(
                                      fontWeight: !_isLoginTab ? FontWeight.bold : FontWeight.normal,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
              
                        // Inputs
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email',
                          icon: Icons.email_outlined,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _passwordController,
                          label: 'Password',
                          icon: Icons.lock_outline,
                          isPassword: true,
                        ),
                        
                        if (!_isLoginTab) ...[
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _confirmPasswordController,
                            label: 'Confirm Password',
                            icon: Icons.lock_reset_outlined,
                            isPassword: true,
                          ),
                        ],
                        
                        if (_selectedRole == UserRole.operator) ...[
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _adminEmailController,
                            label: "Shop Admin's Email",
                            icon: Icons.business_outlined,
                          ),
                        ],
                        
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
                              ],
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 32),
                        
                        // Submit Button using standard theme coloring
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : (_isLoginTab ? _handleLogin : _handleRegister),
                          icon: _isLoading 
                                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                                : const Icon(Icons.login, size: 20),
                          label: Text(_isLoginTab ? 'LOGIN' : 'REGISTER'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: scheme.primary.withOpacity(0.7), // matching settings screen buttons
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
