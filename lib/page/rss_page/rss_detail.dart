import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_rss/main.dart';
import 'package:flutter_rss/model/rss.dart';
import 'package:flutter_rss/utils/adaptive.dart';
import 'package:flutter_rss/widgets/photo_view.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:share/share.dart';
import 'package:url_launcher/url_launcher.dart';

class RssDetail extends StatefulWidget {
  final RssItem rssItem;

  RssDetail({this.rssItem});

  @override
  _RssDetailState createState() => _RssDetailState();
}

class _RssDetailState extends State<RssDetail> {
  RssItem rssItem;

  String title = '';
  String time = '';
  String url = '';
  String author = '';
  String content = '';

  var isDesktop;

  ScrollController _controller = new ScrollController();
  bool showToTopBtn = false; //是否显示“返回到顶部”按钮

  @override
  void initState() {
    super.initState();
    rssItem = this.widget.rssItem;
    if (rssItem.title != null) {
      url = rssItem.url;
      title = rssItem.title;
      content = rssItem.content;
      time = rssItem.time;
      author = rssItem.author;
    }
    //监听滚动事件，打印滚动位置
    _controller.addListener(() {
//      print(_controller.offset); //打印滚动位置
      if (_controller.offset < 1000 && showToTopBtn) {
        setState(() {
          showToTopBtn = false;
        });
      } else if (_controller.offset >= 1000 && showToTopBtn == false) {
        setState(() {
          showToTopBtn = true;
        });
      }
    });

    // 设置监听事件
    bus.on("setRssItem", (arg) {
      setState(() {
        this.rssItem = arg;
      });
      //返回到顶部时执行动画
      _controller.animateTo(.0,
          duration: Duration(milliseconds: 200), curve: Curves.ease);
    });
  }

  @override
  void dispose() {
    //为了避免内存泄露，需要调用_controller.dispose
    _controller.dispose();
    bus.off("setRssItem");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    isDesktop = isDisplayDesktop(context);
    return new Scaffold(
        floatingActionButton: !showToTopBtn
            ? null
            : FloatingActionButton(
                heroTag: '222',
                child: Icon(Icons.arrow_upward),
                onPressed: () {
                  //返回到顶部时执行动画
                  _controller.animateTo(.0,
                      duration: Duration(milliseconds: 200),
                      curve: Curves.ease);
                }),
        body: CustomScrollView(
          controller: _controller,
          slivers: [
            buildRssDetailAppBar(rssItem),
            SliverList(
              delegate: SliverChildListDelegate([
                Container(
                  padding: EdgeInsets.all(15),
                  child: (rssItem.title == null)
                      ? new Container()
                      : new Column(
                          children: [buildRssHeader(), buildRssDetail(rssItem)],
                        ),
                )
              ]),
            ),
          ],
        ));
  }

  // 构建RSS详情页的appBar
  Widget buildRssDetailAppBar(RssItem item) {
    return SliverAppBar(
      leading: IconButton(
        icon: isDesktop ? Icon(Icons.call_split) : Icon(Icons.arrow_back),
        onPressed: () {
          if (isDesktop) {
            // todo 这里用于将左侧边栏隐藏
          } else {
            Navigator.pop(context, true);
          }
        },
      ),
      title: Text(item.title ?? ""),
      floating: true,
      actions: item.title == null
          ? <Widget>[]
          : <Widget>[
              new IconButton(
                  icon: Icon(
                    Icons.share,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    if (Platform.isMacOS) {
                      // todo 待完成MacOS上的文章分享功能
                      EasyLoading.showToast("暂不支持该平台的文章分享");
                    } else {
                      if (item.title != null) {
                        Share.share(item.title +
                            "\n来自：" +
                            item.author +
                            "\n访问：" +
                            item.url +
                            "\n分享自：RSS 阅读器");
                      }
                    }
                  }),
              new IconButton(
                  icon: Icon(
                    Icons.add_to_home_screen,
                    color: Colors.white,
                  ),
                  onPressed: () async {
                    if (await canLaunch(item.url)) {
                      await launch(item.url);
                    } else {
                      throw 'Could not launch $item.url';
                    }
                  })
            ],
    );
  }

  Widget buildRssHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(rssItem.title,
            style: TextStyle(color: Colors.black, fontSize: 24)),
        SizedBox(height: 10),
        Text(rssItem.author,
            style: TextStyle(fontSize: 16, color: Colors.black54)),
        SizedBox(height: 5),
        Text(rssItem.time,
            style: TextStyle(fontSize: 14, color: Colors.black54)),
        SizedBox(height: 10),
        Divider(),
      ],
    );
  }

  // 显示rss的内容，自定义解析器
  Widget buildRssDetail(RssItem item) {
    Widget htmlWidget;
    if (htmlWidget == null) {
      htmlWidget = HtmlWidget(
        item.content,
        webView: true,
        buildAsync: true,
        factoryBuilder: () => _MyWidgetFactory(),
      );
    }

    return htmlWidget;
  }
}

class _MyWidgetFactory extends WidgetFactory {
  _MyWidgetFactory();

  @override
  Widget buildImage(BuildMetadata meta, Object provider, ImageMetadata image) {
    return new Container(child: RssDetailImage(url: image.sources.first.url));
  }
}

// Rss详情页中图片加载自定义
class RssDetailImage extends StatefulWidget {
  final String url;

  const RssDetailImage({Key key, this.url}) : super(key: key);

  @override
  _RssDetailImageState createState() => _RssDetailImageState();
}

class _RssDetailImageState extends State<RssDetailImage> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: new CachedNetworkImage(
        imageUrl: this.widget.url,
        placeholder: (context, url) => new Center(
          child: CircularProgressIndicator(),
        ),
        errorWidget: (context, url, error) => Icon(Icons.error),
      ),
      onTap: () {
        Navigator.push(
          context,
          new MaterialPageRoute(
              builder: (context) => PhotoViewSimpleScreen(
                  imgUrl: this.widget.url, heroTag: 'simple')),
        );
      },
    );
  }
}
