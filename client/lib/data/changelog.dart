class ChangelogEntry {
  final String version;
  final String date;
  final List<String> changes;

  const ChangelogEntry({
    required this.version,
    required this.date,
    required this.changes,
  });
}

const changelog = <ChangelogEntry>[
  ChangelogEntry(
    version: '1.4.0',
    date: '2026-05-23',
    changes: [
      'AI影伴改为底部导航独立Tab页',
      '聊天记录跨页面持久化保存',
      'AI回复中断时显示重试按钮',
      '新增情绪找片（开心/emo/想哭/治愈）',
      '新增基于观看历史的个性化推荐',
      '新增清空对话功能',
      '我的页面布局优化',
    ],
  ),
  ChangelogEntry(
    version: '1.3.0',
    date: '2026-05-17',
    changes: [
      '修复播放器进度条拖动卡顿问题',
      '修复首页轮播图空数据除零崩溃',
      '修复进度条未加载时除零崩溃',
      '新增更新日志模块',
    ],
  ),
  ChangelogEntry(
    version: '1.2.0',
    date: '2026-05-16',
    changes: [
      '详情页支持VOD搜索播放源',
      '新增Hero海报过渡动画',
      '新增演职员信息展示',
      '新增移动网络流量播放提示',
      '新增设置页面（主题切换、版本下载）',
      '支持APK文件名自定义',
    ],
  ),
  ChangelogEntry(
    version: '1.1.0',
    date: '2026-05-15',
    changes: [
      '新增自定义下拉刷新指示器',
      '发现页TabBar毛玻璃效果',
      '分类卡片设计优化',
      'VOD搜索跨站点最佳匹配',
    ],
  ),
  ChangelogEntry(
    version: '1.0.1',
    date: '2026-05-14',
    changes: [
      '新增自定义播放器（手势控制、倍速、全屏）',
      '新增主题管理（深色/浅色/跟随系统）',
      '新增视差滚动组件',
      '多项UI细节优化',
    ],
  ),
  ChangelogEntry(
    version: '1.0.0',
    date: '2026-05-09',
    changes: [
      '视界MAX首次发布',
      '支持影视搜索、分类浏览',
      '支持在线播放、倍速调节',
      '支持收藏、观看历史记录',
      '支持深色/浅色主题切换',
    ],
  ),
];
