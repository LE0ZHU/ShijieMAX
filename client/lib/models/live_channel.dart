class LiveChannel {
  final String name;
  final String url;
  final String? logo;
  final String group;

  LiveChannel({
    required this.name,
    required this.url,
    this.logo,
    required this.group,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'url': url,
    'logo': logo,
    'group': group,
  };

  factory LiveChannel.fromJson(Map<String, dynamic> json) => LiveChannel(
    name: json['name'] as String,
    url: json['url'] as String,
    logo: json['logo'] as String?,
    group: json['group'] as String,
  );
}

class LiveChannelGroup {
  final String name;
  final List<LiveChannel> channels;

  LiveChannelGroup({
    required this.name,
    required this.channels,
  });
}

List<LiveChannelGroup> get builtinLiveGroups {
  return [
    LiveChannelGroup(name: '游戏赛事', channels: [
      LiveChannel(name: 'B站 热门赛事', url: 'http://dns.yiandrive.com:15907/bilibili/10', logo: 'https://epg.yang-1989.eu.org/logo/哔哩哔哩.png', group: '游戏赛事'),
      LiveChannel(name: 'B站 CS 2', url: 'https://cdn-3.ttvb.eu.org/bilibili/21622811', logo: 'https://epg.yang-1989.eu.org/logo/哔哩哔哩.png', group: '游戏赛事'),
      LiveChannel(name: '虎牙 CS 2', url: 'https://cdn-3.ttvb.eu.org/huya/483917', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '游戏赛事'),
      LiveChannel(name: 'B站 英雄联盟', url: 'https://cdn-3.ttvb.eu.org/bilibili/6', logo: 'https://epg.yang-1989.eu.org/logo/哔哩哔哩.png', group: '游戏赛事'),
      LiveChannel(name: '虎牙 英雄联盟 1', url: 'https://cdn-3.ttvb.eu.org/huya/660000', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '游戏赛事'),
      LiveChannel(name: '虎牙 英雄联盟 2', url: 'https://cdn-3.ttvb.eu.org/huya/660001', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '游戏赛事'),
      LiveChannel(name: '斗鱼 英雄联盟 1', url: 'https://cdn-3.ttvb.eu.org/douyu/288016', logo: 'https://epg.yang-1989.eu.org/logo/斗鱼.png', group: '游戏赛事'),
      LiveChannel(name: '斗鱼 英雄联盟 2', url: 'https://cdn-3.ttvb.eu.org/douyu/424559', logo: 'https://epg.yang-1989.eu.org/logo/斗鱼.png', group: '游戏赛事'),
      LiveChannel(name: 'B站 英雄联盟手游', url: 'https://cdn-3.ttvb.eu.org/bilibili/23138275', logo: 'https://epg.yang-1989.eu.org/logo/哔哩哔哩.png', group: '游戏赛事'),
      LiveChannel(name: 'B站 王者荣耀 1', url: 'https://cdn-3.ttvb.eu.org/bilibili/55', logo: 'https://epg.yang-1989.eu.org/logo/哔哩哔哩.png', group: '游戏赛事'),
      LiveChannel(name: 'B站 王者荣耀 2', url: 'https://cdn-3.ttvb.eu.org/bilibili/21654762', logo: 'https://epg.yang-1989.eu.org/logo/哔哩哔哩.png', group: '游戏赛事'),
      LiveChannel(name: '虎牙 王者荣耀 1', url: 'https://cdn-3.ttvb.eu.org/huya/660002', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '游戏赛事'),
      LiveChannel(name: '虎牙 王者荣耀 2', url: 'https://cdn-3.ttvb.eu.org/huya/660164', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '游戏赛事'),
      LiveChannel(name: '斗鱼 王者荣耀 1', url: 'https://cdn-3.ttvb.eu.org/douyu/1863767', logo: 'https://epg.yang-1989.eu.org/logo/斗鱼.png', group: '游戏赛事'),
      LiveChannel(name: '斗鱼 王者荣耀 2', url: 'https://cdn-3.ttvb.eu.org/douyu/1984839', logo: 'https://epg.yang-1989.eu.org/logo/斗鱼.png', group: '游戏赛事'),
      LiveChannel(name: 'B站 绝地求生', url: 'https://cdn-3.ttvb.eu.org/bilibili/98', logo: 'https://epg.yang-1989.eu.org/logo/哔哩哔哩.png', group: '游戏赛事'),
      LiveChannel(name: '虎牙 绝地求生 1', url: 'https://cdn-3.ttvb.eu.org/huya/660004', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '游戏赛事'),
      LiveChannel(name: '虎牙 绝地求生 2', url: 'https://cdn-3.ttvb.eu.org/huya/660005', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '游戏赛事'),
      LiveChannel(name: '斗鱼 绝地求生', url: 'https://cdn-3.ttvb.eu.org/douyu/100', logo: 'https://epg.yang-1989.eu.org/logo/斗鱼.png', group: '游戏赛事'),
      LiveChannel(name: '虎牙 和平精英', url: 'https://cdn-3.ttvb.eu.org/huya/660006', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '游戏赛事'),
      LiveChannel(name: '斗鱼 和平精英', url: 'https://cdn-3.ttvb.eu.org/douyu/999', logo: 'https://epg.yang-1989.eu.org/logo/斗鱼.png', group: '游戏赛事'),
      LiveChannel(name: '虎牙 金铲铲之战', url: 'https://cdn-3.ttvb.eu.org/huya/660579', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '游戏赛事'),
      LiveChannel(name: '斗鱼 金铲铲之战', url: 'https://cdn-3.ttvb.eu.org/douyu/9715241', logo: 'https://epg.yang-1989.eu.org/logo/斗鱼.png', group: '游戏赛事'),
      LiveChannel(name: '虎牙 DOTA2', url: 'https://cdn-3.ttvb.eu.org/huya/660118', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '游戏赛事'),
      LiveChannel(name: '斗鱼 DOTA2', url: 'https://cdn-3.ttvb.eu.org/douyu/3811559', logo: 'https://epg.yang-1989.eu.org/logo/斗鱼.png', group: '游戏赛事'),
      LiveChannel(name: '斗鱼 云顶之弈', url: 'https://cdn-3.ttvb.eu.org/douyu/522423', logo: 'https://epg.yang-1989.eu.org/logo/斗鱼.png', group: '游戏赛事'),
      LiveChannel(name: '虎牙 永劫无间', url: 'https://cdn-3.ttvb.eu.org/huya/660115', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '游戏赛事'),
      LiveChannel(name: '斗鱼 永劫无间', url: 'https://cdn-3.ttvb.eu.org/huya/9662891', logo: 'https://epg.yang-1989.eu.org/logo/斗鱼.png', group: '游戏赛事'),
      LiveChannel(name: 'B站 使命召唤手游', url: 'https://cdn-3.ttvb.eu.org/bilibili/22741849', logo: 'https://epg.yang-1989.eu.org/logo/哔哩哔哩.png', group: '游戏赛事'),
      LiveChannel(name: '虎牙 使命召唤手游', url: 'https://cdn-3.ttvb.eu.org/huya/11718629', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '游戏赛事'),
      LiveChannel(name: '斗鱼 使命召唤手游', url: 'https://cdn-3.ttvb.eu.org/douyu/9223245', logo: 'https://epg.yang-1989.eu.org/logo/斗鱼.png', group: '游戏赛事'),
      LiveChannel(name: '虎牙 穿越火线', url: 'https://cdn-3.ttvb.eu.org/huya/660101', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '游戏赛事'),
      LiveChannel(name: '斗鱼 穿越火线 1', url: 'https://cdn-3.ttvb.eu.org/douyu/605964', logo: 'https://epg.yang-1989.eu.org/logo/斗鱼.png', group: '游戏赛事'),
      LiveChannel(name: '斗鱼 穿越火线 2', url: 'https://cdn-3.ttvb.eu.org/douyu/5388537', logo: 'https://epg.yang-1989.eu.org/logo/斗鱼.png', group: '游戏赛事'),
      LiveChannel(name: '虎牙 穿越火线手游', url: 'https://cdn-3.ttvb.eu.org/huya/660102', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '游戏赛事'),
      LiveChannel(name: 'B站 第五人格', url: 'https://cdn-3.ttvb.eu.org/bilibili/5555', logo: 'https://epg.yang-1989.eu.org/logo/哔哩哔哩.png', group: '游戏赛事'),
      LiveChannel(name: '虎牙 第五人格', url: 'https://cdn-3.ttvb.eu.org/huya/idvesports', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '游戏赛事'),
      LiveChannel(name: '斗鱼 第五人格', url: 'https://cdn-3.ttvb.eu.org/douyu/3226194', logo: 'https://epg.yang-1989.eu.org/logo/斗鱼.png', group: '游戏赛事'),
      LiveChannel(name: '虎牙 逆战', url: 'https://cdn-3.ttvb.eu.org/huya/nsl2021', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '游戏赛事'),
      LiveChannel(name: 'B站 无畏契约', url: 'https://cdn-3.ttvb.eu.org/bilibili/22908869', logo: 'https://epg.yang-1989.eu.org/logo/哔哩哔哩.png', group: '游戏赛事'),
      LiveChannel(name: '虎牙 无畏契约', url: 'https://cdn-3.ttvb.eu.org/huya/660679', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '游戏赛事'),
      LiveChannel(name: '斗鱼 无畏契约', url: 'https://cdn-3.ttvb.eu.org/douyu/4585645', logo: 'https://epg.yang-1989.eu.org/logo/斗鱼.png', group: '游戏赛事'),
      LiveChannel(name: '斗鱼 原神', url: 'https://cdn-3.ttvb.eu.org/douyu/10853239', logo: 'https://epg.yang-1989.eu.org/logo/斗鱼.png', group: '游戏赛事'),
      LiveChannel(name: 'B站 QQ飞车手游', url: 'https://cdn-3.ttvb.eu.org/bilibili/21743919', logo: 'https://epg.yang-1989.eu.org/logo/哔哩哔哩.png', group: '游戏赛事'),
      LiveChannel(name: '斗鱼 QQ飞车手游', url: 'https://cdn-3.ttvb.eu.org/douyu/5040227', logo: 'https://epg.yang-1989.eu.org/logo/斗鱼.png', group: '游戏赛事'),
      LiveChannel(name: '斗鱼 梦幻西游手游', url: 'https://cdn-3.ttvb.eu.org/huya/9163712', logo: 'https://epg.yang-1989.eu.org/logo/斗鱼.png', group: '游戏赛事'),
      LiveChannel(name: '斗鱼 街霸', url: 'https://cdn-3.ttvb.eu.org/huya/11437', logo: 'https://epg.yang-1989.eu.org/logo/斗鱼.png', group: '游戏赛事'),
      LiveChannel(name: 'B站 JJ斗地主', url: 'https://cdn-3.ttvb.eu.org/bilibili/22021983', logo: 'https://epg.yang-1989.eu.org/logo/哔哩哔哩.png', group: '游戏赛事'),
      LiveChannel(name: '斗鱼 JJ斗地主', url: 'https://cdn-3.ttvb.eu.org/douyu/488743', logo: 'https://epg.yang-1989.eu.org/logo/斗鱼.png', group: '游戏赛事'),
      LiveChannel(name: '斗鱼 我的世界', url: 'https://cdn-3.ttvb.eu.org/douyu/738878', logo: 'https://epg.yang-1989.eu.org/logo/斗鱼.png', group: '游戏赛事'),
      LiveChannel(name: '斗鱼 FIFA', url: 'https://cdn-3.ttvb.eu.org/douyu/7692166', logo: 'https://epg.yang-1989.eu.org/logo/斗鱼.png', group: '游戏赛事'),
      LiveChannel(name: '斗鱼 火影忍者', url: 'https://cdn-3.ttvb.eu.org/douyu/1997723', logo: 'https://epg.yang-1989.eu.org/logo/斗鱼.png', group: '游戏赛事'),
      LiveChannel(name: '斗鱼 跑跑卡丁车', url: 'https://cdn-3.ttvb.eu.org/douyu/7722576', logo: 'https://epg.yang-1989.eu.org/logo/斗鱼.png', group: '游戏赛事'),
      LiveChannel(name: '斗鱼 跑跑卡丁车手游', url: 'https://cdn-3.ttvb.eu.org/douyu/6672862', logo: 'https://epg.yang-1989.eu.org/logo/斗鱼.png', group: '游戏赛事'),
    ]),
    LiveChannelGroup(name: '影视轮播', channels: [
      LiveChannel(name: '音乐石榴', url: 'https://cdn-3.ttvb.eu.org/huya/17091681', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '影视轮播'),
      LiveChannel(name: '音乐速递', url: 'https://cdn-3.ttvb.eu.org/huya/19439762', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '影视轮播'),
      LiveChannel(name: '治愈放松', url: 'https://cdn-3.ttvb.eu.org/huya/21241811', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '影视轮播'),
      LiveChannel(name: '阅读学习', url: 'https://cdn-3.ttvb.eu.org/huya/21241813', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '影视轮播'),
      LiveChannel(name: '电视剧 1', url: 'https://cdn-3.ttvb.eu.org/huya/21277391', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '影视轮播'),
      LiveChannel(name: '电视剧 2', url: 'https://cdn-3.ttvb.eu.org/huya/25018873', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '影视轮播'),
      LiveChannel(name: '电影 1', url: 'https://cdn-3.ttvb.eu.org/huya/20289754', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '影视轮播'),
      LiveChannel(name: '电影 2', url: 'https://cdn-3.ttvb.eu.org/huya/24983280', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '影视轮播'),
      LiveChannel(name: '电影 3', url: 'https://cdn-3.ttvb.eu.org/huya/24396428', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '影视轮播'),
      LiveChannel(name: '动漫 1', url: 'https://cdn-3.ttvb.eu.org/huya/19757963', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '影视轮播'),
      LiveChannel(name: '恐怖电影', url: 'https://cdn-3.ttvb.eu.org/huya/23419131', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '影视轮播'),
      LiveChannel(name: '漫威', url: 'https://cdn-3.ttvb.eu.org/huya/17089779', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '影视轮播'),
      LiveChannel(name: '美剧', url: 'https://cdn-3.ttvb.eu.org/huya/20488841', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '影视轮播'),
      LiveChannel(name: '七龙珠', url: 'https://cdn-3.ttvb.eu.org/huya/25650806', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '影视轮播'),
      LiveChannel(name: '止戈电影', url: 'https://cdn-3.ttvb.eu.org/huya/19863777', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '影视轮播'),
      LiveChannel(name: '挨饿德 1', url: 'https://cdn-3.ttvb.eu.org/huya/20985858', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '影视轮播'),
      LiveChannel(name: '挨饿德 2', url: 'https://cdn-3.ttvb.eu.org/huya/17693860', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '影视轮播'),
      LiveChannel(name: '互扇巴掌大赛', url: 'https://cdn-3.ttvb.eu.org/huya/20072873', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '影视轮播'),
      LiveChannel(name: '荒野求生', url: 'https://cdn-3.ttvb.eu.org/huya/593667', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '影视轮播'),
      LiveChannel(name: '野行者', url: 'https://cdn-3.ttvb.eu.org/huya/20072663', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '影视轮播'),
      LiveChannel(name: '跳舞', url: 'https://cdn-3.ttvb.eu.org/huya/24634408', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '影视轮播'),
      LiveChannel(name: '茶啊二中', url: 'https://cdn-3.ttvb.eu.org/huya/11213191', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '影视轮播'),
      LiveChannel(name: '哆啦A梦', url: 'https://cdn-3.ttvb.eu.org/huya/11601963', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '影视轮播'),
      LiveChannel(name: '航海王', url: 'https://cdn-3.ttvb.eu.org/huya/16913382', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '影视轮播'),
      LiveChannel(name: '七龙珠', url: 'https://cdn-3.ttvb.eu.org/huya/11601966', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '影视轮播'),
      LiveChannel(name: '猫和老鼠', url: 'https://cdn-3.ttvb.eu.org/huya/11352879', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '影视轮播'),
      LiveChannel(name: '中华小当家', url: 'https://cdn-3.ttvb.eu.org/huya/11342413', logo: 'https://epg.yang-1989.eu.org/logo/虎牙.png', group: '影视轮播'),
    ]),
  ];
}
