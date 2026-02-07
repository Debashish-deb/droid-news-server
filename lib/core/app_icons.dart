import 'package:flutter/cupertino.dart';

/// Apple-inspired icon system using Material Icons
/// Clean, minimalist SF Symbol-style alternatives
class AppIcons {
  AppIcons._();

  // Navigation & Actions
  static const IconData home = CupertinoIcons.house_fill;
  static const IconData back = CupertinoIcons.back;
  static const IconData forward = CupertinoIcons.forward;
  static const IconData close = CupertinoIcons.xmark;
  static const IconData menu = CupertinoIcons.bars;
  static const IconData more = CupertinoIcons.ellipsis;

  static const IconData search = CupertinoIcons.search;
  static const IconData refresh = CupertinoIcons.refresh;
  static const IconData share = CupertinoIcons.share;
  static const IconData edit = CupertinoIcons.pencil;
  static const IconData delete = CupertinoIcons.delete; // or trash
  static const IconData add = CupertinoIcons.add;
  static const IconData save = CupertinoIcons.check_mark_circled;
  static const IconData cancel = CupertinoIcons.clear_circled;

  // Interaction
  static const IconData bookmark = CupertinoIcons.bookmark_fill;
  static const IconData bookmarkBorder = CupertinoIcons.bookmark;
  static const IconData favorite = CupertinoIcons.heart_fill;
  static const IconData favoriteBorder = CupertinoIcons.heart;
  static const IconData star = CupertinoIcons.star_fill;
  static const IconData starBorder = CupertinoIcons.star;
  static const IconData star_filled = CupertinoIcons.star_fill;

  // Content Types
  static const IconData article = CupertinoIcons.doc_text;
  static const IconData newspaper = CupertinoIcons.news;
  static const IconData magazine = CupertinoIcons.book;
  static const IconData image = CupertinoIcons.photo;
  static const IconData video = CupertinoIcons.play_circle;

  // User & Settings
  static const IconData person = CupertinoIcons.person_fill;
  static const IconData settings = CupertinoIcons.settings;
  static const IconData logout = CupertinoIcons.square_arrow_right; // close approximation to logout
  static const IconData login = CupertinoIcons.square_arrow_left; 

  // Communication
  static const IconData email = CupertinoIcons.mail;
  static const IconData phone = CupertinoIcons.phone;
  static const IconData chat = CupertinoIcons.chat_bubble;
  static const IconData notification = CupertinoIcons.bell;

  // Theme & Flags
  static const IconData lightMode = CupertinoIcons.sun_max;
  static const IconData darkMode = CupertinoIcons.moon;
  static const IconData palette = CupertinoIcons.paintbrush;
  static const IconData flag = CupertinoIcons.flag;

  // Text & Language
  static const IconData translate = CupertinoIcons.globe;
  static const IconData language = CupertinoIcons.text_cursor; // or globe
  static const IconData textFormat = CupertinoIcons.text_cursor;

  // Media Controls
  static const IconData play = CupertinoIcons.play_arrow_solid;
  static const IconData pause = CupertinoIcons.pause;
  static const IconData stop = CupertinoIcons.stop;
  static const IconData volume = CupertinoIcons.volume_up;
  static const IconData volumeOff = CupertinoIcons.volume_off;

  // Status
  static const IconData info = CupertinoIcons.info;
  static const IconData warning = CupertinoIcons.exclamationmark_triangle;
  static const IconData error = CupertinoIcons.exclamationmark_circle;
  static const IconData success = CupertinoIcons.check_mark_circled;
  static const IconData help = CupertinoIcons.question_circle;

  // Misc
  static const IconData calendar = CupertinoIcons.calendar;
  static const IconData clock = CupertinoIcons.time;
  static const IconData history = CupertinoIcons.clock;

  // Categories / Topics (Approximations in Cupertino)
  static const IconData sports = CupertinoIcons.sportscourt;
  static const IconData tech = CupertinoIcons.device_laptop;
  static const IconData business = CupertinoIcons.briefcase;
  static const IconData science = CupertinoIcons.lab_flask;
  static const IconData entertainment = CupertinoIcons.film;
  static const IconData fashion = CupertinoIcons.tag;
  static const IconData arts = CupertinoIcons.paintbrush;
  static const IconData lifestyle = CupertinoIcons.heart_circle;

  // Tools
  static const IconData filter = CupertinoIcons.slider_horizontal_3;
  static const IconData sort = CupertinoIcons.arrow_up_arrow_down;
  static const IconData download = CupertinoIcons.cloud_download;
  static const IconData upload = CupertinoIcons.cloud_upload;
  static const IconData link = CupertinoIcons.link;
  static const IconData copy = CupertinoIcons.doc_on_doc;

  // Nav Bar specific (often filled versions)
  static const IconData navHome = CupertinoIcons.house_fill;
  static const IconData navNewspaper = CupertinoIcons.news_solid;
  static const IconData navMagazine = CupertinoIcons.book_solid;
  static const IconData navSettings = CupertinoIcons.settings_solid;
}
