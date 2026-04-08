import 'package:flutter/material.dart';

const TextStyle kPrimaryPageTitleStyle = TextStyle(
  fontSize: 34 / 1.55,
  fontWeight: FontWeight.w400,
  color: Color(0xFF151515),
  height: 1.15,
);

Widget primaryPageTitle(String text) {
  return Text(
    text,
    style: kPrimaryPageTitleStyle,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );
}
