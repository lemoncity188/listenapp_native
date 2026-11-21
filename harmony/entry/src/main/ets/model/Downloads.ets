import { request } from '@kit.BasicServicesKit';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { Course, courseTitle } from './Models';

export interface DownloadEntry { id: number; name: string; categoryId: number; }
export class Downloads {
  private directory: string = '';
  private context?: common.UIAbilityContext;
  private tasks: Map<number, request.DownloadTask> = new Map();
  entries: DownloadEntry[] = [];
  onChange: () => void = () => {};
  onError: (message: string) => void = () => {};
  progress: Map<number, number> = new Map();
  init(context: common.UIAbilityContext): void {
    this.context = context; this.directory = context.filesDir + '/videos';
    if (!fs.accessSync(this.directory)) { fs.mkdirSync(this.directory); }
    const manifest = this.directory + '/manifest.json';
    if (fs.accessSync(manifest)) {
      this.entries = (JSON.parse(fs.readTextSync(manifest)) as DownloadEntry[]).filter((item: DownloadEntry) => fs.accessSync(this.directory + '/' + item.id + '.mp4'));
    }
  }
  localPath(id: number): string {
    const path = this.directory + '/' + id + '.mp4';
    return this.directory && fs.accessSync(path) ? fileUri.getUriFromPath(path) : '';
  }
  private persist(): void {
    const temp = this.directory + '/manifest.json.tmp';
    const file = fs.openSync(temp, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
    try { fs.writeSync(file.fd, JSON.stringify(this.entries)); } finally { fs.closeSync(file); }
    fs.renameSync(temp, this.directory + '/manifest.json');
  }
  async start(course: Course): Promise<void> {
    if (!this.context || this.progress.has(course.id)) { return; }
    const url = course.url || course.videoUrl || '';
    if (!/^https?:\/\//.test(url) || /\.m3u8(?:\?|$)/i.test(url)) { throw new Error('仅支持下载直接视频文件，HLS流请在线播放'); }
    const target = this.directory + '/' + course.id + '.mp4'; const temp = target + '.part';
    if (fs.accessSync(temp)) { fs.unlinkSync(temp); }
    this.progress.set(course.id, 0); this.onChange();
    try {
      const task = await request.downloadFile(this.context, { url: url, filePath: temp });
      this.tasks.set(course.id, task);
      task.on('progress', (received: number, total: number) => { this.progress.set(course.id, total > 0 ? Math.round(received * 100 / total) : 0); this.onChange(); });
      task.on('complete', () => {
        try {
          if (!fs.accessSync(temp) || fs.statSync(temp).size === 0) { throw new Error('下载文件为空'); }
          if (fs.accessSync(target)) { fs.unlinkSync(target); }
          fs.renameSync(temp, target);
          this.entries = this.entries.filter((item: DownloadEntry) => item.id !== course.id);
          this.entries.push({ id: course.id, name: courseTitle(course), categoryId: course.categoryId ?? 0 }); this.persist();
        } catch (error) { this.onError((error as Error).message); }
        this.progress.delete(course.id); this.tasks.delete(course.id); this.onChange();
      });
      task.on('fail', (code: number) => { this.progress.delete(course.id); this.tasks.delete(course.id); this.onError('视频下载失败：' + code); this.onChange(); });
    } catch (error) { this.progress.delete(course.id); this.onChange(); throw new Error((error as Error).message); }
  }
  async cancel(id: number): Promise<void> {
    await this.tasks.get(id)?.delete(); this.tasks.delete(id); this.progress.delete(id); this.onChange();
  }
  remove(id: number): void {
    if (this.progress.has(id)) { throw new Error('请先取消下载'); }
    const path = this.directory + '/' + id + '.mp4'; if (fs.accessSync(path)) { fs.unlinkSync(path); }
    this.entries = this.entries.filter((item: DownloadEntry) => item.id !== id); this.persist(); this.onChange();
  }
}
