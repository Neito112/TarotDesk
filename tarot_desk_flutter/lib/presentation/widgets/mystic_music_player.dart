import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../core/display_labels.dart';
import '../../logic/settings_provider.dart';

/// Một bài nhạc huyền bí có sẵn (phát qua YouTube, nhạc ambient/thiền
/// hợp với không khí trải bài Tarot).
class MysticTrack {
  final String title;
  final String videoId;
  const MysticTrack({required this.title, required this.videoId});
}

/// 5 bài nhạc huyền bí có sẵn. Người dùng phát thêm bằng link YouTube
/// của mình ở ô nhập link bên dưới panel nhạc.
/// (Video ID lấy từ link YouTube thật; nếu một video bị chủ kênh
/// chặn nhúng thì chạm bài khác hoặc dán link của mình.)
const List<MysticTrack> kMysticTracks = [
  MysticTrack(
      title: 'Thiền The Fool — 432Hz (30 phút)',
      videoId: 'Beht63_bFHw'),
  MysticTrack(
      title: 'Vòng Lặp Vô Tận — nhạc Tarot',
      videoId: 'HlnHn2i_5ks'),
  MysticTrack(
      title: 'Bùa Chú Bóng Đêm — Dark Ambient',
      videoId: 'XWqgeFawCqc'),
  MysticTrack(
      title: 'Trống Hang & Sáo — nhạc huyền bí',
      videoId: 'DcCWB9sX-SM'),
  MysticTrack(
      title: 'Nghỉ Ngơi — Ethereal Ambient (8 giờ)',
      videoId: 'yzSqgYS-WI0'),
];

/// Trích video ID (11 ký tự) từ link YouTube hoặc ID trần.
/// Nhận: youtube.com/watch?v=ID, youtu.be/ID, /shorts/ID, /embed/ID,
/// /live/ID, music.youtube.com/watch?v=ID, hoặc ID trần (11 ký tự).
/// Trả về null nếu không nhận ra link.
String? extractYoutubeVideoId(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;
  final idPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');
  // ID trần (11 ký tự).
  if (idPattern.hasMatch(text)) return text;
  final uri = Uri.tryParse(text);
  if (uri == null) return null;
  // watch?v=ID (kể cả music.youtube.com).
  final v = uri.queryParameters['v'];
  if (v != null && idPattern.hasMatch(v)) return v;
  final segments = uri.pathSegments;
  // /shorts/ID, /embed/ID, /live/ID, /v/ID.
  for (int i = 0; i + 1 < segments.length; i++) {
    final s = segments[i];
    if (s == 'shorts' || s == 'embed' || s == 'live' || s == 'v') {
      final id = segments[i + 1];
      if (idPattern.hasMatch(id)) return id;
    }
  }
  // youtu.be/ID (chỉ một đoạn path).
  if (segments.length == 1 && idPattern.hasMatch(segments[0])) {
    return segments[0];
  }
  return null;
}

/// Panel nhạc huyền bí (bottom sheet): bài đang phát + phát/dừng,
/// âm lượng, danh sách 5 bài có sẵn, ô nhập link YouTube để phát nhạc.
///
/// Panel là một route riêng (bottom sheet) nên nó giữ state hiển thị
/// của riêng nó (bài đang chọn, âm lượng) và báo về màn hình qua
/// callback để đổi bài / đổi âm lượng thật trên controller. Khi mở
/// panel lần sau, nó khởi tạo lại từ state của màn hình (đang phát
/// bài nào, âm lượng bao nhiêu).
class MysticMusicSheet extends StatefulWidget {
  final YoutubePlayerController controller;
  final List<MysticTrack> tracks;
  final int currentIndex; // -1 = đang phát link YouTube tự nhập
  final String currentTitle;
  final double volume; // 0..100
  final TextEditingController linkController;
  final ValueChanged<int> onSelectTrack;
  final void Function(String videoId, String title) onPlayCustom;
  final ValueChanged<double> onVolumeChanged;

  const MysticMusicSheet({
    Key? key,
    required this.controller,
    required this.tracks,
    required this.currentIndex,
    required this.currentTitle,
    required this.volume,
    required this.linkController,
    required this.onSelectTrack,
    required this.onPlayCustom,
    required this.onVolumeChanged,
  }) : super(key: key);

  @override
  State<MysticMusicSheet> createState() => _MysticMusicSheetState();
}

class _MysticMusicSheetState extends State<MysticMusicSheet> {
  late int _currentIndex;
  late String _currentTitle;
  late double _volume;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;
    _currentTitle = widget.currentTitle;
    _volume = widget.volume;
  }

  void _playCustomLink() {
    final settings = context.read<SettingsProvider>();
    final videoId = extractYoutubeVideoId(widget.linkController.text);
    if (videoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(settings.tr('music.invalidLink')),
        ),
      );
      return;
    }
    final title =
        settings.tr('music.youtubeTitle').replaceAll('{id}', videoId);
    setState(() {
      _currentIndex = -1;
      _currentTitle = title;
    });
    widget.onPlayCustom(videoId, title);
    widget.linkController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    // Bài đang phát: bài preset (index >= 0) hiện tên đã dịch theo
    // index — tiêu đề thô trong _currentTitle (do màn Trải bài truyền
    // vào) không bao giờ hiện. Link tự nhập (index -1) hiện tiêu đề
    // đã dịch sẵn từ 'music.youtubeTitle'.
    final nowPlayingTitle = _currentIndex >= 0
        ? settings.tr(trackTitleKey(_currentIndex))
        : _currentTitle;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1426),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tay kéo.
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.music_note, color: Colors.amber, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    settings.tr('music.title'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  tooltip: settings.tr('music.closeTooltip'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Bài đang phát + phát/dừng + âm lượng.
            Row(
              children: [
                YoutubeValueBuilder(
                  controller: widget.controller,
                  builder: (context, value) {
                    final playing =
                        value.playerState == PlayerState.playing;
                    return IconButton(
                      icon: Icon(
                        playing
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        size: 40,
                        color: Colors.amber,
                      ),
                      tooltip: playing
                          ? settings.tr('music.pause')
                          : settings.tr('music.play'),
                      // API youtube_player_iframe 6.x: playVideo() /
                      // pauseVideo() (không có play()/pause()); giá trị
                      // YoutubePlayerValue cũng không có isReady nên
                      // nút luôn bật — video đã được cue sẵn từ lúc
                      // tạo controller (fromVideoId) nên bấm là phát.
                      onPressed: () {
                        playing
                            ? widget.controller.pauseVideo()
                            : widget.controller.playVideo();
                      },
                    );
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nowPlayingTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.volume_down,
                    color: Colors.white54, size: 20),
                Expanded(
                  child: Slider(
                    value: _volume,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: '${_volume.round()}',
                    activeColor: Colors.amber,
                    onChanged: (v) {
                      setState(() => _volume = v);
                      widget.onVolumeChanged(v);
                    },
                  ),
                ),
                const Icon(Icons.volume_up,
                    color: Colors.white54, size: 20),
              ],
            ),
            const Divider(color: Colors.white12),
            Text(
              settings.tr('music.presetTracks'),
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            ...widget.tracks.asMap().entries.map((entry) {
              final index = entry.key;
              final isCurrent = index == _currentIndex;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  isCurrent ? Icons.equalizer : Icons.music_note,
                  color: isCurrent ? Colors.amber : Colors.white54,
                ),
                title: Text(
                  settings.tr(trackTitleKey(index)),
                  style: TextStyle(
                    color: isCurrent ? Colors.amber : Colors.white,
                    fontSize: 14,
                    fontWeight:
                        isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isCurrent
                    ? Text(
                        settings.tr('music.nowPlaying'),
                        style: const TextStyle(
                            color: Colors.amber, fontSize: 12),
                      )
                    : null,
                onTap: () {
                  setState(() {
                    _currentIndex = index;
                    _currentTitle = settings.tr(trackTitleKey(index));
                  });
                  widget.onSelectTrack(index);
                },
              );
            }),
            const Divider(color: Colors.white12),
            Text(
              settings.tr('music.fromYoutube'),
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.linkController,
                    style:
                        const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: settings.tr('music.linkHint'),
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white10,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _playCustomLink(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  onPressed: _playCustomLink,
                  child: Text(settings.tr('music.playButton'),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              settings.tr('music.closeHint'),
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
