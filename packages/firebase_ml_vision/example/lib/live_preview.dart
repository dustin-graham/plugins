import 'dart:async';

import 'package:firebase_ml_vision/src/live_view.dart';
import 'package:firebase_ml_vision_example/detector_painters.dart';
import 'package:flutter/material.dart';

class LivePreview extends StatefulWidget {
  final Detector detector;

  const LivePreview(
    this.detector, {
    Key key,
  }) : super(key: key);

  @override
  LivePreviewState createState() {
    return new LivePreviewState();
  }
}

class LivePreviewState extends State<LivePreview> {
  bool _isShowingPreview = false;
  LiveViewCameraLoadStateReady _readyLoadState;

  Stream<LiveViewCameraLoadState> _prepareCameraPreview() async* {
    if (_readyLoadState != null) {
      yield _readyLoadState;
    } else {
      yield new LiveViewCameraLoadStateLoading();
      final List<LiveViewCameraDescription> cameras = await availableCameras();
      final backCamera = cameras.firstWhere((cameraDescription) =>
          cameraDescription.lensDirection == LiveViewCameraLensDirection.back);
      if (backCamera != null) {
        yield new LiveViewCameraLoadStateLoaded(backCamera);
        try {
          final LiveViewCameraController controller =
              new LiveViewCameraController(
                  backCamera, LiveViewResolutionPreset.high);
          await controller.initialize();
          yield new LiveViewCameraLoadStateReady(controller);
        } on LiveViewCameraException catch (e) {
          yield new LiveViewCameraLoadStateFailed(
              "error initializing camera controller: ${e.toString()}");
        }
      } else {
        yield new LiveViewCameraLoadStateFailed("Could not find device camera");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isShowingPreview) {
      return new StreamBuilder(
        stream: _prepareCameraPreview(),
        builder: (BuildContext context,
            AsyncSnapshot<LiveViewCameraLoadState> snapshot) {
          print("snapshot data: ${snapshot.data}");
          final loadState = snapshot.data;
          if (loadState != null) {
            if (loadState is LiveViewCameraLoadStateLoading) {
              return const Text("loading camera preview…");
            } else if (loadState is LiveViewCameraLoadStateLoaded) {
              // get rid of previous controller if there is one
              return new Text("loaded camera name: ${loadState
                  .cameraDescription
                  .name}");
            } else if (loadState is LiveViewCameraLoadStateReady) {
              ////// BINGO!!!, the camera is ready to present
              if (_readyLoadState != loadState) {
                _readyLoadState?.dispose();
                _readyLoadState = loadState;
              }
              return new AspectRatio(
                aspectRatio: _readyLoadState.controller.value.aspectRatio,
                child: new LiveView(_readyLoadState.controller),
              );
            } else if (loadState is LiveViewCameraLoadStateFailed) {
              return new Text("error loading camera ${loadState
                  .errorMessage}");
            } else {
              return const Text("Unknown Camera error");
            }
          } else {
            return new Text("Camera error: ${snapshot.error.toString()}");
          }
        },
      );
    } else {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text("Current detector: ${widget.detector}"),
          RaisedButton(
            onPressed: () {
              setState(() {
                _isShowingPreview = true;
              });
            },
            child: new Text("Start Live View"),
          ),
        ],
      );
    }
  }
}

abstract class LiveViewCameraLoadState {}

class LiveViewCameraLoadStateLoading extends LiveViewCameraLoadState {}

class LiveViewCameraLoadStateLoaded extends LiveViewCameraLoadState {
  final LiveViewCameraDescription cameraDescription;

  LiveViewCameraLoadStateLoaded(this.cameraDescription);
}

class LiveViewCameraLoadStateReady extends LiveViewCameraLoadState {
  final LiveViewCameraController controller;

  LiveViewCameraLoadStateReady(this.controller);

  void dispose() {
    controller.dispose();
  }
}

class LiveViewCameraLoadStateFailed extends LiveViewCameraLoadState {
  final String errorMessage;

  LiveViewCameraLoadStateFailed(this.errorMessage);
}
