import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/follow_up_bloc.dart';
import 'account_page.dart';
import 'customers_page.dart';
import 'dashboard_page.dart';
import 'follow_ups_page.dart';

class LeadLoopHomePage extends StatelessWidget {
  const LeadLoopHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FollowUpBloc, FollowUpState>(
      builder: (context, state) {
        final pages = [
          const DashboardPage(),
          const CustomersPage(),
          const FollowUpsPage(),
          const AccountPage(),
        ];

        return Scaffold(
          appBar: AppBar(
            title: const Text('LeadLoop'),
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 14),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFFEAF5F3),
                  child: Text('M', style: TextStyle(color: Color(0xFF00897B))),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: switch (state.status) {
              FollowUpStatus.initial || FollowUpStatus.loading => const Center(
                child: CircularProgressIndicator(),
              ),
              FollowUpStatus.failure => Center(
                child: Text(state.errorMessage ?? 'Something went wrong.'),
              ),
              FollowUpStatus.success => pages[state.selectedTab],
            },
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: state.selectedTab,
            onTap: (index) {
              context.read<FollowUpBloc>().add(NavigationTabChanged(index));
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.people_alt_outlined),
                label: 'Customers',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.notifications_active_outlined),
                label: 'Follow-ups',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                label: 'Account',
              ),
            ],
          ),
        );
      },
    );
  }
}
