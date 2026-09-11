import 'package:flutter/material.dart';

import '../../domain/entities/customer.dart';
import '../../domain/entities/follow_up_task.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/timeline_entry.dart';
import '../../domain/repositories/follow_up_repository.dart';

class InMemoryFollowUpRepository implements FollowUpRepository {
  InMemoryFollowUpRepository() {
    final now = DateTime.now();
    _products = const [
      Product(
        id: 'hamro-futsal',
        name: 'Hamro Futsal',
        description: 'Venue booking and futsal management platform.',
        brandColor: Color(0xFF009688),
        isActive: true,
      ),
      Product(
        id: 'kavelo',
        name: 'Kavelo',
        description: 'Customer engagement tools for growing service teams.',
        brandColor: Color(0xFF2563EB),
        isActive: true,
      ),
    ];

    _customers = [
      Customer(
        id: 'c1',
        name: 'Suman Shrestha',
        businessName: 'Arena Futsal Center',
        productId: 'hamro-futsal',
        phoneNumber: '+977 9841234567',
        email: 'suman@arena.example',
        address: 'Baneswor, Kathmandu',
        venues: const [
          Venue(
            name: 'Arena Baneswor',
            address: 'Baneswor',
            contactPerson: 'Suman',
            phoneNumber: '+977 9841234567',
          ),
        ],
        assignedUserId: 'u1',
        leadSource: LeadSource.referral,
        priority: Priority.high,
        status: CustomerStatus.interested,
        description: 'Interested in online booking and membership tracking.',
        lastContactedAt: now.subtract(const Duration(days: 2)),
        nextFollowUpAt: now.subtract(const Duration(hours: 3)),
        createdBy: 'Admin',
        createdAt: now.subtract(const Duration(days: 12)),
        updatedAt: now.subtract(const Duration(hours: 3)),
      ),
      Customer(
        id: 'c2',
        name: 'Anita Rai',
        businessName: 'Peak Fitness Studio',
        productId: 'kavelo',
        phoneNumber: '+977 9807654321',
        email: 'hello@peak.example',
        address: 'Lalitpur',
        venues: const [],
        assignedUserId: 'u1',
        leadSource: LeadSource.website,
        priority: Priority.normal,
        status: CustomerStatus.demoScheduled,
        description: 'Demo booked for team workflow and reminders.',
        lastContactedAt: now.subtract(const Duration(hours: 20)),
        nextFollowUpAt: now.add(const Duration(hours: 4)),
        createdBy: 'Mina',
        createdAt: now.subtract(const Duration(days: 6)),
        updatedAt: now.subtract(const Duration(hours: 20)),
      ),
      Customer(
        id: 'c3',
        name: 'Bikash Gurung',
        businessName: 'Northside Futsal',
        productId: 'hamro-futsal',
        phoneNumber: '+977 9811112222',
        email: '',
        address: 'Pokhara',
        venues: const [],
        assignedUserId: 'u1',
        leadSource: LeadSource.visit,
        priority: Priority.low,
        status: CustomerStatus.newLead,
        description: 'Needs first contact and qualification.',
        lastContactedAt: null,
        nextFollowUpAt: null,
        createdBy: 'Mina',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
    ];

    _tasks = [
      FollowUpTask(
        id: 't1',
        customerId: 'c1',
        productId: 'hamro-futsal',
        assignedUserId: 'u1',
        dueAt: now.subtract(const Duration(hours: 3)),
        nextAction: 'Call about booking module pricing.',
        isOpen: true,
      ),
      FollowUpTask(
        id: 't2',
        customerId: 'c2',
        productId: 'kavelo',
        assignedUserId: 'u1',
        dueAt: now.add(const Duration(hours: 4)),
        nextAction: 'Send demo meeting link.',
        isOpen: true,
      ),
    ];

    _timeline = {
      'c1': [
        TimelineEntry(
          id: 'e1',
          customerId: 'c1',
          title: 'Customer created',
          note: 'Lead added from referral.',
          authorName: 'Admin',
          createdAt: now.subtract(const Duration(days: 12)),
        ),
        TimelineEntry(
          id: 'e2',
          customerId: 'c1',
          title: 'Connected',
          note: 'Discussed venue booking pain points and requested pricing.',
          authorName: 'Mina',
          createdAt: now.subtract(const Duration(days: 2)),
        ),
      ],
    };
  }

  late final List<Product> _products;
  late final List<Customer> _customers;
  late final List<FollowUpTask> _tasks;
  late final Map<String, List<TimelineEntry>> _timeline;

  @override
  Future<List<Customer>> getCustomers() async => _customers;

  @override
  Future<List<FollowUpTask>> getOpenTasks() async =>
      _tasks.where((task) => task.isOpen).toList();

  @override
  Future<List<Product>> getProducts() async =>
      _products.where((product) => product.isActive).toList();

  @override
  Future<List<TimelineEntry>> getTimeline(String customerId) async =>
      _timeline[customerId] ?? const [];
}
