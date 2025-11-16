import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:messenger_flutter/api/api_client.dart';
import 'package:video_player/video_player.dart';

String _guessMime(String url, {required bool video}) {
  final lower = url.toLowerCase();
  if (video) {
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.m3u8')) return 'application/x-mpegURL';
    return 'video/mp4';
  } else {
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    return 'audio/mpeg';
  }
}

String _dataUri(Uint8List bytes, String mime) {
  final b64 = base64Encode(bytes);
  return 'data:$mime;base64,$b64';
}

class VideoBubble extends StatefulWidget {
  final ApiClient client;
  final String url; // absolute or relative acceptable
  final String? mimeHint;

  const VideoBubble({
    super.key,
    required this.client,
    required this.url,
    this.mimeHint,
  });

  @override
  State<VideoBubble> createState() => _VideoBubbleState();
}

class _VideoBubbleState extends State<VideoBubble> {
  VideoPlayerController? _controller;
  Future<void>? _initFut;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (kIsWeb) {
      final bytes = await widget.client.getBytes(widget.url);
      final mime = widget.mimeHint ?? _guessMime(widget.url, video: true);
      final dataUrl = _dataUri(bytes, mime);
      _controller = VideoPlayerController.networkUrl(Uri.parse(dataUrl));
    } else {
      final token = await widget.client.getToken();
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
        httpHeaders: token != null && token.isNotEmpty
            ? {'Authorization': 'Bearer $token'}
            : <String, String>{},
      );
    }
    _initFut = _controller!.initialize();
    setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    if (ctrl == null) {
      return const SizedBox(
        width: 120,
        height: 80,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return FutureBuilder(
      future: _initFut,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(
            width: 120,
            height: 80,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final ar = ctrl.value.aspectRatio == 0
            ? 16 / 9
            : ctrl.value.aspectRatio;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 320,
                  maxHeight: 240,
                ),
                child: AspectRatio(
                  aspectRatio: ar,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoPlayer(ctrl),
                      if (!ctrl.value.isPlaying)
                        Container(
                          color: Colors.black26,
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      Positioned.fill(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              if (ctrl.value.isPlaying) {
                                await ctrl.pause();
                              } else {
                                await ctrl.play();
                              }
                              setState(() {});
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    ctrl.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  ),
                  onPressed: () async {
                    if (ctrl.value.isPlaying) {
                      await ctrl.pause();
                    } else {
                      await ctrl.play();
                    }
                    setState(() {});
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: () async {
                    await ctrl.pause();
                    await ctrl.seekTo(Duration.zero);
                    setState(() {});
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class AudioBubble extends StatefulWidget {
  final ApiClient client;
  final String url;
  final String? mimeHint;
  const AudioBubble({
    super.key,
    required this.client,
    required this.url,
    this.mimeHint,
  });

  @override
  State<AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<AudioBubble> {
  final _player = AudioPlayer();
  StreamSubscription? _posSub;
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      if (kIsWeb) {
        final bytes = await widget.client.getBytes(widget.url);
        final mime = widget.mimeHint ?? _guessMime(widget.url, video: false);
        final dataUrl = _dataUri(bytes, mime);
        await _player.setUrl(dataUrl);
      } else {
        final token = await widget.client.getToken();
        await _player.setAudioSource(
          AudioSource.uri(
            Uri.parse(widget.url),
            headers: token != null && token.isNotEmpty
                ? {'Authorization': 'Bearer $token'}
                : null,
          ),
        );
      }
      _duration = await _player.durationFuture;
      _posSub = _player.positionStream.listen((p) {
        setState(() => _position = p);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        width: 200,
        height: 40,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    String fmt(Duration d) {
      final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      final hh = d.inHours;
      return hh > 0 ? '$hh:$mm:$ss' : '$mm:$ss';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(_player.playing ? Icons.pause : Icons.play_arrow),
            onPressed: () async {
              if (_player.playing) {
                await _player.pause();
              } else {
                await _player.play();
              }
              setState(() {});
            },
          ),
          Text('${fmt(_position)} / ${fmt(_duration ?? Duration.zero)}'),
        ],
      ),
    );
  }
}
