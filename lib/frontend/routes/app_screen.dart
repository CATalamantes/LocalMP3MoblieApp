/// Presentation destinations verified against the approved wireframes.
enum AppScreen {
  library('/library', 'Your Library'),
  playlist('/playlist', 'Playlist Details'),
  nowPlaying('/now-playing', 'Now Playing'),
  songDetails('/song-details', 'Lyrics & Song Details'),
  lyrics('/lyrics', 'Fullscreen Lyrics'),
  addMusic('/add-music', 'Add Music'),
  record('/record', 'Record Audio'),
  saveRecording('/save-recording', 'Save Recording / Track Information'),
  device('/device', 'Device'),
  connections('/connections', 'Connections'),
  sync('/sync', 'Music Sync'),
  storage('/storage', 'Storage'),
  files('/files', 'File Manager'),
  bluetoothAudio('/bluetooth-audio', 'Bluetooth Audio'),
  batteryDisplay('/battery-display', 'Battery & Display'),
  aboutDevice('/about-device', 'About Device'),
  statistics('/statistics', 'Listening Statistics');

  const AppScreen(this.route, this.title);

  final String route;
  final String title;

  static const mainScreens = [library, addMusic, device, statistics];
}
