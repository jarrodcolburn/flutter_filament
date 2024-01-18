import 'dart:async';
import 'package:flutter/material.dart';
import '../filament_controller.dart';

enum GestureType { RotateCamera, PanCamera, PanBackground }

///
/// A widget that translates finger/mouse gestures to zoom/pan/rotate actions.
///
class FilamentGestureDetectorMobile extends StatefulWidget {
  ///
  /// The content to display below the gesture detector/listener widget.
  /// This will usually be a FilamentWidget (so you can navigate by directly interacting with the viewport), but this is not necessary.
  /// It is equally possible to render the viewport/gesture controls elsewhere in the widget hierarchy. The only requirement is that they share the same [FilamentController].
  ///
  final Widget? child;

  ///
  /// The [controller] attached to the [FilamentWidget] you wish to control.
  ///
  final FilamentController controller;

  ///
  /// If true, an overlay will be shown with buttons to toggle whether pointer movements are interpreted as:
  /// 1) rotate or a pan (mobile only),
  /// 2) moving the camera or the background image (TODO).
  ///
  final bool showControlOverlay;

  ///
  /// If false, all gestures will be ignored.
  ///
  final bool enableGestures;

  final bool enablePick;

  final double zoomDelta;

  FilamentGestureDetectorMobile(
      {Key? key,
      required this.controller,
      this.child,
      this.showControlOverlay = false,
      this.enableGestures = true,
      this.zoomDelta = 1,
      required this.enablePick})
      : super(key: key) {
    if (enablePick) {
      throw Exception("TODO");
    }
  }

  @override
  State<StatefulWidget> createState() => _FilamentGestureDetectorMobileState();
}

class _FilamentGestureDetectorMobileState
    extends State<FilamentGestureDetectorMobile> {
  GestureType gestureType = GestureType.PanCamera;

  final _icons = {
    GestureType.PanBackground: Icons.image,
    GestureType.PanCamera: Icons.pan_tool,
    GestureType.RotateCamera: Icons.rotate_90_degrees_ccw
  };

  // on mobile, we can't differentiate between pointer down events like we do on desktop with primary/secondary/tertiary buttons
  // we allow the user to toggle between panning and rotating by double-tapping the widget
  bool _rotateOnPointerMove = false;

  //
  //
  //
  bool _scaling = false;

  // to avoid duplicating code for pan/rotate (panStart, panUpdate, panEnd, rotateStart, rotateUpdate etc)
  // we have only a single function for start/update/end.
  // when the gesture type is changed, these properties are updated to point to the correct function.
  late Function(double x, double y) _functionStart;
  late Function(double x, double y) _functionUpdate;
  late Function() _functionEnd;

  @override
  void initState() {
    _setFunction();
    super.initState();
  }

  void _setFunction() {
    switch (gestureType) {
      case GestureType.RotateCamera:
        _functionStart = widget.controller.rotateStart;
        _functionUpdate = widget.controller.rotateUpdate;
        _functionEnd = widget.controller.rotateEnd;
        break;
      case GestureType.PanCamera:
        _functionStart = widget.controller.panStart;
        _functionUpdate = widget.controller.panUpdate;
        _functionEnd = widget.controller.panEnd;
        break;
      // TODO
      case GestureType.PanBackground:
        _functionStart = (x, y) async {};
        _functionUpdate = (x, y) async {};
        _functionEnd = () async {};
    }
  }

  @override
  void didUpdateWidget(FilamentGestureDetectorMobile oldWidget) {
    if (widget.showControlOverlay != oldWidget.showControlOverlay ||
        widget.enableGestures != oldWidget.enableGestures) {
      setState(() {});
    }

    super.didUpdateWidget(oldWidget);
  }

  Timer? _scrollTimer;
  double _lastScale = 0;

  // pinch zoom on mobile
  // couldn't find any equivalent for pointerCount in Listener so we use two widgets:
  // - outer is a GestureDetector only for pinch zoom
  // - inner is a Listener for all other gestures (including scroll zoom on desktop)
  @override
  Widget build(BuildContext context) {
    if (!widget.enableGestures) {
      return widget.child ?? Container();
    }

    return Stack(children: [
      Positioned.fill(
          child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: () {
                setState(() {
                  _rotateOnPointerMove = !_rotateOnPointerMove;
                });
              },
              onScaleStart: (d) async {
                if (d.pointerCount == 2) {
                  _scaling = true;
                  await widget.controller.zoomBegin();
                } else if (!_scaling) {
                  if (_rotateOnPointerMove) {
                    widget.controller.rotateStart(
                        d.localFocalPoint.dx, d.localFocalPoint.dy);
                  } else {
                    widget.controller
                        .panStart(d.localFocalPoint.dx, d.localFocalPoint.dy);
                  }
                }
              },
              onScaleUpdate: (ScaleUpdateDetails d) async {
                if (d.pointerCount == 2) {
                  if (d.horizontalScale != _lastScale) {
                    widget.controller.zoomUpdate(
                        d.localFocalPoint.dx,
                        d.localFocalPoint.dy,
                        d.horizontalScale > _lastScale ? 0.1 : -0.1);
                    _lastScale = d.horizontalScale;
                  }
                } else if (!_scaling) {
                  if (_rotateOnPointerMove) {
                    widget.controller
                        .rotateUpdate(d.focalPoint.dx, d.focalPoint.dy);
                  } else {
                    widget.controller
                        .panUpdate(d.focalPoint.dx, d.focalPoint.dy);
                  }
                }
              },
              onScaleEnd: (d) async {
                if (d.pointerCount == 2) {
                  widget.controller.zoomEnd();
                } else if (!_scaling) {
                  if (_rotateOnPointerMove) {
                    widget.controller.rotateEnd();
                  } else {
                    widget.controller.panEnd();
                  }
                }
                _scaling = false;
              },
              child: widget.child)),
      widget.showControlOverlay
          ? Align(
              alignment: Alignment.bottomRight,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    var curIdx = GestureType.values.indexOf(gestureType);
                    var nextIdx = curIdx == GestureType.values.length - 1
                        ? 0
                        : curIdx + 1;
                    gestureType = GestureType.values[nextIdx];
                    _setFunction();
                  });
                },
                child: Container(
                    padding: const EdgeInsets.all(50),
                    child: Icon(_icons[gestureType], color: Colors.green)),
              ))
          : Container()
    ]);
  }
}
