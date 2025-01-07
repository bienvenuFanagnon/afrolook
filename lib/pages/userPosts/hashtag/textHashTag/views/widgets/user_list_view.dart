import 'package:flutter/material.dart';

import 'package:fluttertagger/fluttertagger.dart';

import '../../models/user.dart';
import '../view_models/search_view_model.dart';
import 'loading_indicator.dart';

class UserListView extends StatelessWidget {
  const UserListView({
    Key? key,
    required this.tagController,
    required this.animation,
  }) : super(key: key);

  final FlutterTaggerController tagController;
  final Animation<Offset> animation;

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: animation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.2),
              offset: const Offset(0, -20),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: ValueListenableBuilder<bool>(
            valueListenable: searchViewModel.loading,
            builder: (_, loading, __) {
              return ValueListenableBuilder<List<User>>(
                valueListenable: searchViewModel.users,
                builder: (_, users, __) {
                  return Column(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: tagController.dismissOverlay,
                          icon: const Icon(Icons.close),
                        ),
                      ),
                      if (loading && users.isEmpty) ...{
                        const Center(
                          heightFactor: 16,
                          child: LoadingWidget(),
                        )
                      },
                      if (!loading && users.isEmpty)
                        const Center(
                          heightFactor: 16,
                          child: Text("No user found"),
                        ),
                      if (users.isNotEmpty)
                        Expanded(
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: users.length,
                            itemBuilder: (_, index) {
                              final user = users[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: NetworkImage(
                                      '${user.avatar}'),
                                  onBackgroundImageError: (exception, stackTrace) =>
                                      AssetImage(
                                          "assets/icon/user-removebg-preview.png"),
                                ),
                                title: Text(user.fullName),
                                subtitle: Text("@${user.userName}"),
                                onTap: () {
                                  tagController.addTag(
                                    id: user.id,
                                    name: user.userName,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
