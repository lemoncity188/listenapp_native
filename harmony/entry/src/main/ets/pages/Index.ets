import { common } from '@kit.AbilityKit';
import { Api, AuthBody, MobileBody, FeedbackBody, RemoveBody, encrypt } from '../model/Api';
import { User, Course, Category, Study, Segment, Records, CategoryBody, CategoryIDBody, IDBody, KindBody, CurriculumIDBody, ThumbBody, CollectionBody, SpecializeBody, SaveRecordsBody, VIPBody, courseTitle, boundedSeek, validSegment, toggleActive, activeAfterDelete } from '../model/Models';
import { Downloads, DownloadEntry } from '../model/Downloads';
import { privacyText } from '../model/Privacy';

@Entry
@Component
struct Index {
  private api: Api = new Api();
  private downloads: Downloads = new Downloads();
  private controller: VideoController = new VideoController();
  private seekUntil: number = 0;
  private countdownTimer: number = -1;
  @State repeatPassword: string = '';
  @State countdown: number = 0;
  @State privacyRegistration: boolean = false;
  private seriesReturn: string = 'catalog';
  private playerReturn: string = 'series';
  @State ready: boolean = false;
  @State loggedIn: boolean = false;
  @State busy: boolean = false;
  @State notice: string = '';
  @State page: string = 'home';
  @State authMode: number = 0;
  @State mobile: string = '';
  @State password: string = '';
  @State username: string = '';
  @State code: string = '';
  @State agreed: boolean = false;
  @State server: string = 'http://47.97.107.100:8090/';
  @State showingPrivacy: boolean = false;
  @State showingVIP: boolean = false;
  @State categories: Category[] = [];
  @State courses: Course[] = [];
  @State episodes: Course[] = [];
  @State seriesTitle: string = '';
  @State search: string = '';
  @State study: Study = {};
  @State user: User = { userId: 0, username: '', vip: 0 };
  @State feedback: string = '';
  @State editingFeedback: boolean = false;
  @State editingVIP: boolean = false;
  @State vipUser: string = '';
  @State detail: Course = { id: 0 };
  @State videoURL: string = '';
  @State playhead: number = 0;
  @State duration: number = 0;
  @State playing: boolean = false;
  @State speed: number = 1;
  @State abMode: boolean = false;
  @State segments: Segment[] = [];
  @State active: number = -1;
  @State pendingA: number = -1;
  @State recordsReady: boolean = false;
  @State downloaded: DownloadEntry[] = [];
  @State runningIDs: number[] = [];
  @State progressLabel: string = '';
  aboutToAppear(): void {
    this.execute(async () => {
      const context = getContext(this) as common.UIAbilityContext;
      await this.api.init(context); this.server = this.api.baseURL;
      this.downloads.onChange = () => {
        this.downloaded = this.downloads.entries.slice(); this.runningIDs = Array.from(this.downloads.progress.keys());
        this.progressLabel = this.runningIDs.map((id: number) => id + ': ' + this.downloads.progress.get(id) + '%').join(' · ');
      };
      this.downloads.onError = (message: string) => { this.notice = message; };
      this.downloads.init(context); this.downloads.onChange(); this.ready = true;
      if (this.api.token) { this.user = await this.api.post<User>('user/info'); this.categories = await this.api.post<Category[]>('dict/selectByKind', new KindBody()); }
    });
  }
  aboutToDisappear(): void { clearInterval(this.countdownTimer); if (this.videoURL) { this.controller.pause(); } }
  async execute(work: () => Promise<void>): Promise<void> {
    if (this.busy) { return; } this.busy = true; this.notice = '';
    try { await work(); } catch (error) { this.notice = (error as Error).message || '操作失败，请重试'; }
    finally { this.loggedIn = this.api.token.length > 0; if (!this.loggedIn && this.videoURL) { this.controller.pause(); this.videoURL = ''; } this.busy = false; }
  }
  async authenticate(): Promise<void> {
    if (!/^\d{11}$/.test(this.mobile) || this.password.length < 6) { throw new Error('请输入11位手机号和至少6位密码'); }
    if ((this.authMode === 1 && !this.agreed) || (this.authMode !== 0 && !this.code)) { throw new Error('请同意隐私政策并输入验证码'); }
    if (this.authMode !== 0 && this.password !== this.repeatPassword) { throw new Error('两次密码输入不一致'); }
    if (this.authMode === 1 && !this.username.trim()) { throw new Error('请输入昵称'); }
    await this.api.saveURL(this.server);
    const body = new AuthBody(); body.mobile = await encrypt(this.mobile); body.password = await encrypt(this.password);
    if (this.authMode !== 0) { body.verificationCode = this.code; }
    if (this.authMode === 1) { body.username = this.username; body.roles = 'editor'; body.avatar = 'https://lemoncity.oss-cn-shanghai.aliyuncs.com/avatar/avater01.png'; }
    if (this.authMode === 0) {
      const token = await this.api.post<string>('user/login', body); if (!token || typeof token !== 'string') { throw new Error('登录未返回有效凭证'); }
      await this.api.saveToken(token); this.password = ''; this.loggedIn = true; this.page = 'home';
      this.user = await this.api.post<User>('user/info'); this.categories = await this.api.post<Category[]>('dict/selectByKind', new KindBody());
    } else { await this.api.post<Object>(this.authMode === 1 ? 'user/register' : 'user/change/password', body); this.authMode = 0; this.notice = '操作成功，请登录'; }
  }
  async openCatalog(code: string): Promise<void> {
    const body = new CategoryBody(); body.categoryNo = code; body.searchText = code ? '' : this.search.trim();
    this.courses = await this.api.post<Course[]>('category/selectByCategoryNo', body); this.page = 'catalog';
  }
  async openSeries(course: Course): Promise<void> {
    if (this.page === 'catalog' && this.user.vip === 0 && course.id !== 3) { this.page = 'profile'; return; }
    const body = new CategoryIDBody(); body.categoryId = course.id;
    this.episodes = await this.api.post<Course[]>('curriculum/selectByCategoryId', body); this.seriesReturn = this.page; this.seriesTitle = courseTitle(course); this.page = 'series';
  }
  async openPlayer(id: number): Promise<void> {
    const previous = this.page; this.abMode = false; this.videoURL = ''; this.playhead = 0; this.duration = 0; this.playing = false; this.active = -1; this.pendingA = -1; this.recordsReady = false; this.segments = [];
    const local = this.downloads.localPath(id);
    if (local) {
      const cached = this.downloaded.find((entry: DownloadEntry) => entry.id === id);
      this.detail = { id: id, curriculumName: cached?.name ?? '离线视频', categoryId: cached?.categoryId ?? 0 }; this.videoURL = local;
    } else {
      const body = new IDBody(); body.id = id; this.detail = await this.api.post<Course>('curriculum/load', body);
      this.videoURL = this.detail.url || this.detail.videoUrl || ''; if (!/^https?:\/\//.test(this.videoURL)) { throw new Error('视频地址无效'); }
    }
    this.playerReturn = previous; this.page = 'player';
    const body = new CurriculumIDBody(); body.curriculumId = id;
    const records = await this.api.post<Records>('curriculumUserRecord/pageList', body);
    this.segments = (records?.recordPhase ?? []).filter(validSegment).sort((a: Segment, b: Segment) => a.APos - b.APos); this.recordsReady = true;
  }
  seek(value: number): void { this.playhead = boundedSeek(value, this.duration); this.seekUntil = Date.now() + 500; this.controller.setCurrentTime(this.playhead); }
  recordA(): void { if (!this.playing) { this.notice = '请先播放'; return; } this.pendingA = this.pendingA < 0 ? this.playhead : -1; }
  recordB(): void {
    if (!this.playing) { this.notice = '请先播放'; return; }
    if (this.pendingA < 0 || this.playhead <= this.pendingA) { this.notice = '先设置A点，B点必须晚于A点'; return; }
    const selected = this.active >= 0 ? this.segments[this.active] : undefined;
    this.segments = this.segments.concat([{ APos: this.pendingA, BPos: this.playhead }]).sort((a: Segment, b: Segment) => a.APos - b.APos);
    this.active = selected ? this.segments.findIndex((s: Segment) => s.APos === selected.APos && s.BPos === selected.BPos) : -1; this.pendingA = -1;
  }
  select(index: number): void { this.active = toggleActive(this.active, index, this.segments.length); if (this.active >= 0) { this.seek(this.segments[this.active].APos); this.controller.start(); } }
  remove(index: number): void { this.segments = this.segments.filter((s: Segment, i: number) => i !== index); this.active = activeAfterDelete(this.active, index); }
  async saveRecords(): Promise<void> {
    if (!this.recordsReady) { throw new Error('请先成功加载云端记录'); }
    const body = new SaveRecordsBody(); body.curriculumId = this.detail.id; body.curriculumName = courseTitle(this.detail); body.category = this.detail.categoryId ?? 0; body.recordPhase = this.segments;
    await this.api.post<Object>('curriculumUserRecord/insertOrUpdate', body); this.notice = 'AB记录已保存';
  }
  clear(): void { this.api.token = ''; this.loggedIn = false; this.user = { userId: 0, username: '', vip: 0 }; this.categories = []; this.courses = []; this.episodes = []; this.segments = []; this.study = {}; this.page = 'home'; }
  back(): void { if (this.page === 'player') { this.controller.pause(); this.videoURL = ''; this.page = this.playerReturn; } else { this.page = this.page === 'series' ? this.seriesReturn : this.page === 'downloads' ? 'study' : 'home'; } }
  @Builder
  authView() {
    Column({ space: 16 }) {
      Image('https://lemoncity.oss-cn-shanghai.aliyuncs.com/logo/firefox_word.png').width(66).height(66).margin({ bottom: 24 })
      TextInput({ placeholder: '请输入手机号', text: this.mobile }).height(48).borderRadius(6).backgroundColor('#F9F9F9').type(InputType.PhoneNumber).onChange((v: string) => { this.mobile = v; })
      if (this.authMode === 1) { TextInput({ placeholder: '请输入用户名', text: this.username }).height(48).borderRadius(6).onChange((v: string) => { this.username = v; }) }
      TextInput({ placeholder: '请输入密码', text: this.password }).height(48).borderRadius(6).backgroundColor('#F9F9F9').type(InputType.Password).onChange((v: string) => { this.password = v; })
      if (this.authMode !== 0) {
        TextInput({ placeholder: '确认密码', text: this.repeatPassword }).height(48).borderRadius(6).type(InputType.Password).onChange((v: string) => { this.repeatPassword = v; })
        Row({ space: 8 }) {
          TextInput({ placeholder: '验证码', text: this.code }).layoutWeight(1).onChange((v: string) => { this.code = v; })
          Button(this.countdown > 0 ? this.countdown + '秒后重试' : '发送验证码', { type: ButtonType.Normal }).height(40).fontSize(14).padding({ left: 14, right: 14 }).enabled(this.countdown === 0).backgroundColor('#EAF6F3').fontColor('#287F73').borderRadius(10).onClick(() => { this.execute(async () => {
            if (!/^\d{11}$/.test(this.mobile)) { throw new Error('请输入11位手机号'); }
            const body = new MobileBody(); body.mobile = await encrypt(this.mobile);
            await this.api.post<Object>('user/sendCode', body);
            this.countdown = 60;
            this.countdownTimer = setInterval(() => { this.countdown--; if (this.countdown <= 0) { clearInterval(this.countdownTimer); } }, 1000);
            this.notice = '验证码已发送';
          }); })
        }
      }
      Button(this.authMode === 0 ? '登陆' : this.authMode === 1 ? '注册' : '修改密码').width('100%').height(48).borderRadius(4).backgroundColor('#26A69A').margin({ top: 16 }).fontColor(Color.White).onClick(() => { this.execute(async () => { await this.authenticate(); }); })
      if (this.authMode === 0) {
        Text('立即注册').fontSize(14).fontColor('#666666').margin({ top: 14 }).onClick(() => { this.privacyRegistration = true; this.showingPrivacy = true; })
        Text('忘记密码').fontSize(14).fontColor('#666666').margin({ top: 14 }).onClick(() => { this.authMode = 2; })
      } else { Text('已有账号去登陆').fontSize(14).fontColor('#666666').onClick(() => { this.authMode = 0; }) }
    }.padding({ left: 40, right: 40, top: 40, bottom: 40 }).width('100%').constraintSize({ minHeight: '90%' }).justifyContent(FlexAlign.Center)
  }

  categoryImage(name: string): Resource {
    switch (name.toLowerCase()) {
      case 'news': return $r('app.media.icon_news');
      case 'documentary': return $r('app.media.icon_documentary');
      case 'talkshow': return $r('app.media.icon_talkshow');
      case 'action': return $r('app.media.icon_action');
      case 'animation': return $r('app.media.icon_animation');
      case 'detective': return $r('app.media.icon_detective');
      case 'live': return $r('app.media.icon_live');
      case 'moive': return $r('app.media.icon_moive');
      case 'speech': return $r('app.media.icon_speech');
      case 'blog': return $r('app.media.icon_blog');
      default: return $r('app.media.icon_home');
    }
  }
  @Builder
  homeView() {
    Column({ space: 16 }) {
      Row({ space: 10 }) {
        TextInput({ placeholder: '搜索', text: this.search }).layoutWeight(1).height(44).borderRadius(16).backgroundColor('#F5F6F7').onChange((v: string) => { this.search = v; })
        Text('搜索').fontSize(16).fontColor('#26A69A').onClick(() => { if (this.search.trim()) { this.execute(async () => { await this.openCatalog(''); }); } })
      }.padding({ left: 16, right: 16, top: 8 })
      Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Start }) {
        ForEach(this.categories, (category: Category) => {
          Column() {
            Column({ space: 6 }) {
              Image(this.categoryImage(category.img || '')).width(56).height(56).padding(13).backgroundColor('#E9F6F4').borderRadius(16)
              Text(category.desc).fontSize(13).fontColor('#333333')
            }.width('100%').padding(8).onClick(() => { this.search = ''; this.execute(async () => { await this.openCatalog(category.code); }); })
          }
          .width('33.33%')
        })
      }.width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  @Builder
  catalogView() {
    Column({ space: 16 }) {
      Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Start }) {
      ForEach(this.courses, (course: Course, index: number) => {
        Column() {
        Column({ space: 6 }) {
          if (course.poster) { Image(course.poster).height(180).width('100%').objectFit(ImageFit.Contain).onClick(() => { this.execute(async () => { await this.openSeries(course); }); }) }
          Text(courseTitle(course) + (this.user.vip === 0 && course.id !== 3 ? ' 🔒' : '')).fontSize(14).fontColor('#333333').maxLines(2).onClick(() => { this.execute(async () => { await this.openSeries(course); }); })
          Row({ space: 16 }) {
            Text(course.thumbUp === 0 ? '♥ 已赞' : '♡ 赞').fontSize(13).fontColor('#26A69A').onClick(() => { this.execute(async () => {
              const body = new ThumbBody(); body.curriculumId = course.id; body.thumbUp = (course.thumbUp ?? 1) === 0 ? 1 : 0;
              await this.api.post<Object>('curriculumGoodUserRelated/thumbUp', body); const next = this.courses.slice(); next[index].thumbUp = body.thumbUp; this.courses = next;
            }); })
            Text(course.collection === 0 ? '★' : '☆').fontSize(20).fontColor('#26A69A').onClick(() => { this.execute(async () => {
              const body = new CollectionBody(); body.curriculumId = course.id; body.collection = (course.collection ?? 1) === 0 ? 1 : 0;
              await this.api.post<Object>('curriculumScheduleUserRelated/collection', body); const next = this.courses.slice(); next[index].collection = body.collection; this.courses = next;
            }); })
          }
        }.width('100%').padding(6).backgroundColor(Color.White).borderRadius(12)
        }.width('50%').padding(4)
      })
      }.width('100%')
    }.padding(16).width('100%')
  }
  @Builder
  seriesView() {
    Column({ space: 0 }) {
      ForEach(this.episodes, (episode: Course, index: number) => {
        Row({ space: 12 }) {
          if (episode.thumbnail) { Image(episode.thumbnail).width(56).height(56).objectFit(ImageFit.Contain) }
          Column({ space: 6 }) {
          Text(courseTitle(episode) + (this.user.vip === 0 && index >= 10 ? ' 🔒' : '')).fontSize(16).fontColor('#26A69A').width('100%').onClick(() => {
            if (this.user.vip === 0 && index >= 10) { this.page = 'profile'; } else { this.execute(async () => { await this.openPlayer(episode.id); }); }
          })
          Text(episode.curriculumDesc || episode.desc || '').fontSize(13).fontColor('#777777').maxLines(2)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          if (this.runningIDs.includes(episode.id)) { Button('下载中，点击取消').backgroundColor('#E9F6F4').fontColor('#238E83').borderRadius(10).onClick(() => { this.execute(async () => { await this.downloads.cancel(episode.id); }); }) }
          else { Button(this.downloaded.some((entry: DownloadEntry) => entry.id === episode.id) ? '已下载' : '↓', { type: ButtonType.Normal }).backgroundColor(Color.White).fontColor('#999999').width(48).backgroundColor('#E9F6F4').fontColor('#238E83').borderRadius(10).onClick(() => { this.execute(async () => { if (!this.downloaded.some((entry: DownloadEntry) => entry.id === episode.id)) { await this.downloads.start(episode); } }); }) }
        }.width('100%').padding(16).backgroundColor(Color.White)
        Divider().color('#EEEEEE')
      })
    }.padding(16).width('100%').alignItems(HorizontalAlign.Start)
  }
  @Builder
  playerView() {
    Column({ space: 0 }) {
      Text('‹ 返回').fontSize(14).fontColor('#26A69A').width('100%').padding(8).onClick(() => { this.back(); })
      if (this.videoURL) {
        Video({ src: this.videoURL, controller: this.controller, currentProgressRate: this.speed }).width('100%').height(230).autoPlay(false).controls(false)
          .onPrepared((event) => { if (event) { this.duration = event.duration; } })
          .onStart(() => { this.playing = true; }).onPause(() => { this.playing = false; })
          .onFinish(() => { if (this.active >= 0) { this.seek(this.segments[this.active].APos); this.controller.start(); } else { this.playing = false; } })
          .onError(() => { this.playing = false; this.notice = '视频播放失败，请检查网络后重试'; })
          .onUpdate((event) => { if (event && Date.now() >= this.seekUntil) { this.playhead = event.time; if (this.playing && this.active >= 0 && this.playhead >= this.segments[this.active].BPos) { this.seek(this.segments[this.active].APos); } } })
      }

      Row({ space: 4 }) {
        Text(this.clockTime(this.playhead)).fontSize(12).fontColor('#888888').width(40)
        Slider({ value: this.playhead, min: 0, max: Math.max(1, this.duration), step: 0.1 }).layoutWeight(1).selectedColor('#26A69A').onChange((value: number, mode: SliderChangeMode) => { if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) { this.seek(value); } })
        Text(this.clockTime(this.duration)).fontSize(12).fontColor('#888888').width(40)
      }.padding(8)
      Scroll() {
      Flex({ wrap: FlexWrap.Wrap }) {
        if (!this.segments.length) { Text('暂无记录').fontSize(12).fontColor('#888888').padding(8) }
        ForEach(this.segments, (segment: Segment, index: number) => {
          Column({ space: 2 }) {
            Image($r('app.media.control_heart')).width(24).height(24).fillColor(this.active === index ? '#26A69A' : '#C7C7C7')
            Text((index + 1).toString()).fontSize(10).fontColor('#999999')
          }.padding(4).onClick(() => { this.select(index); }).gesture(LongPressGesture().onAction(() => {
            AlertDialog.show({ title: '确认删除', message: '确定要删除这条记录么？', primaryButton: { value: '取消', action: () => {} }, secondaryButton: { value: '确定', action: () => { this.remove(index); } } });
          }))
        })
      }.width('100%').padding(8)

      }.layoutWeight(1).width('100%').align(Alignment.TopStart)
      Row() {
        if (!this.abMode) {
          Button({ type: ButtonType.Normal }) { Image($r('app.media.control_back5')).width(24).height(24) }.backgroundColor(Color.White).fontColor('#888888').fontSize(20).height(44).layoutWeight(1).onClick(() => { this.seek(this.playhead - 5); })
          Button({ type: ButtonType.Normal }) { Image($r('app.media.control_forward5')).width(24).height(24) }.backgroundColor(Color.White).fontColor('#888888').fontSize(20).height(44).layoutWeight(1).onClick(() => { this.seek(this.playhead + 5); })
          Button({ type: ButtonType.Normal }) { Image(this.playing ? $r('app.media.control_pause') : $r('app.media.control_play')).width(24).height(24) }.backgroundColor(Color.White).fontColor('#888888').fontSize(20).height(44).layoutWeight(1).onClick(() => { if (this.playing) { this.controller.pause(); } else { this.controller.start(); } })
          Button({ type: ButtonType.Normal }) { Image($r('app.media.control_previous')).width(24).height(24) }.backgroundColor(Color.White).fontColor('#888888').fontSize(20).height(44).layoutWeight(1).onClick(() => { if (this.active > 0) { this.select(this.active - 1); } })
          Button({ type: ButtonType.Normal }) { Image($r('app.media.control_next')).width(24).height(24) }.backgroundColor(Color.White).fontColor('#888888').fontSize(20).height(44).layoutWeight(1).onClick(() => { if (this.active >= 0 && this.active + 1 < this.segments.length) { this.select(this.active + 1); } })
      Button({ type: ButtonType.Normal }) { Image($r('app.media.control_fire')).width(24).height(24).fillColor(this.detail.specialize === 0 ? '#26A69A' : '#888888') }.backgroundColor(Color.White).fontColor(this.detail.specialize === 0 ? '#26A69A' : '#888888').layoutWeight(1).onClick(() => { this.execute(async () => {
        const body = new SpecializeBody(); body.curriculumId = this.detail.id; body.specialize = (this.detail.specialize ?? 1) === 0 ? 1 : 0; await this.api.post<Object>('curriculumUserDaydayuse/specialize', body); this.detail.specialize = body.specialize; this.notice = '操作成功';
      }); })

          if (this.user.vip === 8) { Button({ type: ButtonType.Normal }) { Image($r('app.media.control_swap')).width(24).height(24) }.backgroundColor(Color.White).fontColor('#888888').fontSize(20).height(44).layoutWeight(1).onClick(() => { this.abMode = true; }) }
        } else {
          Button('A', { type: ButtonType.Normal }).backgroundColor(Color.White).fontColor('#888888').fontSize(20).height(44).layoutWeight(1).onClick(() => { this.recordA(); })
          Button('B', { type: ButtonType.Normal }).backgroundColor(Color.White).fontColor('#888888').fontSize(20).height(44).layoutWeight(1).onClick(() => { this.recordB(); })
          Button({ type: ButtonType.Normal }) { Image($r('app.media.control_back5')).width(24).height(24) }.backgroundColor(Color.White).fontColor('#888888').fontSize(20).height(44).layoutWeight(1).onClick(() => { this.seek(this.playhead - 5); })
          Button({ type: ButtonType.Normal }) { Image($r('app.media.control_forward5')).width(24).height(24) }.backgroundColor(Color.White).fontColor('#888888').fontSize(20).height(44).layoutWeight(1).onClick(() => { this.seek(this.playhead + 5); })
          Button({ type: ButtonType.Normal }) { Image($r('app.media.control_save')).width(24).height(24) }.backgroundColor(Color.White).fontColor('#888888').fontSize(20).height(44).layoutWeight(1).onClick(() => { this.execute(async () => { await this.saveRecords(); }); })
      Button({ type: ButtonType.Normal }) { Image($r('app.media.control_trash')).width(24).height(24) }.backgroundColor(Color.White).fontColor('#888888').layoutWeight(1).onClick(() => { AlertDialog.show({ title: '清空记录', message: '确认删除云端AB记录？', primaryButton: { value: '取消', action: () => {} }, secondaryButton: { value: '确认删除', action: () => { this.execute(async () => {
        const body = new CurriculumIDBody(); body.curriculumId = this.detail.id; await this.api.post<Object>('curriculumUserRecord/deleteRecord', body); this.segments = []; this.active = -1; this.pendingA = -1; this.recordsReady = true;
      }); } } }); })

          Button({ type: ButtonType.Normal }) { Image($r('app.media.control_swap')).width(24).height(24) }.backgroundColor(Color.White).fontColor('#888888').fontSize(20).height(44).layoutWeight(1).onClick(() => { this.abMode = false; })
        }
      }.width('100%').padding(8)
    }.width('100%').height('100%')
  }
  clockTime(value: number): string { return Math.floor(value / 60) + ':' + Math.floor(value % 60).toString().padStart(2, '0'); }
  @Builder
  menuRow(label: string, action: () => void) {
    Row({ space: 12 }) {
      Text(label).fontSize(15).fontColor('#444444').layoutWeight(1)
      Text('›').fontSize(20).fontColor('#999999')
    }.width('100%').constraintSize({ minHeight: 52 }).padding({ left: 16, right: 16 }).onClick(action)
    Divider().color('#EEEEEE')
  }
  @Builder
  studyView() {
    Column({ space: 8 }) {
      Column({ space: 4 }) {
        Text('今天').fontSize(14).fontColor(Color.White)
        Text(new Date().toLocaleDateString('zh-CN')).fontSize(18).fontColor(Color.White).fontWeight(FontWeight.Bold)
      }.width('100%').alignItems(HorizontalAlign.Start).padding(20).backgroundColor('#258F85').borderRadius(12)
      if (this.study.curriculumList?.length) {
        Text('专注').fontWeight(FontWeight.Bold).fontSize(17)
        ForEach(this.study.curriculumList, (course: Course) => {
          this.menuRow(courseTitle(course), () => { this.execute(async () => { await this.openPlayer(course.id); }); })
        })
      }
      if (this.study.categoryList?.length) {
        Text('收藏').fontWeight(FontWeight.Bold).fontSize(17)
        ForEach(this.study.categoryList, (course: Course) => {
          this.menuRow(courseTitle(course), () => { this.execute(async () => { await this.openSeries(course); }); })
        })
      }
      this.menuRow('离线视频', () => { this.page = 'downloads'; })
    }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
  }
  @Builder
  downloadsView() {
    Column({ space: 16 }) {
      if (this.progressLabel) { Text(this.progressLabel) }
      ForEach(this.runningIDs, (id: number) => { Button('视频 ' + id + ' 下载中，点击取消').backgroundColor('#E9F6F4').fontColor('#238E83').borderRadius(10).onClick(() => { this.execute(async () => { await this.downloads.cancel(id); }); }) })
      ForEach(this.downloaded, (entry: DownloadEntry) => {
        Row() { Button(entry.name).layoutWeight(1).backgroundColor('#E9F6F4').fontColor('#238E83').borderRadius(10).onClick(() => { this.execute(async () => { await this.openPlayer(entry.id); }); }); Button('删除本地视频').backgroundColor('#E9F6F4').fontColor('#238E83').borderRadius(10).onClick(() => { this.execute(async () => { this.downloads.remove(entry.id); }); }) }
      })
      if (!this.downloaded.length && !this.runningIDs.length) { Text('暂无下载，请在剧集列表中下载视频') }
    }.padding(16).width('100%').alignItems(HorizontalAlign.Start)
  }
  @Builder
  profileView() {
    Column({ space: 0 }) {
      Row({ space: 16 }) {
        Image(this.user.avatar || 'https://lemoncity.oss-cn-shanghai.aliyuncs.com/avatar/avater01.png').width(60).height(60).borderRadius(30)
        Column({ space: 6 }) {
          Text(this.user.name || this.user.username || '我的账号').fontSize(16).fontWeight(FontWeight.Bold)
          Text(this.user.vip === 0 ? '普通用户' : 'VIP').fontSize(14).fontColor(this.user.vip === 0 ? '#888888' : '#C4A25C')
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        if (this.user.vip !== 0) { Text('VIP').fontWeight(FontWeight.Bold).fontColor('#C4A25C') }
      }.padding(16).width('100%')
      this.menuRow('建议', () => { this.editingFeedback = !this.editingFeedback; })
      Divider().color('#EEEEEE')
      if (this.editingFeedback) {
      TextArea({ placeholder: '建议与反馈', text: this.feedback }).onChange((v: string) => { this.feedback = v; })
      Button('提交反馈').enabled(this.feedback.trim().length > 0).backgroundColor('#E9F6F4').fontColor('#238E83').borderRadius(10).onClick(() => { this.execute(async () => { const body = new FeedbackBody(); body.userId = this.user.userId; body.content = this.feedback; await this.api.post<Object>('suggest/insert', body); this.feedback = ''; this.editingFeedback = false; this.notice = '感谢反馈'; }); })
      }
      if (this.user.vip === 8) {
        this.menuRow('设置 VIP', () => { this.editingVIP = !this.editingVIP; })
        if (this.editingVIP) {
        TextInput({ placeholder: '会员用户名', text: this.vipUser }).onChange((v: string) => { this.vipUser = v; })
        Button('设置会员').enabled(this.vipUser.trim().length > 0).backgroundColor('#E9F6F4').fontColor('#238E83').borderRadius(10).onClick(() => { this.execute(async () => { const body = new VIPBody(); body.username = this.vipUser; await this.api.post<Object>('user/setting/vip', body); this.notice = '操作成功'; }); })
      }
        }
      this.menuRow('会员说明', () => { this.showingVIP = true; })
      this.menuRow('隐私政策', () => { this.privacyRegistration = false; this.showingPrivacy = true; })
      this.menuRow('登出', () => { this.execute(async () => { await this.api.post<Object>('user/logout'); await this.api.saveToken(''); this.clear(); }); })
      this.menuRow('注销用户', () => { AlertDialog.show({ title: '注销账号', message: '注销将删除账号，是否继续？', primaryButton: { value: '取消', action: () => {} }, secondaryButton: { value: '确认注销', action: () => { this.execute(async () => { const body = new RemoveBody(); body.id = this.user.userId; await this.api.post<Object>('user/removal', body); await this.api.saveToken(''); this.clear(); }); } } }); })
    }.padding(16).width('100%').alignItems(HorizontalAlign.Start)
  }
  build() {
    Column() {
      if (this.showingPrivacy) {
        Button('‹ 返回', { type: ButtonType.Normal }).backgroundColor(Color.White).fontColor('#26A69A').height(44).onClick(() => { this.showingPrivacy = false; }); Scroll() { Text(privacyText).padding(24) }.layoutWeight(1)
        if (this.privacyRegistration) { Button('同意并注册').backgroundColor('#E9F6F4').fontColor('#238E83').borderRadius(10).onClick(() => { this.agreed = true; this.authMode = 1; this.showingPrivacy = false; this.privacyRegistration = false; }) }
      } else if (this.showingVIP) {
        Button('‹ 返回', { type: ButtonType.Normal }).backgroundColor(Color.White).fontColor('#26A69A').height(44).onClick(() => { this.showingVIP = false; })
        Scroll() { Column({ space: 24 }) { Text('支付宝二维码').fontSize(24); Image('https://lemoncity.oss-cn-shanghai.aliyuncs.com/zhifubao/zhifubao.png').width(250).height(250).objectFit(ImageFit.Contain); Text('请在支付备注里面填写用户名，一个工作日左右开通'); Text('听力年度VIP ¥88\n听力与单词年度双VIP ¥158') }.padding(24) }.layoutWeight(1)
      } else {
        if (this.notice) { Text(this.notice).fontColor('#A33E32').padding(12).width('100%') }
        if (this.busy) { LoadingProgress().width(32).height(32) }
        if (this.loggedIn && ['catalog', 'series', 'downloads'].includes(this.page)) {
          Row({ space: 8 }) {
            Text('‹').fontSize(30).width(44).height(44).textAlign(TextAlign.Center)
              .accessibilityText('返回').onClick(() => { this.back(); })
            Text(this.page === 'series' ? this.seriesTitle : this.page === 'catalog' ? '课程' : '离线视频')
              .fontSize(18).fontWeight(FontWeight.Medium).maxLines(2).layoutWeight(1)
          }.width('100%').padding({ right: 16 }).enabled(!this.busy)
          Divider().color('#EEEEEE')
        }
        if (this.loggedIn && this.page === 'player') {
          Column() { this.playerView() }.layoutWeight(1).width('100%')
        } else {
        Scroll() {
          Column() {
            if (!this.loggedIn) { this.authView() }
            else if (this.page === 'home') { this.homeView() }
            else if (this.page === 'catalog') { this.catalogView() }
            else if (this.page === 'series') { this.seriesView() }
            else if (this.page === 'player') { this.playerView() }
            else if (this.page === 'study') { this.studyView() }
            else if (this.page === 'downloads') { this.downloadsView() }
            else { this.profileView() }
          }.width('100%').enabled(this.ready && !this.busy)
        }.layoutWeight(1).width('100%').align(Alignment.TopStart)
        }
        if (this.loggedIn && ['home', 'study', 'profile'].includes(this.page)) {
          Row({ space: 4 }) {
            Column({ space: 2 }) {
              Image($r('app.media.icon_home')).width(23).height(23).fillColor(this.page === 'home' ? '#26A69A' : '#777777')
              Text('类目').fontSize(12).fontColor(this.page === 'home' ? '#238E83' : '#777777')
            }.height(48).justifyContent(FlexAlign.Center).layoutWeight(1).onClick(() => { this.page = 'home'; })
            Column({ space: 2 }) {
              Image($r('app.media.icon_blog')).width(23).height(23).fillColor(this.page === 'study' ? '#26A69A' : '#777777')
              Text('学习').fontSize(12).fontColor(this.page === 'study' ? '#238E83' : '#777777')
            }.height(48).justifyContent(FlexAlign.Center).layoutWeight(1).onClick(() => { this.page = 'study'; this.execute(async () => { this.study = await this.api.post<Study>('study/list'); }); })

            Column({ space: 2 }) {
              Image($r('app.media.icon_profile')).width(23).height(23).fillColor(this.page === 'profile' ? '#26A69A' : '#777777')
              Text('我的').fontSize(12).fontColor(this.page === 'profile' ? '#238E83' : '#777777')
            }.height(48).justifyContent(FlexAlign.Center).layoutWeight(1).onClick(() => { this.page = 'profile'; this.execute(async () => { this.user = await this.api.post<User>('user/info'); }); })
          }.padding({ left: 8, right: 8, top: 4, bottom: 4 }).width('100%').backgroundColor(Color.White).enabled(!this.busy)
        }
      }
    }.width('100%').height('100%').backgroundColor('#FFFFFF')
  }
}
