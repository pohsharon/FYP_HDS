import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/home/user_management/add_user.dart';
import 'package:fyp_hbs/services/user_api.dart';

class UserListPage extends StatefulWidget {
  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  late Future<List<Map<String, dynamic>>> _userFuture;

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  void fetchUsers() {
    setState(() {
      _userFuture = UserApi.fetchUsers();
    });
  }

  Widget _buildUserCard(
    BuildContext context,
    Map<String, dynamic> user, {
    bool isOwner = false,
  }) {
    final roleText =
        (user['roles'] as List).isEmpty
            ? 'No Role'
            : (user['roles'] as List).join(', ');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
      color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        title: Text(
          isOwner ? '${user['name']} (Me)' : user['name'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(user['email'] ?? '-'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.grey.shade200,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(roleText),
              if (isOwner) const Icon(Icons.lock, size: 16, color: Colors.grey),
            ],
          ),
        ),
        onLongPress: () {
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder:
                (_) => Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8), // Add spacing at the top
                      ListTile(
                        leading: const Icon(Icons.edit),
                        title: const Text('Edit'),
                        onTap: () async {
                          Navigator.pop(context); // Close the bottom sheet
                          final result = await showAddUserSheet(
                            context,
                            user: user,
                          );
                          if (result == true) fetchUsers();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.delete),
                        title: const Text('Delete'),
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder:
                                (context) => AlertDialog(
                                  title: const Text('Confirm Delete'),
                                  content: const Text(
                                    'Are you sure you want to delete this species?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed:
                                          () => Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed:
                                          () => Navigator.pop(context, true),
                                      child: const Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                          );

                          if (confirm == true) {
                            try {
                              final response = await UserApi.deleteUser(
                                user['id'].toString(),
                              );

                              if (context.mounted) {
                                fetchUsers();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Deleted successfully"),
                                  ),
                                );
                                Navigator.pop(context, true);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "Delete failed: ${e.toString()}",
                                    ),
                                  ),
                                );
                              }
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
          );
        },
      ),
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Tooltip(
              message: 'Long press to edit user details',
              child: Icon(Icons.info_outline, color: Colors.grey),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _userFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final users = snapshot.data ?? [];

            final activeUsers =
                users.where((u) => u['is_active'] == 1).toList();
            final deactivatedUsers =
                users.where((u) => u['is_active'] != 1).toList();

            return ListView(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: const Text(
                        'Active Users',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),

                    ElevatedButton.icon(
                      onPressed: () async {
                        final shouldRefresh = await showAddUserSheet(
                          context,
                          user: {},
                        );
                        if (shouldRefresh == true) {
                          fetchUsers();
                        }
                      },
                      icon: const Icon(
                        Icons.add,
                        size: 12,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Add User',
                        style: TextStyle(fontSize: 12, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.hunterGreen,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                ...activeUsers.map(
                  (user) => _buildUserCard(
                    context,
                    user,
                    isOwner: user['roles']?.contains('Owner') ?? false,
                  ),
                ),
                if (deactivatedUsers.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: const Text(
                      'Deactivated Users',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...deactivatedUsers.map(
                    (user) => _buildUserCard(context, user),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
