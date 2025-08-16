import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _registerMode = false; // when true show person creation fields
  String? _branchId; // selected branch for new person

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
  _name.dispose();
  _phone.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() { _busy = true; _error = null; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (mounted) Navigator.of(context).pushReplacementNamed('/home');
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Sign in failed');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  Future<void> _forgotPassword() async {
    if (_registerMode || _busy) return; // only in login mode
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() { _error = 'Enter your email then tap Forgot Password'; });
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email sent')));
      }
    } on FirebaseAuthException catch (e) {
      setState(() { _error = e.message ?? 'Reset failed'; });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  Future<void> _register() async {
    if (!_registerMode) {
      // first press toggles register mode so user can enter extra details
      setState(() { _registerMode = true; _error = null; });
      return;
    }
    // validate minimal fields similar to Add Person dialog ordering
    final email = _email.text.trim();
    final password = _password.text;
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    if (name.isEmpty) { setState(() { _error = 'Enter name'; }); return; }
    if (phone.length < 7) { setState(() { _error = 'Enter valid phone'; }); return; }
    if (email.isEmpty || !email.contains('@')) { setState(() { _error = 'Enter valid email'; }); return; }
    if (password.length < 6) { setState(() { _error = 'Password min 6 chars'; }); return; }
    setState(() { _busy = true; _error = null; });
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // After auth user creation add person doc (mirroring ManagePersonsPanel logic simplified)
      final data = {
        'name': name,
        'email': email.toLowerCase(),
        'phone': phone,
        'branchId': _branchId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance.collection('persons').add(data);
      if (mounted) Navigator.of(context).pushReplacementNamed('/home');
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Registration failed');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_registerMode ? 'Register' : 'Sign in', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 8),
                  ],
                  if (_registerMode) ...[
                    // Branch selector first (like add person dialog)
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('branches').orderBy('name').snapshots(),
                      builder: (context, snap) {
                        final docs = snap.data?.docs ?? [];
                        return DropdownButtonFormField<String?>(
                          value: _branchId,
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('No Branch')),
                            ...docs.map((d) => DropdownMenuItem<String?>(value: d.id, child: Text((d['name'] ?? '').toString()))),
                          ],
                          onChanged: (v) => setState(() => _branchId = v),
                          decoration: const InputDecoration(labelText: 'Branch'),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Name'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phone,
                      decoration: const InputDecoration(labelText: 'Phone'),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  if (!_registerMode)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _busy ? null : _signIn,
                            child: _busy ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Login'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _busy ? null : _register,
                          child: const Text('Register'),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _busy ? null : _register,
                        child: _busy
                            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Create Account'),
                      ),
                    ),
                  if (!_registerMode) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _busy ? null : _forgotPassword,
                        child: const Text('Forgot Password?'),
                      ),
                    ),
                  ],
                  if (_registerMode) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy ? null : () => setState(() { _registerMode = false; _error = null; }),
                      child: const Text('Cancel Register'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
