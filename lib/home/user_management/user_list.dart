import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/home/user_management/add_user.dart';

class UserListPage extends StatelessWidget {
  final List<Map<String, String>> mockActiveUsers = [
    {
      "name": "Hooi",
      "role": "Owner",
      "image": "https://i.pravatar.cc/150?img=3",
    },
    {
      "name": "Tui",
      "role": "Worker",
      "image": "https://i.pravatar.cc/150?img=5",
    },
    {
      "name": "Sotong",
      "role": "Manager",
      "image": "https://i.pravatar.cc/150?img=5",
    },
    {
      "name": "Ali",
      "role": "Worker",
      "image": "https://i.pravatar.cc/150?img=5",
    },
  ];

  final List<Map<String, String>> mockDeactivatedUsers = [
    {
      "name": "Ahmad",
      "role": "Worker",
      "image": "https://i.pravatar.cc/150?img=5",
    },
  ];

  void _onUserTap(BuildContext context, Map<String, String> user) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('User Details'),
            content: Text('You tapped on ${user["name"]} (${user["role"]})'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Widget _buildUserCard(
    BuildContext context,
    Map<String, String> user, {
    bool isOwner = false,
  }) {
    return GestureDetector(
      onTap: () => _onUserTap(context, user),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
        color: Colors.white,
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: CircleAvatar(
            backgroundImage: NetworkImage(user['image'] ?? ''),
          ),
          title: Text(
            isOwner ? '${user['name']} (Me)' : user['name'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.grey.shade200,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(user['role'] ?? ''),
                if (isOwner)
                  const Icon(Icons.lock, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserSection(
    BuildContext context,
    String title,
    List<Map<String, String>> users, {
    bool isDeactivated = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...users
            .map(
              (user) => _buildUserCard(
                context,
                user,
                isOwner: user['role'] == 'Owner',
              ),
            )
            .toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.pakistanGreen,
        title: const Text(
          'User Management',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Active Users',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                ElevatedButton.icon(
                  onPressed: () => showAddUserSheet(context),
                  icon: const Icon(Icons.add, size: 12, color: AppColors.white,),
                  label: const Text('Add User', style: TextStyle(fontSize: 12, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.hunterGreen,
                  ),
                ),
              ],
            ),
            ...mockActiveUsers.map(
              (user) => _buildUserCard(
                context,
                user,
                isOwner: user['role'] == 'Owner',
              ),
            ),
            _buildUserSection(
              context,
              'Deactivated Users',
              mockDeactivatedUsers,
            ),
          ],
        ),
      ),
    );
  }
}
