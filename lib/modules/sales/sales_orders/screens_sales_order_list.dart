import 'package:flutter/material.dart';
import 'screens_sales_order_form.dart';

class SalesOrderListScreen extends StatelessWidget {
  const SalesOrderListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text(
              'Sales Order Module Started',
              style: TextStyle(
                fontSize: 18,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        ),
        Positioned(
          right: 24,
          bottom: 24,
          child: FloatingActionButton(
            onPressed: null,
            child: Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}