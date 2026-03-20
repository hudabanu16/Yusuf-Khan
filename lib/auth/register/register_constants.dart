import 'package:flutter/material.dart';

const Color regTealTop = Color(0xFF0F6A6C);
const Color regCanvasBg = Color(0xFFF3F6FB);
const Color regBorder = Color(0xFFD9E1EC);
const Color regText = Color(0xFF111827);
const Color regMuted = Color(0xFF667085);
const Color regBlue = Color(0xFF3167E3);
const Color regSuccess = Color(0xFF16A34A);
const Color regFieldBg = Color(0xFFF8FAFC);
const Color regIconBg = Color(0xFFF1F5F9);
const Color regSidebarTone = Color(0xFF2A4A66);

class RegisterConstants {
  static const List<String> entityTypes = [
    'Private Limited Company',
    'Public Limited Company',
    'One Person Company (OPC)',
    'Limited Liability Partnership (LLP)',
    'Partnership Firm',
    'Proprietorship',
    'Hindu Undivided Family (HUF)',
    'Section 8 Company',
    'Trust',
    'Society',
    'Association of Persons (AOP)',
    'Body of Individuals (BOI)',
    'Branch Office',
    'Liaison Office',
    'Subsidiary Company',
    'Foreign Company',
    'Government Company',
    'Statutory Corporation',
    'Other',
  ];

  static const List<String> employeeRanges = [
    '1',
    '2 to 5',
    '6 to 10',
    '11 to 20',
    '21 to 50',
    '51 to 100',
    '101 to 250',
    '251 to 500',
    '501 to 1000',
    '1000+',
  ];

  static const List<String> industryTypes = [
    'Manufacturing',
    'Service',
    'Manufacturing & Service',
    'Trading',
    'Consulting',
    'Construction',
    'Engineering',
    'Export / Import',
    'Healthcare',
    'Education',
    'Technology / SaaS',
    'Other',
  ];

  static const Map<String, List<String>> subIndustriesByIndustry = {
    'Manufacturing': [
      'Welding Equipment',
      'Machine Tools',
      'Electrical Equipment',
      'Industrial Machinery',
      'Fabrication',
      'Auto Components',
      'Consumables',
      'Electronics',
      'Other Manufacturing',
    ],
    'Service': [
      'Repair & Maintenance',
      'Annual Maintenance Contract',
      'Installation & Commissioning',
      'Field Service',
      'Consulting Service',
      'Training Service',
      'Software Service',
      'Business Support',
      'Other Service',
    ],
    'Manufacturing & Service': [
      'Welding Equipment + Service',
      'Industrial Machinery + Service',
      'Electrical Equipment + Service',
      'Fabrication + AMC',
      'Machine Tools + Service',
      'Equipment Sales + After Sales',
      'Engineering Projects + Service',
      'Other Hybrid Industry',
    ],
    'Trading': [
      'Industrial Products',
      'Electrical Trading',
      'Consumables Trading',
      'Hardware Trading',
      'Import Trading',
      'Export Trading',
      'Other Trading',
    ],
    'Consulting': [
      'Business Consulting',
      'Legal Consulting',
      'Technical Consulting',
      'Financial Consulting',
      'Compliance Consulting',
      'Other Consulting',
    ],
    'Construction': [
      'Civil Construction',
      'Industrial Construction',
      'MEP Contracting',
      'Infrastructure',
      'Interior Fitout',
      'Other Construction',
    ],
    'Engineering': [
      'Mechanical Engineering',
      'Electrical Engineering',
      'Automation',
      'Design Engineering',
      'Project Engineering',
      'Other Engineering',
    ],
    'Export / Import': [
      'Industrial Export',
      'Industrial Import',
      'Merchant Export',
      'International Supply',
      'Other Export / Import',
    ],
    'Healthcare': [
      'Clinic',
      'Hospital',
      'Medical Equipment',
      'Diagnostic Center',
      'Pharmacy',
      'Other Healthcare',
    ],
    'Education': [
      'School',
      'College',
      'Coaching Institute',
      'Skill Training',
      'Online Education',
      'Other Education',
    ],
    'Technology / SaaS': [
      'CRM Software',
      'ERP Software',
      'SaaS Platform',
      'Mobile App',
      'IT Services',
      'Automation Software',
      'Other Technology',
    ],
    'Other': [
      'General Business',
      'Multi Business',
      'Custom Industry',
    ],
  };

  static const List<String> listingStatuses = [
    'Unlisted',
    'Listed',
    'Planning to list',
  ];

  static const List<String> registrationStatuses = [
    'Registered',
    'Applied',
    'Not Registered',
  ];

  static const List<String> indiaStates = [
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chhattisgarh',
    'Delhi',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Madhya Pradesh',
    'Maharashtra',
    'Odisha',
    'Punjab',
    'Rajasthan',
    'Tamil Nadu',
    'Telangana',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
  ];
}