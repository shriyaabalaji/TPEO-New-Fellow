import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'onboarding_provider.dart';

class RoleScreen extends ConsumerStatefulWidget {
  const RoleScreen({super.key});

  @override
  ConsumerState<RoleScreen> createState() => _RoleScreenState();
}

class _RoleScreenState extends ConsumerState<RoleScreen> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CircleBackButton(onPressed: () => context.go('/login')),
              const SizedBox(height: 32),
              Text(
                'Which Option Best\nDescribes You?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      height: 1.2,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose all that apply',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                    ),
              ),
              const SizedBox(height: 32),
              _SelectableRoleButton(
                label: 'Service Provider',
                isSelected: _selected.contains('provider'),
                onTap: () => setState(() {
                  if (_selected.contains('provider')) {
                    _selected.remove('provider');
                  } else {
                    _selected.add('provider');
                  }
                }),
              ),
              const SizedBox(height: 16),
              _SelectableRoleButton(
                label: 'Customer',
                isSelected: _selected.contains('customer'),
                onTap: () => setState(() {
                  if (_selected.contains('customer')) {
                    _selected.remove('customer');
                  } else {
                    _selected.add('customer');
                  }
                }),
              ),
              const Spacer(),
              _ContinueButton(
                onPressed: _selected.isNotEmpty
                    ? () {
                        String role;
                        if (_selected.contains('provider') &&
                            _selected.contains('customer')) {
                          role = 'both';
                        } else if (_selected.contains('provider')) {
                          role = 'provider';
                        } else {
                          role = 'customer';
                        }
                        ref.read(onboardingRoleProvider.notifier).state = role;
                        context.go('/onboarding/name');
                      }
                    : null,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleBackButton extends StatelessWidget {
  const _CircleBackButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black, width: 1.5),
        ),
        child: const Icon(Icons.arrow_back, size: 20, color: Colors.black),
      ),
    );
  }
}

class _SelectableRoleButton extends StatelessWidget {
  const _SelectableRoleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.black : const Color(0xFFD0D0D0),
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({required this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: enabled ? Colors.black : const Color(0xFFB0B0B0),
          borderRadius: BorderRadius.circular(30),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Continue',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: enabled ? Colors.white : Colors.white70,
              ),
            ),
            Icon(
              Icons.arrow_forward,
              color: enabled ? Colors.white : Colors.white70,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
