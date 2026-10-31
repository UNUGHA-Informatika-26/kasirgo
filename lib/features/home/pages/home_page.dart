import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/home_cubit.dart';
import '../../cart/pages/cart_page.dart';
import '../../dashboard/pages/dashboard_page.dart';
import '../../products/pages/products_page.dart';
import '../../reports/pages/reports_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeCubit(),
      child: BlocBuilder<HomeCubit, int>(
        builder: (context, selectedIndex) => Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: SafeArea(
            child: IndexedStack(
              index: selectedIndex,
              children: [
                DashboardPage(
                  onMulaiTransaksi: () =>
                      context.read<HomeCubit>().selectTab(2),
                ),
                const ProductsPage(),
                const CartPage(),
                const ReportsPage(),
              ],
            ),
          ),
          bottomNavigationBar: CustomBottomNavBar(
            selectedIndex: selectedIndex,
            onTap: context.read<HomeCubit>().selectTab,
          ),
        ),
      ),
    );
  }
}

class CustomBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2563EB);
    const activeBgColor = Color(0xFFEFF6FF); // Background pill biru muda
    const darkIconColor = Color(0xFF0F172A); // Outline ikon hitam/gelap
    const unselectedTextColor = Color(0xFF64748B);

    final items = [
      _NavBarItemData(
        label: 'Beranda',
        icon: Icons.house_outlined,
        iconSize: 26,
      ),
      _NavBarItemData(
        label: 'Barang',
        icon: Icons.inventory_2_outlined,
        iconSize: 24,
      ),
      _NavBarItemData(
        label: 'Kasir',
        icon: Icons.desktop_windows_outlined,
        iconSize: 24,
      ),
      _NavBarItemData(
        label: 'Laporan',
        icon: Icons.description_outlined,
        iconSize: 24,
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1.0)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (index) {
            final isSelected = selectedIndex == index;
            final item = items[index];

            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(index),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? activeBgColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        color: darkIconColor,
                        size: item.iconSize,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isSelected ? primaryBlue : unselectedTextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Garis indikator biru di bawah teks aktif
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: isSelected ? 22 : 0,
                        height: 3.5,
                        decoration: BoxDecoration(
                          color: isSelected ? primaryBlue : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavBarItemData {
  final String label;
  final IconData icon;
  final double iconSize;

  _NavBarItemData({
    required this.label,
    required this.icon,
    this.iconSize = 24,
  });
}
