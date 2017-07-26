enum PLAYBACK_STATUS
{
  INVALID,
  DOWNLOADING,
  VALID
}

::g_sound <- {
  [PERSISTENT_DATA_PARAMS] = ["playbackStatus", "curPlaying"]

  playbackStatus = {}
  curPlaying = ""
}

function g_sound::onCachedMusicDowloaded(playbackId, success)
{
  playbackStatus[playbackId] <- success? PLAYBACK_STATUS.VALID : PLAYBACK_STATUS.INVALID
  ::broadcastEvent("PlaybackDownloaded", {id = playbackId, success = success})
}

function g_sound::onCachedMusicPlayEnd(playbackId)
{
  curPlaying = ""
  ::broadcastEvent("FinishedPlayback", {id = playbackId})
}

function g_sound::preparePlayback(url, playbackId)
{
  if (::u.isEmpty(url)
      || getPlaybackStatus(playbackId) != PLAYBACK_STATUS.INVALID)
    return

  playbackStatus[playbackId] <- PLAYBACK_STATUS.DOWNLOADING
  ::set_cached_music(::CACHED_MUSIC_MISSION, url, playbackId)
}

function g_sound::play(playbackId = "")
{
  if (playbackId == "" && curPlaying == "")
    return

  if (getPlaybackStatus(playbackId) != PLAYBACK_STATUS.VALID)
    return

  if (::play_cached_music(playbackId))
    curPlaying = playbackId
}

function g_sound::stop()
{
  ::play_cached_music("")
  curPlaying = ""
}

function g_sound::getPlaybackStatus(playbackId)
{
  return ::getTblValue(playbackId, playbackStatus, PLAYBACK_STATUS.INVALID)
}

function g_sound::canPlay(playbackId)
{
  return getPlaybackStatus(playbackId) == PLAYBACK_STATUS.VALID
}

function g_sound::isPlaying(playbackId)
{
  return playbackId == curPlaying && curPlaying != ""
}

function g_sound::onEventGameLocalizationChanged(p)
{
  stop()
  playbackStatus.clear()
}

::g_script_reloader.registerPersistentDataFromRoot("g_sound")
::subscribe_handler(::g_sound, ::g_listener_priority.DEFAULT_HANDLER)

//C++ call
::on_cached_music_play_end <- ::g_sound.onCachedMusicPlayEnd.bindenv(::g_sound)
//C++ call
::on_cached_music_downloaded <- ::g_sound.onCachedMusicDowloaded.bindenv(::g_sound)