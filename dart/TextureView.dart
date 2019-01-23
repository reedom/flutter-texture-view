import 'package:flutter/widgets.dart';

/// TextureValue contains the current properties for a [TextureView].
/// And [TextureViewController] holds TextureValue as of its property.
class TextureValue {
  const TextureValue({
    this.textureId,
    this.size,
  });

  /// Non-null means there is a valid texture and the ID is used with a [Texture] widget
  /// to render the native device side's graphics.
  final int textureId;

  /// The size of the graphics context of the native device side.
  final Size size;

  /// Determines whether there is a valid texture in the native device side.
  bool get hasTexture => textureId != null;

  /// Create a new copy of this instance with some new values.
  TextureValue copyWith({int textureId, Size size}) {
    return TextureValue(
      textureId: textureId ?? this.textureId,
      size: size ?? this.size,
    );
  }

  /// Create a new copy of this instance with some new values.
  static TextureValue get empty => const TextureValue();
}

/// A interface of a TextureView controller, which controls a TextureView widget.
///
/// TextureView controllers are typically stored as member variables in [State]
/// objects and are reused in each [State.build]. In design, a controller
/// controls a single view.
///
/// A TextureView controller does:
///
/// *  Create a texture in the native device side.
///
/// *  Delete a texture in the native device side.
///
/// *  Order the native side to (re-)render the texture.
///    This manual operation is sometimes needed.
///    E.g. the app gets back from background in iOS.
///
/// *  Hold texture properties.
abstract class TextureViewController {
  /// Texture properties.
  TextureValue get value;

  /// Returns texture ID. It will create a new texture in the native device side
  /// if it does not exist yet.
  Future<int> getOrCreateTexture();

  /// Order the native side to (re-)render the texture.
  Future<void> render();

  /// Delete a texture in the native device side.
  Future<void> releaseTexture();
}

/// TextureView widget builds either [Texture] or [Container] according to its controller's state.
class TextureView<T extends TextureViewController> extends StatelessWidget {
  const TextureView(this.controller);

  final T controller;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
        future: controller.getOrCreateTexture(),
        builder: (context, snapshot) {
          return controller.value.hasTexture ? Texture(textureId: controller.value.textureId) : Container();
        });
  }
}
