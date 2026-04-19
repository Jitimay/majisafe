import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MajiSafeLogo extends StatelessWidget {
  final double? width;
  final double? height;
  
  const MajiSafeLogo({
    super.key,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/majisafe_logo.svg',
      width: width,
      height: height,
    );
  }
}
