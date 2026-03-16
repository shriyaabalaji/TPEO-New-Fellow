import 'package:flutter/material.dart';

class OnboardingStepHeader extends StatelessWidget {
  const OnboardingStepHeader({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final stepLabel =
        'Step ${(currentStep + 1).toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stepLabel,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(totalSteps, (i) {
            final isFilled = i <= currentStep;
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i < totalSteps - 1 ? 6 : 0),
                decoration: BoxDecoration(
                  color: isFilled ? Colors.black : const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

@Deprecated('Use OnboardingStepHeader instead')
class OnboardingProgressLines extends StatelessWidget {
  const OnboardingProgressLines({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return OnboardingStepHeader(
      currentStep: currentStep,
      totalSteps: totalSteps,
    );
  }
}
