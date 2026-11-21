import { media } from '@kit.MediaKit';
import { avSession } from '@kit.AVSessionKit';
import { common, wantAgent } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { fileIo as fs } from '@kit.CoreFileKit';

export class ListeningPlayer {
  private player?: media.AVPlayer;
  private session?: avSession.AVSession;
  private file?: fs.File;
  private context?: common.UIAbilityContext;
  private background: boolean = false;
  private generation: number = 0;
  private queue: Promise<void> = Promise.resolve();
  onError: (message: string) => void = () => {};
  onTime: (seconds: number) => void = () => {};
  onDuration: (seconds: number) => void = () => {};
  onPlaying: (playing: boolean) => void = () => {};
  onEnd: () => void = () => {};
  onStep: (direction: number) => void = () => {};

  private schedule(work: () => Promise<void>): void {
    this.queue = this.queue.then(work).catch((error: Error) => { this.onError(error.message); });
  }

  open(context: common.UIAbilityContext, url: string, surface: string, title: string, id: number): void {
    const generation = ++this.generation;
    this.schedule(async () => {
      await this.release();
      if (generation !== this.generation) { return; }
      this.context = context;
      const player = await media.createAVPlayer();
      this.player = player;
      player.on('error', (error) => { if (generation === this.generation) { this.onError(error.message); this.close(); } });
      player.on('timeUpdate', (ms: number) => { if (generation === this.generation) { this.onTime(ms / 1000); } });
      player.on('stateChange', (state: string) => {
        this.schedule(async () => {
          if (generation !== this.generation) { return; }
          if (state === 'initialized') { player.surfaceId = surface; await player.prepare(); }
          if (state === 'prepared') { this.onDuration(player.duration / 1000); }
          if (state === 'playing' || state === 'paused' || state === 'completed') {
            const playing = state === 'playing';
            this.onPlaying(playing);
            if (state === 'completed') { this.onEnd(); }
            if (this.session) {
              await this.session.setAVPlaybackState({
                state: playing ? avSession.PlaybackState.PLAYBACK_STATE_PLAY : avSession.PlaybackState.PLAYBACK_STATE_PAUSE,
                position: { elapsedTime: player.currentTime, updateTime: Date.now() }
              });
            }
            if (playing && !this.background) {
              const agent = await wantAgent.getWantAgent({
                wants: [{ bundleName: context.abilityInfo.bundleName, abilityName: context.abilityInfo.name }],
                operationType: wantAgent.OperationType.START_ABILITY, requestCode: 0,
                wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
              });
              await backgroundTaskManager.startBackgroundRunning(context, backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK, agent);
              this.background = true;
            } else if (!playing) { await this.stopBackground(); }
          }
        });
      });
      this.session = await avSession.createAVSession(context, 'RedFoxListening', 'audio');
      this.session.on('play', () => { this.start(); });
      this.session.on('pause', () => { this.pause(); });
      this.session.on('playPrevious', () => { if (generation === this.generation) { this.onStep(-1); } });
      this.session.on('playNext', () => { if (generation === this.generation) { this.onStep(1); } });
      this.session.on('seek', (ms: number) => { this.setCurrentTime(ms / 1000); });
      await this.session.setAVMetadata({ assetId: id.toString(), title: title });
      await this.session.activate();
      if (url.startsWith('file://')) {
        this.file = fs.openSync(url, fs.OpenMode.READ_ONLY);
        player.fdSrc = { fd: this.file.fd };
      } else { player.url = url; }
    });
  }
  start(): void {
    this.schedule(async () => {
      if (this.player && ['prepared', 'paused', 'completed'].includes(this.player.state)) { await this.player.play(); }
    });
  }
  pause(): void {
    this.schedule(async () => { if (this.player?.state === 'playing') { await this.player.pause(); } });
  }
  setCurrentTime(seconds: number): void {
    if (this.player && ['prepared', 'playing', 'paused', 'completed'].includes(this.player.state)) {
      this.player.seek(Math.round(seconds * 1000), media.SeekMode.SEEK_PREV_SYNC);
    }
  }
  close(): void { ++this.generation; this.schedule(async () => { await this.release(); }); }
  private async stopBackground(): Promise<void> {
    if (this.background && this.context) {
      await backgroundTaskManager.stopBackgroundRunning(this.context);
      this.background = false;
    }
  }
  private async release(): Promise<void> {
    try { await this.stopBackground(); } finally {
      try { await this.session?.destroy(); } finally {
        this.session = undefined;
        try { await this.player?.release(); } finally {
          this.player = undefined;
          if (this.file) { fs.closeSync(this.file); this.file = undefined; }
        }
      }
    }
  }
}
