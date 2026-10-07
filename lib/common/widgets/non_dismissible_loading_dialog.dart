import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:pickles_and_pies/util/dimensions.dart';
import 'package:pickles_and_pies/util/styles.dart';

/// A non-dismissible loading dialog used during sensitive, irreversible
/// operations such as Account Deletion.
///
/// Why `barrierDismissible: false`:
///   - The user must NOT be able to tap outside the dialog to close it
///     while a server-side delete request is in flight. Doing so would
///     leave the local / remote state in an inconsistent, undefined state.
///
/// Why `PointerInterceptor`:
///   - On the Web platform (and some embedded web views), clicks can fall
///     through to widgets stacked behind the dialog. Wrapping the content
///     in a `PointerInterceptor` guarantees the dialog captures every tap.
class NonDismissibleLoadingDialog extends StatelessWidget {
  final String message;

  const NonDismissibleLoadingDialog({
    super.key,
    required this.message,
  });

  /// Convenience helper that opens this dialog as a GetX dialog with all
  /// the safety flags correctly set.
  static void show({required String message}) {
    if (Get.isDialogOpen ?? false) {
      return;
    }
    Get.dialog(
      NonDismissibleLoadingDialog(message: message),
      barrierDismissible: false, // <-- The crucial safety flag.
      useSafeArea: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Disable Android system back-button dismissal as well.
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
        ),
        insetPadding: const EdgeInsets.all(40),
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: PointerInterceptor(
          child: SizedBox(
            width: 280,
            child: Padding(
              padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    height: 36,
                    width: 36,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeLarge),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: robotoMedium.copyWith(
                      fontSize: Dimensions.fontSizeDefault,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

