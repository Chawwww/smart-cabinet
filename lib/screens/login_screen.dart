import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Navigate to home, clearing all previous routes ──
  void _goHome() => Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );

  // ── Show error snackbar ──────────────────────────────
  void _showError(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );

  // ── Email / Password login ───────────────────────────
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      final ok = await auth.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      if (!mounted) return;
      if (ok) {
        _goHome();
      } else {
        _showError(auth.errorMessage ?? 'Invalid email or password');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Google login ─────────────────────────────────────
  Future<void> _googleLogin() async {
    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      final ok = await auth.signInWithGoogle();
      if (!mounted) return;
      if (ok) {
        _goHome();
      } else if (auth.errorMessage != null) {
        _showError(auth.errorMessage!);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor = textColor.withValues(alpha: 0.55);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),

                // ── Logo ───────────────────────────────
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4ECDC4), Color(0xFF45B7D1)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.cabin,
                        color: Colors.white, size: 40),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Welcome Back!',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: textColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to continue',
                  style: TextStyle(fontSize: 16, color: subColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // ── Email field ────────────────────────
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please enter your email';
                    if (!v.contains('@')) return 'Please enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── Password field ─────────────────────
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty)
                      return 'Please enter your password';
                    if (v.length < 6)
                      return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                // ── Forgot password ────────────────────
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () async {
                      final email = _emailController.text.trim();
                      if (email.isEmpty || !email.contains('@')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Enter your email above first')));
                        return;
                      }
                      await context
                          .read<AuthProvider>()
                          .resetPassword(email);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Password reset email sent!')),
                        );
                      }
                    },
                    child: const Text('Forgot Password?'),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Sign In button ─────────────────────
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4ECDC4),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Sign In',
                            style: TextStyle(fontSize: 16)),
                      ),

                const SizedBox(height: 20),

                // ── OR divider ─────────────────────────
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or sign in with',
                        style: TextStyle(color: subColor, fontSize: 13)),
                  ),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: 16),

                // ── Google button ──────────────────────
                OutlinedButton(
                  onPressed: _isLoading ? null : _googleLogin,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: BorderSide(
                        color: Theme.of(context).dividerColor),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Google coloured "G" icon
                      _GoogleIcon(),
                      const SizedBox(width: 12),
                      const Text(
                        'Continue with Google',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Sign up link ───────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account?",
                        style: TextStyle(color: textColor)),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RegisterScreen()),
                      ),
                      child: const Text('Sign Up'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // ── Guest divider ──────────────────────
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('or continue as guest',
                        style: TextStyle(color: subColor)),
                  ),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: 16),

                // ── Guest button ───────────────────────
                OutlinedButton(
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4ECDC4),
                    side: const BorderSide(color: Color(0xFF4ECDC4)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text('Continue as Guest'),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Google coloured "G" icon ──────────────────────────────
class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;
    final double stroke = size.width * 0.17;

    Paint arc(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.78);

    // Red (top-right)
    canvas.drawArc(rect, -1.38, 2.15, false, arc(const Color(0xFFEA4335)));
    // Blue (top-left)
    canvas.drawArc(rect, -3.55, 1.10, false, arc(const Color(0xFF4285F4)));
    // Yellow (bottom-right)
    canvas.drawArc(rect, 0.75, 1.10, false, arc(const Color(0xFFFBBC05)));
    // Green (bottom-left)
    canvas.drawArc(rect, 1.82, 0.82, false, arc(const Color(0xFF34A853)));

    // Blue horizontal bar
    canvas.drawRect(
      Rect.fromLTWH(
        cx - 1,
        cy - stroke / 2,
        r * 0.78 + stroke / 2 + 1,
        stroke,
      ),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(_) => false;
}