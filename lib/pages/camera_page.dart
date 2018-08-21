import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

import 'dart:async';
import 'dart:io';

import 'package:bikecouch/utils/bucket.dart';

import 'package:bikecouch/models/app_state.dart';
import 'package:bikecouch/app_state_container.dart';

import 'package:bikecouch/pages/challenge_results_page.dart';

import 'package:http/http.dart' as http;

class CameraPage extends StatefulWidget {
  CameraPage({this.cameras, this.challengeWords});
  final List<CameraDescription> cameras;
  final Set<String> challengeWords;

  @override
  _CameraPageState createState() => new _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  AppState appState;
  CameraController controller;
  final GlobalKey leftFocusBoxKey = GlobalKey();
  final GlobalKey rightFocusBoxKey = GlobalKey();
  final GlobalKey _stackBoxKey = GlobalKey();
  String imagePath;
  List<Anchor> anchors;
  bool _isLoading;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    _isLoading = false;
    anchors = List<Anchor>();
    super.initState();
    controller = new CameraController(widget.cameras[0], ResolutionPreset.high);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  _uploadPhoto(String filePath) async {
    // String url = await Bucket.uploadFile(filePath);

    // final File imageFile = File(filePath);
    // final im.Image src = Image(image: imageFile.readAsBytesSync());
    // im.Image left = im.copyCrop(src, 0, 0, src.width ~/ 2, src.height);
    // im.Image right = im.copyCrop(src, src.width ~/ 2, 0, src.width ~/ 2, src.height);

    // Navigator.of(context).push(MaterialPageRoute(
    //   builder: (context) => DisplayImagesTest(
    //     left: left.getBytes(),
    //     right: right.getBytes()
    //   )
    // ));

    // String leftb64 = base64Encode(left.getBytes());
    // String rightb64 = base64Encode(right.getBytes());

    String b64 = Bucket.imageToBase64String(filePath);
    String url =
        'https://us-central1-bikecouch.cloudfunctions.net/resize-crop-and-label';

    http.post(url, headers: {
      // 'uuid': '${appState.user.uuid}'
    }, body: {
      'image': b64,
      'left': widget.challengeWords.first,
      'right': widget.challengeWords.last,
      'anchors': jsonEncode({
        'left': anchors[0].toJson(),
        'right': anchors[1].toJson(),
      }),
    }).then(((response) {
      setState(() => _isLoading = false);
      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => ChallengeResults(
                  success: json.decode(response.body)['result'],
                ),
          ));
    }));
    // Bucket.uploadFile(filePath, appState.user.uuid);

    // VisionResponse vs = await ComputerVision.annotateImage(
    //     b64, AnnotationRequestMode.Base64String);
    // bool success = vs.annotations.any((annotation) {
    //   return widget.challengeWords.any((word) {
    //     return annotation.description == word;
    //   });
    // });
    // Navigator.of(context).push(MaterialPageRoute(
    //       builder: (context) => ChallengeResults(
    //             success: success,
    //           ),
    //     ));
    // free resources

    File(filePath).delete();
  }

  _makeSnackBar(String message) {
    final snackbar = SnackBar(content: Text(message));
    _scaffoldKey.currentState.showSnackBar(snackbar);
  }

  _takePhotoWrapper() {
    setState(() => _isLoading = true);
    _takePhoto().then((filePath) {
      if (mounted) {
        // setState(() => imagePath = filePath);
        _uploadPhoto(filePath);
      }
      if (filePath != null) {
        print('image saved to $filePath');
      }
    }).catchError((e) => setState(() {
          setState(() => _isLoading = false);
          _makeSnackBar(e);
        }));
  }

  _displayTakenPhoto() {
    setState(() => _isLoading = true);
    _takePhoto().then((filePath) {
      if (mounted) {
        setState(() {
          imagePath = filePath;
          _isLoading = false;
        });
      }
      if (filePath != null) {
        print('image saved to $filePath');
      }
    }).catchError((e) => setState(() {
          setState(() => _isLoading = false);
          _makeSnackBar(e);
        }));
  }

  Future<String> _takePhoto() async {
    print('taking picture');
    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}/Pictures/test';
    await Directory(dirPath).create(recursive: true);
    final String filePath = '$dirPath/${timestamp()}.jpg';

    if (controller.value.isTakingPicture) {
      print('already taking picture!!!');
      return null;
    }

    try {
      await controller.takePicture(filePath);
    } on CameraException catch (e) {
      print(e);
      return null;
    }
    return filePath;
  }

  String timestamp() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  @override
  Widget build(BuildContext context) {
    // var container = AppStateContainer.of(context);
    // appState = container.state;

    final overlay = Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max,
        children: [
          createFocusBox(leftFocusBoxKey),
          createFocusBox(rightFocusBoxKey),
        ]);

    if (!controller.value.isInitialized) {
      return new Container();
    }

    Widget _cameraBoxContent;
    FloatingActionButton _actionButton;

    if (imagePath == null) {
      _cameraBoxContent = Center(child: CameraPreview(controller));
      _actionButton = FloatingActionButton(
        child: RotatedBox(quarterTurns: 1, child: Icon(Icons.camera_alt)),
        onPressed: () => _displayTakenPhoto(),
      );
    } else {
      _cameraBoxContent = Image.file(File(imagePath));
      _actionButton = FloatingActionButton(
          child: Icon(Icons.navigate_next),
          onPressed: () {
            setState(() {
              anchors.add(getFocusAnchor());
            });
            if (anchors.length > 1) {
              _uploadPhoto(imagePath);
            }
            // File(imagePath).delete();
            // imagePath = null;
          });
    }

    double _deviceWidth = MediaQuery.of(context).size.width;
    double _deviceHeight = MediaQuery.of(context).size.height;

    // TODO: Add WillPopScope to catch back button press...
    return Scaffold(
      key: _scaffoldKey,
      body: new Container(
        color: Colors.black,
        child: new Column(
          children: <Widget>[
            new AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: new Stack(
                key: _stackBoxKey,
                children: <Widget>[
                  _cameraBoxContent,
                  _isLoading
                      ? Center(
                          child: CircularProgressIndicator(),
                        )
                      : Container(),
                  imagePath == null
                      ? Container()
                      : DraggableFocusBox(
                          Offset(
                            _deviceWidth / 2 - (2 * _deviceHeight + 100) / 2,
                            (_deviceHeight / 2) - (2 * _deviceHeight + 100) / 2,
                          ),
                          100.00,
                          100.00,
                          _stackBoxKey,
                          leftFocusBoxKey,
                        ),
                  // DraggableFocusBox(
                  //     rightFocusBoxKey,
                  //     Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.width * 2 / 3 + 20.00),
                  //     MediaQuery.of(context).size.width * 2 / 3,
                  //     MediaQuery.of(context).size.width * 2 / 3,
                  //     _stackBoxKey),
                  // overlay,
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _actionButton,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget createFocusBox(Key key) {
    final borderWidth = MediaQuery.of(context).size.width * 0.10;
    final borderShade = Colors.black12;
    return Expanded(
        child: Container(
            key: key,
            decoration: BoxDecoration(
                border: BorderDirectional(
              top: BorderSide(
                width: borderWidth / 2,
                color: borderShade,
              ),
              bottom: BorderSide(
                width: borderWidth / 2,
                color: borderShade,
              ),
              start: BorderSide(
                width: borderWidth,
                color: borderShade,
              ),
              end: BorderSide(
                width: borderWidth,
                color: borderShade,
              ),
            ))));
  }

  /*
    Calculates the UI overlay position anchors for better cropping of the taken image.
    TODO: Allow resizing of the overlay boxes./
  */
  Object getFocusAnchors() {
    RenderBox cameraBox = _stackBoxKey.currentContext.findRenderObject();
    final cameraHeight = cameraBox.paintBounds.height;
    final cameraWidth = cameraBox.paintBounds.width;

    // NOTE: This is a copy-paste from #createFocusBox, should be pulled out into a constant.
    final shadowWidth = MediaQuery.of(context).size.width * 0.10;

    // Extract the focusbox position and width MINUS the border.
    RenderBox leftBox = leftFocusBoxKey.currentContext.findRenderObject();
    RenderBox rightBox = rightFocusBoxKey.currentContext.findRenderObject();
    Offset leftBoxOffsetRaw = cameraBox
        .globalToLocal(leftBox.localToGlobal(leftBox.paintBounds.topLeft));
    // Offset leftBoxOffset = Offset(leftBoxOffsetRaw.dx + shadowWidth,
    //     leftBoxOffsetRaw.dx + shadowWidth / 2);
    // final leftBoxWidth = leftBox.paintBounds.width - 2 * shadowWidth;
    // final leftBoxHeight = leftBox.paintBounds.height - shadowWidth;
    Offset rightBoxOffsetRaw = cameraBox
        .globalToLocal(rightBox.localToGlobal(rightBox.paintBounds.topLeft));
    // Offset rightBoxOffset = Offset(rightBoxOffsetRaw.dx + shadowWidth,
    //     rightBoxOffsetRaw.dy + shadowWidth / 2);
    // final rightBoxWidth = rightBox.paintBounds.width - 2 * shadowWidth;
    // final rightBoxHeight = rightBox.paintBounds.height - shadowWidth;

    /*
    All returned sizes are RELATIVE to the full image size.
    That is necessary because the UI does not render in the same resolution as the camera.
    Alternativley, all sizes could be scaled UP to the full image resoltion, which one must know beforehand.

                       WIDTH
                  ---------------
                  |             |
                  |             |
                  |             |
         HEIGHT   |             |
                  |             |
                  |             |
                  |             |
                  |             |
                  |             |
                  |  <  @  []   |
    */
    return {
      'camera': {
        // This is UI pixesl !!!
        'height': cameraBox.paintBounds.height,
      },
      'left': {
        'dy_offset': leftBoxOffsetRaw.dy / cameraHeight,
        'dx_offset': leftBoxOffsetRaw.dx / cameraWidth,
        'width': leftBox.paintBounds.width / cameraWidth,
        'height': leftBox.paintBounds.height / cameraHeight,
      },
      'right': {
        'dy_offset': rightBoxOffsetRaw.dy / cameraHeight,
        'dx_offset': rightBoxOffsetRaw.dx / cameraWidth,
        'width': rightBox.paintBounds.width / cameraWidth,
        'height': rightBox.paintBounds.height / cameraHeight,
      }
    };
  }

  Anchor getFocusAnchor() {
    RenderBox cameraBox = _stackBoxKey.currentContext.findRenderObject();
    final cameraHeight = cameraBox.paintBounds.height;
    final cameraWidth = cameraBox.paintBounds.width;

    RenderBox leftBox = leftFocusBoxKey.currentContext.findRenderObject();
    Offset leftBoxOffsetRaw = cameraBox
        .globalToLocal(leftBox.localToGlobal(leftBox.paintBounds.topLeft));

    // Normalisation with regards to the camera size
    return Anchor(
      leftBoxOffsetRaw.dx / cameraWidth,
      leftBoxOffsetRaw.dy / cameraHeight,
      leftBox.paintBounds.width / cameraWidth,
      leftBox.paintBounds.height / cameraHeight,
    );
  }
}

enum ResizeMode { Move, Scale }

class DraggableFocusBox extends StatefulWidget {
  final Offset initPos;
  final double initWidth;
  final double initHeight;
  final GlobalKey parentKey;
  final GlobalKey cropBoxKey;

  DraggableFocusBox(this.initPos, this.initWidth, this.initHeight,
      this.parentKey, this.cropBoxKey);

  @override
  _DraggableFocusBoxState createState() => _DraggableFocusBoxState();
}

class _DraggableFocusBoxState extends State<DraggableFocusBox> {
  Offset position;
  double width;
  double height;
  double startWidth;
  double startHeight;

  //Dragging
  Offset _correctionPanPosition;

  @override
  void initState() {
    position = widget.initPos;
    width = widget.initWidth;
    height = widget.initHeight;

    super.initState();
  }

  //TODO: Implement uni-lateral scaling (rectangular)
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        child: Container(
          child: Container(
            key: widget.cropBoxKey,
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).primaryColor,
                width: 5.0,
                style: BorderStyle.solid,
              ),
            ),
            width: width,
            height: height,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.black45,
              width: MediaQuery.of(context).size.height,
            ),
          ),
        ),
        onScaleStart: onScaleStart,
        onScaleUpdate: onScaleUpdate,
        onScaleEnd: onScaleEnd,
      ),
    );
  }

  void onScaleStart(ScaleStartDetails details) {
    RenderBox parentBox = widget.parentKey.currentContext.findRenderObject();
    setState(() {
      startWidth = width;
      startHeight = height;
      _correctionPanPosition =
          parentBox.globalToLocal(details.focalPoint) - position;
    });
  }

  void onScaleUpdate(ScaleUpdateDetails details) {
    double scaledWidth;
    double scaledHeight;
    Offset scaledPos;
    RenderBox parent;

    // TODO: Implement boundary checks
    parent = widget.parentKey.currentContext.findRenderObject();
    scaledWidth = startWidth * details.scale;
    scaledHeight = startHeight * details.scale;
    scaledPos =
        parent.globalToLocal(details.focalPoint) - _correctionPanPosition;

    setState(() {
      width = scaledWidth;
      height = scaledHeight;
      position = scaledPos;
    });
  }

  void onScaleEnd(ScaleEndDetails details) {
    setState(() {
      startWidth = 0.0;
      startHeight = 0.0;
      _correctionPanPosition = Offset.zero;
    });
  }
}

class Anchor {
  final double dx;
  final double dy;
  final double width;
  final double height;

  Anchor(this.dx, this.dy, this.width, this.height);

  Object toJson() {
    return {
      'dx_offset': dx,
      'dy_offset': dy,
      'width': width,
      'height': height,
    };
  }
}
