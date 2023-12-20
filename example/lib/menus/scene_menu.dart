import 'package:flutter/material.dart';

import 'package:flutter_filament/filament_controller.dart';
import 'package:flutter_filament_example/menus/asset_submenu.dart';
import 'package:flutter_filament_example/menus/camera_submenu.dart';
import 'package:flutter_filament_example/menus/rendering_submenu.dart';

class SceneMenu extends StatefulWidget {
  final FilamentController? controller;

  const SceneMenu({super.key, required this.controller});

  @override
  State<StatefulWidget> createState() {
    return _SceneMenuState();
  }
}

class _SceneMenuState extends State<SceneMenu> {
  @override
  void didUpdateWidget(SceneMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null &&
        (widget.controller != oldWidget.controller ||
            widget.controller!.hasViewer != oldWidget.controller!.hasViewer)) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
        valueListenable:
            widget.controller?.hasViewer ?? ValueNotifier<bool>(false),
        builder: (BuildContext ctx, bool hasViewer, Widget? child) {
          return MenuAnchor(
            menuChildren: widget.controller == null
                ? []
                : <Widget>[
                    RenderingSubmenu(
                      controller: widget.controller!,
                    ),
                    AssetSubmenu(controller: widget.controller!),
                    CameraSubmenu(
                      controller: widget.controller!,
                    ),
                  ],
            builder: (BuildContext context, MenuController controller,
                Widget? child) {
              return TextButton(
                onPressed: !hasViewer
                    ? null
                    : () {
                        if (controller.isOpen) {
                          controller.close();
                        } else {
                          controller.open();
                        }
                      },
                child: const Text("Scene"),
              );
            },
          );
        });
  }
}
