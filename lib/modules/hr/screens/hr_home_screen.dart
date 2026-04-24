import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:QUIK/core/theme/app_theme.dart';
import 'package:QUIK/modules/hr/models/hr_attendance_model.dart';
import 'package:QUIK/modules/hr/models/hr_employee_model.dart';
import 'package:QUIK/modules/hr/models/hr_wage_entry_model.dart';
import 'package:QUIK/modules/hr/repositories/hr_repository.dart';

class HrHomeScreen extends StatefulWidget {
  final String tenantId;

  const HrHomeScreen({super.key, required this.tenantId});

  @override
  State<HrHomeScreen> createState() => _HrHomeScreenState();
}

class _HrHomeScreenState extends State<HrHomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final HrRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = HrRepository(tenantId: widget.tenantId);
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: zBorder),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: zBlueSoft,
                child: Icon(Icons.badge_outlined, color: zBlue),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HR',
                      style: TextStyle(
                        color: zText,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Employee master, daily attendance, and wages for this company',
                      style: TextStyle(
                        color: zMuted,
                        fontSize: 13.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _handlePrimaryAction,
                icon: const Icon(Icons.add),
                label: Text(_primaryActionLabel),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: zBorder),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: zBlue,
            unselectedLabelColor: zMuted,
            indicatorColor: zBlue,
            onTap: (_) => setState(() {}),
            tabs: const [
              Tab(text: 'Employees'),
              Tab(text: 'Attendance'),
              Tab(text: 'Wages'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _EmployeeList(repository: _repository),
              _AttendanceList(repository: _repository),
              _WageList(repository: _repository),
            ],
          ),
        ),
      ],
    );
  }

  String get _primaryActionLabel {
    switch (_tabController.index) {
      case 1:
        return 'Mark Attendance';
      case 2:
        return 'Add Wage';
      default:
        return 'Add Employee';
    }
  }

  void _handlePrimaryAction() {
    switch (_tabController.index) {
      case 1:
        _showAttendanceDialog();
        break;
      case 2:
        _showWageDialog();
        break;
      default:
        _showEmployeeDialog();
    }
  }

  Future<void> _showEmployeeDialog() async {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final deptCtrl = TextEditingController(text: 'Production');
    final designationCtrl = TextEditingController(text: 'Operator');
    final phoneCtrl = TextEditingController();
    final wageCtrl = TextEditingController();
    String employmentType = 'staff';
    var isActive = true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Employee'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 460,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _field(codeCtrl, 'Employee Code'),
                      _field(nameCtrl, 'Full Name'),
                      _field(deptCtrl, 'Department'),
                      _field(designationCtrl, 'Designation'),
                      _field(phoneCtrl, 'Phone'),
                      _field(
                        wageCtrl,
                        'Daily Wage',
                        keyboardType: TextInputType.number,
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: employmentType,
                        decoration: const InputDecoration(
                          labelText: 'Employment Type',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'staff', child: Text('Staff')),
                          DropdownMenuItem(
                            value: 'worker',
                            child: Text('Worker'),
                          ),
                          DropdownMenuItem(
                            value: 'contract',
                            child: Text('Contract'),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            employmentType = value ?? employmentType;
                          });
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: isActive,
                        title: const Text('Active'),
                        onChanged: (value) {
                          setDialogState(() => isActive = value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) return;

    final employee = HrEmployeeModel(
      employeeId: _repository.newEmployeeId(),
      employeeCode: codeCtrl.text.trim(),
      fullName: nameCtrl.text.trim(),
      department: deptCtrl.text.trim(),
      designation: designationCtrl.text.trim(),
      employmentType: employmentType,
      phone: phoneCtrl.text.trim(),
      dailyWage: double.tryParse(wageCtrl.text.trim()) ?? 0,
      isActive: isActive,
      joinedAt: DateTime.now(),
    );

    await _repository.saveEmployee(employee);
    if (!mounted) return;
    _savedSnack('Employee saved');
  }

  Future<void> _showAttendanceDialog() async {
    final employeeCtrl = TextEditingController();
    final overtimeCtrl = TextEditingController(text: '0');
    final remarksCtrl = TextEditingController();
    DateTime date = DateTime.now();
    String shift = 'Day';
    String status = 'present';

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Mark Attendance'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 460,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Date'),
                        subtitle: Text(DateFormat('dd MMM yyyy').format(date)),
                        trailing: const Icon(Icons.calendar_month_outlined),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                            initialDate: date,
                          );
                          if (picked != null) {
                            setDialogState(() => date = picked);
                          }
                        },
                      ),
                      _field(employeeCtrl, 'Employee Name'),
                      DropdownButtonFormField<String>(
                        initialValue: shift,
                        decoration: const InputDecoration(labelText: 'Shift'),
                        items: const [
                          DropdownMenuItem(value: 'Day', child: Text('Day')),
                          DropdownMenuItem(value: 'Night', child: Text('Night')),
                          DropdownMenuItem(
                            value: 'General',
                            child: Text('General'),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() => shift = value ?? shift);
                        },
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: const [
                          DropdownMenuItem(
                            value: 'present',
                            child: Text('Present'),
                          ),
                          DropdownMenuItem(
                            value: 'absent',
                            child: Text('Absent'),
                          ),
                          DropdownMenuItem(
                            value: 'half_day',
                            child: Text('Half day'),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() => status = value ?? status);
                        },
                      ),
                      _field(
                        overtimeCtrl,
                        'Overtime Hours',
                        keyboardType: TextInputType.number,
                      ),
                      _field(remarksCtrl, 'Remarks'),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) return;

    final attendance = HrAttendanceModel(
      attendanceId: _repository.newAttendanceId(),
      employeeId: '',
      employeeNameSnapshot: employeeCtrl.text.trim(),
      date: date,
      shift: shift,
      status: status,
      overtimeHours: double.tryParse(overtimeCtrl.text.trim()) ?? 0,
      remarks: remarksCtrl.text.trim(),
    );

    await _repository.saveAttendance(attendance);
    if (!mounted) return;
    _savedSnack('Attendance saved');
  }

  Future<void> _showWageDialog() async {
    final employeeCtrl = TextEditingController();
    final daysCtrl = TextEditingController();
    final wageCtrl = TextEditingController();
    final advanceCtrl = TextEditingController(text: '0');
    final remarksCtrl = TextEditingController();
    DateTime from = DateTime.now();
    DateTime to = DateTime.now();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Wage Entry'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 460,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _dateTile(
                        title: 'Period From',
                        date: from,
                        onPicked: (picked) =>
                            setDialogState(() => from = picked),
                      ),
                      _dateTile(
                        title: 'Period To',
                        date: to,
                        onPicked: (picked) => setDialogState(() => to = picked),
                      ),
                      _field(employeeCtrl, 'Employee Name'),
                      _field(
                        daysCtrl,
                        'Payable Days',
                        keyboardType: TextInputType.number,
                      ),
                      _field(
                        wageCtrl,
                        'Daily Wage',
                        keyboardType: TextInputType.number,
                      ),
                      _field(
                        advanceCtrl,
                        'Advance Paid',
                        keyboardType: TextInputType.number,
                      ),
                      _field(remarksCtrl, 'Remarks'),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) return;

    final wageEntry = HrWageEntryModel(
      wageEntryId: _repository.newWageEntryId(),
      employeeId: '',
      employeeNameSnapshot: employeeCtrl.text.trim(),
      periodFrom: from,
      periodTo: to,
      payableDays: double.tryParse(daysCtrl.text.trim()) ?? 0,
      dailyWage: double.tryParse(wageCtrl.text.trim()) ?? 0,
      advancePaid: double.tryParse(advanceCtrl.text.trim()) ?? 0,
      remarks: remarksCtrl.text.trim(),
    );

    await _repository.saveWageEntry(wageEntry);
    if (!mounted) return;
    _savedSnack('Wage entry saved');
  }

  Widget _dateTile({
    required String title,
    required DateTime date,
    required ValueChanged<DateTime> onPicked,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(DateFormat('dd MMM yyyy').format(date)),
      trailing: const Icon(Icons.calendar_month_outlined),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          initialDate: date,
        );
        if (picked != null) onPicked(picked);
      },
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  void _savedSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _EmployeeList extends StatelessWidget {
  final HrRepository repository;

  const _EmployeeList({required this.repository});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HrEmployeeModel>>(
      stream: repository.watchEmployees(),
      builder: (context, snapshot) {
        return _HrListShell(
          loading: snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData,
          error: snapshot.error,
          emptyTitle: 'No employees yet',
          emptyMessage: 'Add Aman staff, workers, operators, and supervisors.',
          children: (snapshot.data ?? const <HrEmployeeModel>[])
              .map(
                (employee) => _HrTile(
                  icon: Icons.person_outline,
                  title: employee.fullName,
                  subtitle:
                      '${employee.employeeCode} • ${employee.department} • ${employee.designation}',
                  trailing: employee.isActive ? 'Active' : 'Inactive',
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _AttendanceList extends StatelessWidget {
  final HrRepository repository;

  const _AttendanceList({required this.repository});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HrAttendanceModel>>(
      stream: repository.watchAttendance(),
      builder: (context, snapshot) {
        return _HrListShell(
          loading: snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData,
          error: snapshot.error,
          emptyTitle: 'No attendance yet',
          emptyMessage: 'Mark daily attendance by worker, shift, and status.',
          children: (snapshot.data ?? const <HrAttendanceModel>[])
              .map(
                (attendance) => _HrTile(
                  icon: Icons.event_available_outlined,
                  title: attendance.employeeNameSnapshot,
                  subtitle:
                      '${DateFormat('dd MMM yyyy').format(attendance.date)} • ${attendance.shift} • OT ${attendance.overtimeHours}',
                  trailing: attendance.status.replaceAll('_', ' '),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _WageList extends StatelessWidget {
  final HrRepository repository;

  const _WageList({required this.repository});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HrWageEntryModel>>(
      stream: repository.watchWageEntries(),
      builder: (context, snapshot) {
        return _HrListShell(
          loading: snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData,
          error: snapshot.error,
          emptyTitle: 'No wage entries yet',
          emptyMessage: 'Add wages or advances for workers and staff.',
          children: (snapshot.data ?? const <HrWageEntryModel>[])
              .map(
                (wage) => _HrTile(
                  icon: Icons.payments_outlined,
                  title: wage.employeeNameSnapshot,
                  subtitle:
                      '${DateFormat('dd MMM').format(wage.periodFrom)} - ${DateFormat('dd MMM yyyy').format(wage.periodTo)} • ${wage.payableDays} days',
                  trailing: '₹${wage.netAmount.toStringAsFixed(0)}',
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _HrListShell extends StatelessWidget {
  final bool loading;
  final Object? error;
  final String emptyTitle;
  final String emptyMessage;
  final List<Widget> children;

  const _HrListShell({
    required this.loading,
    required this.error,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: zBlue));
    }

    if (error != null) {
      return _HrEmptyState(
        icon: Icons.error_outline,
        title: 'Unable to load HR records',
        message: error.toString(),
      );
    }

    if (children.isEmpty) {
      return _HrEmptyState(
        icon: Icons.badge_outlined,
        title: emptyTitle,
        message: emptyMessage,
      );
    }

    return ListView.separated(
      itemCount: children.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => children[index],
    );
  }
}

class _HrTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;

  const _HrTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: zBlueSoft,
            child: Icon(icon, color: zBlue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? 'Untitled' : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: zText,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: zMuted,
                    fontSize: 12.6,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            trailing,
            style: const TextStyle(
              color: zMuted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HrEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _HrEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: zBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: zMuted),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: zText,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: zMuted,
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
