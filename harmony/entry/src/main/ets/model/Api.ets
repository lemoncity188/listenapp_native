import { http } from '@kit.NetworkKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { asset } from '@kit.AssetStoreKit';
import { BusinessError } from '@kit.BasicServicesKit';

interface Envelope<T> { status?: number; data: T; errorCode?: number; subCode?: number; subMessage?: string; errorMessage?: string; }
export class EmptyBody {}
export class MobileBody { mobile: string = ''; }
export class AuthBody { mobile: string = ''; password: string = ''; verificationCode?: string; username?: string; roles?: string; avatar?: string; }
export class FeedbackBody { userId: number = 0; content: string = ''; }
export class RemoveBody { id: number = 0; }

export class Api {
  baseURL: string = 'http://47.97.107.100:8090/';
  token: string = '';
  private prefs?: preferences.Preferences;
  async init(context: common.UIAbilityContext): Promise<void> {
    this.prefs = await preferences.getPreferences(context, { name: 'redfox_listen_settings' });
    this.baseURL = await this.prefs.get('apiURL', this.baseURL) as string;
    try {
      const query: asset.AssetMap = new Map();
      query.set(asset.Tag.ALIAS, new util.TextEncoder().encodeInto('redfox_listen_token'));
      query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
      const values = await asset.query(query);
      if (values.length > 0) { this.token = new util.TextDecoder().decodeToString(values[0].get(asset.Tag.SECRET) as Uint8Array); }
    } catch (error) {
      if ((error as BusinessError).code !== asset.ErrorCode.NOT_FOUND) { throw new Error((error as BusinessError).message); }
    }
  }
  async saveToken(value: string): Promise<void> {
    const attributes: asset.AssetMap = new Map();
    attributes.set(asset.Tag.ALIAS, new util.TextEncoder().encodeInto('redfox_listen_token'));
    if (value) {
      attributes.set(asset.Tag.SECRET, new util.TextEncoder().encodeInto(value));
      attributes.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE);
      await asset.add(attributes);
    } else {
      try { await asset.remove(attributes); } catch (error) {
        if ((error as BusinessError).code !== asset.ErrorCode.NOT_FOUND) { throw new Error((error as BusinessError).message); }
      }
    }
    this.token = value;
  }
  async saveURL(value: string): Promise<void> {
    this.baseURL = value;
    await this.prefs?.put('apiURL', value); await this.prefs?.flush();
  }
  async post<T>(endpoint: string, body: Object = new EmptyBody()): Promise<T> {
    if (!/^https?:\/\//.test(this.baseURL)) { throw new Error('接口地址无效'); }
    const client = http.createHttp();
    try {
      const response = await client.request(this.baseURL.replace(/\/+$/, '') + '/' + endpoint.replace(/^\/+/, ''), {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json', 'token': this.token },
        extraData: JSON.stringify(body), connectTimeout: 20000, readTimeout: 20000,
        expectDataType: http.HttpDataType.STRING
      });
      if (response.responseCode === 401) { await this.saveToken(''); }
      if (response.responseCode < 200 || response.responseCode >= 300) { throw new Error('服务器请求失败：' + response.responseCode); }
      const result = JSON.parse(response.result as string) as Envelope<T>;
      if (result.errorCode === 1000 && result.subCode === 1) { await this.saveToken(''); throw new Error('登录已过期，请重新登录'); }
      if (result.status !== 0) { throw new Error(result.subMessage || result.errorMessage || '请求失败'); }
      return result.data;
    } finally { client.destroy(); }
  }
}
export async function encrypt(text: string): Promise<string> {
  const keyBytes = new util.TextEncoder().encodeInto('gww417038_x8888x');
  const bytes = new util.TextEncoder().encodeInto(text);
  const padded = new Uint8Array((Math.floor(bytes.length / 16) + 1) * 16); padded.set(bytes);
  const generator = cryptoFramework.createSymKeyGenerator('AES128');
  const key = await generator.convertKey({ data: keyBytes });
  const cipher = cryptoFramework.createCipher('AES128|CBC|NoPadding');
  const params: cryptoFramework.IvParamsSpec = { algName: 'IvParamsSpec', iv: { data: keyBytes } };
  await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, key, params);
  const result = await cipher.doFinal({ data: padded });
  return new util.Base64Helper().encodeToStringSync(result.data);
}
