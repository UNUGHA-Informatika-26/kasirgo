import 'package:flutter/material.dart';
import '../../dashboard/pages/dashboard_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  List<Widget> get _pages => [
        DashboardPage(
          onMulaiTransaksi: () {
            setState(() {
              _selectedIndex = 2; // Pindah ke Tab Kasir
            });
          },
        ),
        const _BarangView(),
        const _KasirView(),
        const _LaporanView(),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
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
    const activeBgColor = Color(0xFFE8F0FE); // Background pill biru muda
    const darkIconColor = Color(0xFF0F172A); // Outline ikon hitam/gelap
    const unselectedTextColor = Color(0xFF64748B);

    final items = [
      _NavBarItemData(
        label: 'Beranda',
        icon: Icons.home_outlined,
      ),
      _NavBarItemData(
        label: 'Barang',
        icon: Icons.inventory_2_outlined,
      ),
      _NavBarItemData(
        label: 'Kasir',
        icon: Icons.desktop_windows_outlined,
      ),
      _NavBarItemData(
        label: 'Laporan',
        icon: Icons.description_outlined,
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFF1F5F9), width: 1.0),
        ),
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
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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

  _NavBarItemData({
    required this.label,
    required this.icon,
  });
}

class _BarangView extends StatelessWidget {
  const _BarangView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_rounded, size: 64, color: Color(0xFF2563EB)),
          SizedBox(height: 12),
          Text(
            'Halaman Barang',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _KasirView extends StatelessWidget {
  const _KasirView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.desktop_windows_rounded, size: 64, color: Color(0xFF2563EB)),
          SizedBox(height: 12),
          Text(
            'Halaman Kasir',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _LaporanView extends StatelessWidget {
  const _LaporanView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_rounded, size: 64, color: Color(0xFF2563EB)),
          SizedBox(height: 12),
          Text(
            'Halaman Laporan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
