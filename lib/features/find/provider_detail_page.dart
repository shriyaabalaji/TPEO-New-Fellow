import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProviderDetailPage extends StatelessWidget {
  const ProviderDetailPage({super.key, required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Provider'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 120, child: Placeholder()),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(radius: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Business $providerId', style: Theme.of(context).textTheme.titleMedium),
                        Row(
                          children: [
                            Icon(Icons.star, size: 16, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 4),
                            const Text('5.0 (37)'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.favorite_border), onPressed: () {}),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Service Title', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: ['\$', '\$\$', '\$\$\$'].map((p) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: OutlinedButton(onPressed: () {}, child: Text(p)),
                )).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.push('/booking?providerId=$providerId'),
                  child: const Text('Book Now'),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Gallery', style: Theme.of(context).textTheme.titleSmall),
                  TextButton(onPressed: () {}, child: const Text('See all')),
                ],
              ),
            ),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 4,
                itemBuilder: (_, i) => Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Reviews', style: Theme.of(context).textTheme.titleSmall),
                  TextButton(onPressed: () {}, child: const Text('See all')),
                ],
              ),
            ),
            const ListTile(title: Text('Review placeholder 1'), subtitle: Text('Great service!')),
            const ListTile(title: Text('Review placeholder 2'), subtitle: Text('Would book again.')),
          ],
        ),
      ),
    );
  }
}
