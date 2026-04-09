import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'auth_controller.dart';
import '../../core/auth/ut_email_gate.dart';
import '../../core/firebase_init.dart';
import '../onboarding/onboarding_provider.dart' show onboardingDoneProvider, clearOnboardingDone;
import 'effective_user_provider.dart';
import '../profile/provider_account_controller.dart';

final _loginRedirectDoneProvider = StateProvider<bool>((ref) => false);

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _showLanding = true; // false = show email/password form
  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _signedOutStaleSession = false;

  @override
  void initState() {
    super.initState();
    _clearStaleSession();
  }

  /// Sign out any persisted Firebase session so users always land on login.
  Future<void> _clearStaleSession() async {
    if (_signedOutStaleSession) return;
    _signedOutStaleSession = true;
    final auth = ref.read(authServiceProvider);
    final user = ref.read(authStateProvider).valueOrNull;
    if (user != null && auth != null) {
      await auth.signOut();
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter your email';
    if (!isUtEmail(value.trim())) {
      return 'Use an @utexas.edu account';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password';
    if (_isSignUp && value.length < 6) return 'Use at least 6 characters';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = ref.read(authServiceProvider);
    if (auth == null || !firebaseInitialized) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Firebase not configured. Run: flutterfire configure')),
        );
      }
      return;
    }
    setState(() => _isLoading = true);
    try {
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text;
      if (_isSignUp) {
        final cred = await auth.createUserWithEmailAndPassword(email: email, password: password);
        if (cred?.user != null) {
          try {
            await auth.sendEmailVerification();
          } on Exception catch (e) {
            final s = e.toString().toLowerCase();
            if (mounted) {
              if (s.contains('too-many-requests')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Too many verification emails sent. Wait a few minutes and use Resend on the next screen.'),
                  ),
                );
              }
              // else: other errors, still show success below
            }
          }
          final fs = ref.read(firestoreServiceProvider);
          if (fs != null) {
            try {
              await fs.upsertUserProfile(cred!.user!);
            } catch (_) {}
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Account created. Check your inbox (and spam) for the verification link.'),
              ),
            );
          }
        }
      } else {
        await auth.signInWithEmailAndPassword(email: email, password: password);
        final fs = ref.read(firestoreServiceProvider);
        final user = ref.read(authStateProvider).valueOrNull;
        if (user != null && fs != null) {
          try {
            await fs.upsertUserProfile(user);
          } catch (_) {}
        }
      }
    } on Exception catch (e) {
      if (mounted) {
        String msg = 'Sign-in failed';
        final s = e.toString().toLowerCase();
        if (s.contains('user-not-found') || s.contains('wrong-password') || s.contains('invalid-credential')) {
          msg = 'Invalid email or password';
        } else if (s.contains('email-already-in-use')) {
          msg = 'This email is already registered. Sign in instead.';
        } else if (s.contains('weak-password')) {
          msg = 'Use at least 6 characters for password';
        } else if (s.contains('invalid-email')) {
          msg = 'Use a valid @utexas.edu email';
        } else {
          msg = e.toString().replaceFirst(RegExp(r'^Exception:?\s*'), '');
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final onboardingDone = ref.watch(onboardingDoneProvider);
    final redirectDone = ref.watch(_loginRedirectDoneProvider);

    ref.listen(authStateProvider, (prev, next) {
      if (next.valueOrNull == null) ref.read(_loginRedirectDoneProvider.notifier).state = false;
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: authState.when(
        data: (user) {
          if (user != null) {
            final email = user.email;
            if (!isUtEmail(email)) {
              ref.read(authServiceProvider)?.signOut();
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'You must use an @utexas.edu account.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              );
            }
            if (!user.emailVerified) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Please verify your email before continuing. Check your inbox (and spam) for the verification link.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () async {
                          final auth = ref.read(authServiceProvider);
                          if (auth == null) return;
                          final verified = await auth.reloadUser();
                          if (!mounted) return;
                          if (verified) {
                            await auth.reloadUserAndRefreshToken();
                            if (!mounted) return;
                            final user = ref.read(authStateProvider).valueOrNull;
                            final fs = ref.read(firestoreServiceProvider);
                            if (user != null && fs != null) {
                              try {
                                await fs.upsertUserProfile(user);
                              } catch (_) {}
                            }
                            ref.read(_loginRedirectDoneProvider.notifier).state = true;
                            context.go('/onboarding/role');
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Email not verified yet. Click the link in your email, then tap Continue again.'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Continue to onboarding'),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () async {
                          await ref.read(authServiceProvider)?.signOut();
                          if (!mounted) return;
                          setState(() {
                            _showLanding = true;
                            _isSignUp = false;
                          });
                        },
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Back to login'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            await ref.read(authServiceProvider)?.sendEmailVerification();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Verification email sent. Check your inbox and spam.')),
                              );
                            }
                          } on Exception catch (e) {
                            if (!mounted) return;
                            final s = e.toString().toLowerCase();
                            if (s.contains('too-many-requests')) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Too many attempts. Please wait a few minutes before resending.'),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Could not send: ${e.toString().replaceFirst(RegExp(r"^Exception:?\s*"), "")}',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.email),
                        label: const Text('Resend verification email'),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (!redirectDone && onboardingDone.hasValue) {
              // New accounts (created in last 10 min) always get onboarding; others use saved pref
              final createdAt = user.metadata.creationTime;
              final isNewAccount = createdAt != null &&
                  DateTime.now().difference(createdAt).inMinutes < 10;
              final goToOnboarding = isNewAccount || !onboardingDone.value!;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.read(_loginRedirectDoneProvider.notifier).state = true;
                if (context.mounted) context.go(goToOnboarding ? '/onboarding/role' : '/find');
              });
            }
            return const Center(child: CircularProgressIndicator());
          }
          return _showLanding ? _buildLanding(context) : _buildForm(context);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Auth error: $e')),
      ),
    );
  }

  Widget _buildLanding(BuildContext context) {
    // ── Vertical position of the content ──────────────────────────────────
    // Negative = move up, Positive = move down. 0 = perfectly centered.
    const verticalOffset = -40.0;
    // ──────────────────────────────────────────────────────────────────────
    return Center(
      child: Transform.translate(
        offset: const Offset(0, verticalOffset),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/logo.png', width: 220),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => setState(() { _showLanding = false; _isSignUp = false; }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBF5800),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Login'),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => setState(() { _showLanding = false; _isSignUp = true; }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBF5800),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Sign Up'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Circular back button
              GestureDetector(
                onTap: () => setState(() => _showLanding = true),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                  child: const Icon(Icons.arrow_back, size: 20, color: Colors.black),
                ),
              ),
              const SizedBox(height: 24),
              // Centered subtitle header
              Center(
                child: Column(
                  children: [
                    Text(
                      'Bevo Booked',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isSignUp ? 'Create your account' : 'Welcome back',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.black54,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                _isSignUp ? 'Sign Up' : 'Sign In',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
              ),
              const SizedBox(height: 24),
              // Email field
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Email (@utexas.edu)',
                  hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.black, width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.red, width: 1.5),
                  ),
                ),
                validator: _validateEmail,
              ),
              const SizedBox(height: 16),
              // Password field
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: _isSignUp ? 'Password (min 6 characters)' : 'Password',
                  hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.black, width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.red, width: 1.5),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: _validatePassword,
              ),
              const Spacer(),
              // Switch between login/signup
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _isSignUp = !_isSignUp),
                  child: Text(
                    _isSignUp ? 'Already have an account? Sign in' : "Don't have an account? Sign up",
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Submit button styled like onboarding Continue
              GestureDetector(
                onTap: _isLoading ? null : _submit,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: _isLoading ? const Color(0xFFB0B0B0) : Colors.black,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isSignUp ? 'Create Account' : 'Sign In',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      _isLoading
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
