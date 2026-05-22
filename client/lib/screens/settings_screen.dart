import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/theme_provider.dart';
import '../data/changelog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '设置',
          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildThemeSection(context),
            const SizedBox(height: 16),
            _buildDownloadSection(context),
            const SizedBox(height: 16),
            _buildChangelogSection(context),
          ],
        ),
      ),
    );
  }

  // ── Theme Section ──

  Widget _buildThemeSection(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF16161E) : Colors.white;
    final textColor = isDark ? const Color(0xFFE0E0E8) : const Color(0xFF1A1A2E);
    final subtitleColor = isDark ? const Color(0xFF5A5A6E) : const Color(0xFF9E9E9E);

    return Consumer<ThemeProvider>(
      builder: (context, provider, _) {
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.palette_outlined, color: subtitleColor, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    '外观设置',
                    style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildThemeOption(
                context,
                icon: Icons.phone_android,
                title: '跟随系统',
                selected: provider.isSystem,
                onTap: () => provider.setThemeMode(ThemeMode.system),
                textColor: textColor,
                subtitleColor: subtitleColor,
              ),
              _buildThemeOption(
                context,
                icon: Icons.dark_mode,
                title: '深色模式',
                selected: provider.isDark,
                onTap: () => provider.setThemeMode(ThemeMode.dark),
                textColor: textColor,
                subtitleColor: subtitleColor,
              ),
              _buildThemeOption(
                context,
                icon: Icons.light_mode,
                title: '浅色模式',
                selected: provider.isLight,
                onTap: () => provider.setThemeMode(ThemeMode.light),
                textColor: textColor,
                subtitleColor: subtitleColor,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool selected,
    required VoidCallback onTap,
    required Color textColor,
    required Color subtitleColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE50914).withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? const Color(0xFFE50914) : subtitleColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: selected ? const Color(0xFFE50914) : textColor,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: Color(0xFFE50914), size: 20)
            else
              Icon(Icons.circle_outlined, color: subtitleColor.withOpacity(0.4), size: 20),
          ],
        ),
      ),
    );
  }

  // ── Download Section ──

  Widget _buildDownloadSection(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF16161E) : Colors.white;
    final textColor = isDark ? const Color(0xFFE0E0E8) : const Color(0xFF1A1A2E);
    final subtitleColor = isDark ? const Color(0xFF5A5A6E) : const Color(0xFF9E9E9E);

    return GestureDetector(
      onTap: () => _onDownloadTap(context),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE50914).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.system_update_rounded, color: Color(0xFFE50914), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '点击下载最新版本',
                    style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '暂不支持检查更新功能，待后续更新，请手动更新目前最新版本',
                    style: TextStyle(color: subtitleColor, fontSize: 12, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: subtitleColor.withOpacity(0.5), size: 22),
          ],
        ),
      ),
    );
  }

  void _onDownloadTap(BuildContext context) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE50914).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.download_rounded, color: Color(0xFFE50914), size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              '下载最新版本',
              style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          '是否下载视界MAX最新版本 APK？',
          style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontSize: 14, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontSize: 14)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE50914),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('下载', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      const url = 'https://gaolei-zhu.oss-cn-shanghai.aliyuncs.com/ShijieMAX/apk/ShijieMAX.apk';
      try {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法打开下载链接'), backgroundColor: Color(0xFFE50914)),
          );
        }
      }
    }
  }

  // ── Changelog Section ──

  Widget _buildChangelogSection(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF16161E) : Colors.white;
    final textColor = isDark ? const Color(0xFFE0E0E8) : const Color(0xFF1A1A2E);
    final subtitleColor = isDark ? const Color(0xFF5A5A6E) : const Color(0xFF9E9E9E);

    return GestureDetector(
      onTap: () => _showChangelog(context),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE50914).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.article_outlined, color: Color(0xFFE50914), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '更新日志',
                    style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'v${changelog.first.version} · ${changelog.first.date}',
                    style: TextStyle(color: subtitleColor, fontSize: 12, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: subtitleColor.withOpacity(0.5), size: 22),
          ],
        ),
      ),
    );
  }

  void _showChangelog(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFE0E0E8) : const Color(0xFF1A1A2E);
    final subtitleColor = isDark ? const Color(0xFF5A5A6E) : const Color(0xFF9E9E9E);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: subtitleColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE50914).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.article_outlined, color: Color(0xFFE50914), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '更新日志',
                    style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                itemCount: changelog.length,
                itemBuilder: (ctx, index) {
                  final entry = changelog[index];
                  final isLatest = index == 0;
                  return Padding(
                    padding: EdgeInsets.only(bottom: index < changelog.length - 1 ? 20 : 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: isLatest ? const Color(0xFFE50914) : subtitleColor.withOpacity(0.4),
                                shape: BoxShape.circle,
                              ),
                            ),
                            if (index < changelog.length - 1)
                              Container(
                                width: 2,
                                height: entry.changes.length * 28.0 + 16,
                                color: subtitleColor.withOpacity(0.15),
                              ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'v${entry.version}',
                                    style: TextStyle(
                                      color: isLatest ? const Color(0xFFE50914) : textColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    entry.date,
                                    style: TextStyle(color: subtitleColor, fontSize: 12),
                                  ),
                                  if (isLatest) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE50914).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        '最新',
                                        style: TextStyle(color: Color(0xFFE50914), fontSize: 10, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...entry.changes.map((c) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('· ', style: TextStyle(color: subtitleColor, fontSize: 13)),
                                    Expanded(
                                      child: Text(
                                        c,
                                        style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 13, height: 1.4),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
