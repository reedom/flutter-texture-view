Flutter Texture Adapter
=======================

Background
-------------

This repository contains support classes for [Flutter Texture Widget][], I crafted during the development of my app, [scanaction][].

[Flutter Texture Widget][] just renders an image data.
I used `Texture` not only for camera preview stream rendering but also render a camera snapshot or an image from `ImagePicker`.

What I needed around the rendering were:
- receive image data from an image provider and pass it to `Texture` in time
- store image source data for repaint events

The classes work for those purposes.

Status
-------

At this moment I've just extracted those classes from my application. There is no example app nor document, they are to be done.

[Flutter Texture Widget]: https://docs.flutter.io/flutter/widgets/Texture-class.html
[scanaction]: http://bit.ly/itunes-scanaction-us
