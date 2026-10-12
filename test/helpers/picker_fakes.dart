import 'dart:async';

import 'package:image_picker/image_picker.dart';

/// Fake picker for the native boundary. Every picker call returns what the user
/// selected: nothing for single pickers, [selection] for the multi picker.
/// `noSuchMethod` forwards any other member, so the fake does not depend on the
/// exact parameter lists of the image_picker version.
class CancellingPicker implements ImagePicker {
  int pickCalls = 0;
  final List<XFile> selection;

  CancellingPicker({this.selection = const []});

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    if (name == #pickMultiImage) {
      pickCalls++;
      return Future<List<XFile>>.value(selection);
    }
    if (name == #pickImage || name == #pickVideo) {
      pickCalls++;
      return Future<XFile?>.value(null);
    }
    return super.noSuchMethod(invocation);
  }
}

/// Fake picker whose first presentation stays open until [release] is called.
/// Later presentations return immediately with no selection. Used to test that
/// the camera plugin refuses a second call while the first is still open.
class BlockingPicker implements ImagePicker {
  int pickCalls = 0;
  final Completer<void> _gate = Completer<void>();

  void release() {
    if (!_gate.isCompleted) _gate.complete();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    if (name == #pickImage || name == #pickVideo) {
      pickCalls++;
      if (pickCalls == 1) {
        return _gate.future.then<XFile?>((_) => null);
      }
      return Future<XFile?>.value(null);
    }
    if (name == #pickMultiImage) {
      pickCalls++;
      return Future<List<XFile>>.value(const []);
    }
    return super.noSuchMethod(invocation);
  }
}
