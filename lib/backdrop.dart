// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import 'category.dart';

const double _kFlingVelocity = 2.0;

class _BackdropPanel extends StatelessWidget {
  const _BackdropPanel({
    Key key,
    this.onTap,
    this.onVerticalDragUpdate,
    this.onVerticalDragEnd,
    this.title,
    this.child,
  }) : super(key: key);

  final VoidCallback onTap;
  final GestureDragUpdateCallback onVerticalDragUpdate;
  final GestureDragEndCallback onVerticalDragEnd;
  final Widget title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2.0,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(16.0),
        topRight: Radius.circular(16.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          GestureDetector(
            // 全部區域可接收事件，並禁止事件後傳
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: onVerticalDragUpdate,
            onVerticalDragEnd: onVerticalDragEnd,
            onTap: onTap,
            child: Container(
              height: 48.0,
              padding: EdgeInsetsDirectional.only(start: 16.0),
              // 對齊方式：靠左置中
              alignment: AlignmentDirectional.centerStart,
              child: DefaultTextStyle(
                style: Theme.of(context).textTheme.subhead,
                child: title,
              ),
            ),
          ),
          Divider(
            height: 1.0,
          ),
          Expanded(
            child: child,
          ),
        ],
      ),
    );
  }
}

class _BackdropTitle extends AnimatedWidget {
  final Widget frontTitle;
  final Widget backTitle;

  const _BackdropTitle({
    Key key,
    Listenable listenable,
    this.frontTitle,
    this.backTitle,
  }) : super(key: key, listenable: listenable);

  @override
  Widget build(BuildContext context) {
    final Animation<double> animation = this.listenable;
    // 使用預設樣式
    return DefaultTextStyle(
      // 預設為系統title樣式的TextStyle
      style: Theme.of(context).primaryTextTheme.title,
      // 不斷行的文字
      softWrap: false,
      // 溢出的內容加上...
      overflow: TextOverflow.ellipsis,
      // Here, we do a custom cross fade between backTitle and frontTitle.
      // This makes a smooth animation between the two texts.
      child: Stack(
        children: <Widget>[
          Opacity(
            // 透明度為一非線性動畫
            opacity: CurvedAnimation(
              // 執行相反的動畫
              parent: ReverseAnimation(animation),
              // https://docs.flutter.io/flutter/animation/Interval-class.html
              curve: Interval(0.5, 1.0),
            ).value,
            child: backTitle,
          ),
          Opacity(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Interval(0.5, 1.0),
            ).value,
            child: frontTitle,
          ),
        ],
      ),
    );
  }
}

/// Builds a Backdrop.
///
/// A Backdrop widget has two panels, front and back. The front panel is shown
/// by default, and slides down to show the back panel, from which a user
/// can make a selection. The user can also configure the titles for when the
/// front or back panel is showing.
class Backdrop extends StatefulWidget {
  final Category currentCategory;
  final Widget frontPanel;
  final Widget backPanel;
  final Widget frontTitle;
  final Widget backTitle;

  const Backdrop({
    @required this.currentCategory,
    @required this.frontPanel,
    @required this.backPanel,
    @required this.frontTitle,
    @required this.backTitle,
  })  : assert(currentCategory != null),
        assert(frontPanel != null),
        assert(backPanel != null),
        assert(frontTitle != null),
        assert(backTitle != null);

  @override
  _BackdropState createState() => _BackdropState();
}

class _BackdropState extends State<Backdrop>
    with SingleTickerProviderStateMixin {
  // SingleTickerProviderStateMixin使State可以使用一個AnimationController
  // 若要使用多個動畫可以用TickerProviderStateMixin
  final GlobalKey _backdropKey = GlobalKey(debugLabel: 'Backdrop');
  AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // This creates an [AnimationController] that can allows for animation for
    // the BackdropPanel. 0.00 means that the front panel is in "tab" (hidden)
    // mode, while 1.0 means that the front panel is open.
    _controller = AnimationController(
      duration: Duration(milliseconds: 300),
      // 動畫的預設值
      // 實際預設的位置由panelAnimation決定
      value: 1.0,
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(Backdrop old) {
    super.didUpdateWidget(old);
    // widget重載時，若選擇的類別不同，切換動畫狀態
    if (widget.currentCategory != old.currentCategory) {
      setState(() {
        _controller.fling(
            velocity:
                _backdropPanelVisible ? -_kFlingVelocity : _kFlingVelocity);
      });
    }
    // frontPanel預設為開啟，若widget重載時應為關閉，則觸發關閉動畫
    else if (!_backdropPanelVisible) {
      setState(() {
        _controller.fling(velocity: _kFlingVelocity);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _backdropPanelVisible {
    // 當動畫正在播放or完成時，_backdropPanelVisible=true
    final AnimationStatus status = _controller.status;
    return status == AnimationStatus.completed ||
        status == AnimationStatus.forward;
  }

  void _toggleBackdropPanelVisibility() {
    // 根據_backdropPanelVisible的狀態控制動畫執行方向
    _controller.fling(
        velocity: _backdropPanelVisible ? -_kFlingVelocity : _kFlingVelocity);
  }

  double get _backdropHeight {
    // 取得frontPanel的高度
    final RenderBox renderBox = _backdropKey.currentContext.findRenderObject();
    return renderBox.size.height;
  }

  // By design: the panel can only be opened with a swipe. To close the panel
  // the user must either tap its heading or the backdrop's menu icon.

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_controller.isAnimating ||
        _controller.status == AnimationStatus.completed) return;

    _controller.value -= details.primaryDelta / _backdropHeight;
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_controller.isAnimating ||
        _controller.status == AnimationStatus.completed) return;

    // 根據frontPanel拖移距離決定動畫是展開或縮回
    final double flingVelocity =
        details.velocity.pixelsPerSecond.dy / _backdropHeight;
    if (flingVelocity < 0.0)
      _controller.fling(velocity: math.max(_kFlingVelocity, -flingVelocity));
    else if (flingVelocity > 0.0)
      _controller.fling(velocity: math.min(-_kFlingVelocity, -flingVelocity));
    else
      _controller.fling(
          velocity:
              _controller.value < 0.5 ? -_kFlingVelocity : _kFlingVelocity);
  }

  Widget _buildStack(BuildContext context, BoxConstraints constraints) {
    const double panelTitleHeight = 48.0;
    final Size panelSize = constraints.biggest;
    final double panelTop = panelSize.height - panelTitleHeight;

    Animation<RelativeRect> panelAnimation = RelativeRectTween(
      begin: RelativeRect.fromLTRB(
          0.0, panelTop, 0.0, panelTop - panelSize.height),
      end: RelativeRect.fromLTRB(0.0, 0.0, 0.0, 0.0),
    ).animate(_controller.view);

    return Container(
      // 確保frontPanel被拖移時此物件能存活
      key: _backdropKey,
      color: widget.currentCategory.color,
      child: Stack(
        children: <Widget>[
          widget.backPanel,
          // 位移動畫
          PositionedTransition(
            rect: panelAnimation,
            child: _BackdropPanel(
              onTap: _toggleBackdropPanelVisibility,
              onVerticalDragUpdate: _handleDragUpdate,
              onVerticalDragEnd: _handleDragEnd,
              title: Text(widget.currentCategory.name),
              child: widget.frontPanel,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: widget.currentCategory.color,
        elevation: 0.0,
        leading: IconButton(
          onPressed: _toggleBackdropPanelVisibility,
          icon: AnimatedIcon(
            // https://docs.flutter.io/flutter/material/AnimatedIcons-class.html
            icon: AnimatedIcons.close_menu,
            // 傳入_controller的Animation<double>
            progress: _controller.view,
          ),
        ),
        title: _BackdropTitle(
          listenable: _controller.view,
          frontTitle: widget.frontTitle,
          backTitle: widget.backTitle,
        ),
      ),
      body: LayoutBuilder(
        builder: _buildStack,
      ),
    );
  }
}
