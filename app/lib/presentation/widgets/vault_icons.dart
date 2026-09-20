import 'package:flutter/cupertino.dart';

/// Shared outline glyphs for the compact, dark vault UI.
/// Use 14px for metadata, 18–20px for actions, and 28px for headers.
abstract final class VaultIcons {
  static const muted = Color(0xFFA7B0C0);
  static const accent = Color(0xFF82B6FF);
  static const danger = Color(0xFFEF9393);

  static const search = CupertinoIcons.search;
  static const chevronDown = CupertinoIcons.chevron_down;
  static const close = CupertinoIcons.xmark;
  static const add = CupertinoIcons.plus;
  static const info = CupertinoIcons.info;
  static const settings = CupertinoIcons.slider_horizontal_3;
  static const list = CupertinoIcons.list_bullet;
  static const link = CupertinoIcons.link;
  static const person = CupertinoIcons.person;
  static const password = CupertinoIcons.lock;
  static const lock = CupertinoIcons.lock;
  static const shield = CupertinoIcons.shield;
  static const eye = CupertinoIcons.eye;
  static const eyeOff = CupertinoIcons.eye_slash;
  static const back = CupertinoIcons.arrow_left;
  static const export = CupertinoIcons.square_arrow_up;
  static const restore = CupertinoIcons.arrow_counterclockwise;
  static const edit = CupertinoIcons.pencil;
  static const delete = CupertinoIcons.trash;
  static const power = CupertinoIcons.power;
  static const network = CupertinoIcons.antenna_radiowaves_left_right;
  static const code = CupertinoIcons.chevron_left_slash_chevron_right;
  static const cloud = CupertinoIcons.cloud;
  static const storage = CupertinoIcons.layers;
  static const check = CupertinoIcons.check_mark;
  static const success = CupertinoIcons.checkmark_circle;
  static const warning = CupertinoIcons.exclamationmark_triangle;
  static const error = CupertinoIcons.exclamationmark_circle;
  static const keyboard = CupertinoIcons.keyboard;
  static const record = CupertinoIcons.circle_filled;
  static const history = CupertinoIcons.clock;
}
