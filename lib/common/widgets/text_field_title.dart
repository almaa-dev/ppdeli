import 'package:flutter/material.dart';
import 'package:pickles_and_pies/util/dimensions.dart';
import 'package:pickles_and_pies/util/styles.dart';

class TextFieldTitle extends StatelessWidget {
  final String title;
  final bool requiredMark;
  
  const TextFieldTitle({
    super.key,
    required this.title, 
    this.requiredMark = false
  });
  
  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: <TextSpan>[
          TextSpan(
            text: title,  
            style: robotoMedium.copyWith(
              fontSize: Dimensions.fontSizeDefault, 
              color: Theme.of(context).textTheme.bodySmall?.color
            )
          ),
          TextSpan(
            text: requiredMark ? ' *' : "", 
            style: robotoMedium.copyWith(color: Colors.red)
          ),
        ]
      )
    );
  }
}
