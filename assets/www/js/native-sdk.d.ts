declare global {
  interface Window {
    NativeSDK: NativeSDKInterface;
    Native: {
      call(options: NativeCallOptions): Promise<any>;
      batch(requests: BatchRequest[], options?: BatchOptions): Promise<any[]>;
      on(event: string, callback: (data: any) => void): () => void;
      off(event: string, callback: (data: any) => void): void;
      info(): NativeBridgeInfo;
    };
  }
}

export interface NativeBridgeInfo {
  initialized: boolean;
  pendingRequests: number;
  totalRequests: number;
  version: string | null;
}

export interface NativeCallOptions {
  plugin: string;
  method: string;
  args?: Record<string, any>;
  timeout?: number;
  version?: string;
}

export interface BatchRequest {
  plugin: string;
  method: string;
  args?: Record<string, any>;
}

export interface BatchOptions {
  parallel?: boolean;
  stopOnError?: boolean;
  timeout?: number;
}

// ── Permission Types ──
export interface PermissionResult {
  permission: string;
  status: 'granted' | 'denied' | 'permanentlyDenied' | 'notDetermined';
  granted: boolean;
  permanentlyDenied: boolean;
}

// ── Storage Types ──
export interface StorageKeysResult { keys: string[]; }
export interface StorageHasResult { exists: boolean; }

// ── FileSystem Types ──
export interface FileSystemDirectories {
  documents: string;
  cache: string;
  support: string;
  temporary: string;
}

export interface FileInfo {
  name: string;
  path: string;
  type: 'file' | 'directory';
  size: number;
  modified: string;
}

// ── HTTP Types ──
export interface HttpResponse<T = any> {
  ok: boolean;
  statusCode: number;
  headers: Record<string, string>;
  data: T;
  url: string;
}

export interface DownloadResult {
  saved: boolean;
  path?: string;
  fileName?: string;
  size?: number;
  mimeType?: string;
}

// ── Device Info Types ──
export interface DeviceInfo {
  platform: string;
  brand?: string;
  model?: string;
  manufacturer?: string;
  isPhysicalDevice?: boolean;
  version?: { sdkInt?: number; release?: string };
}

export interface AppInfo {
  appName: string;
  packageName: string;
  version: string;
  buildNumber: string;
}

// ── Geolocation Types ──
export interface Position {
  latitude: number;
  longitude: number;
  altitude: number;
  accuracy: number;
  heading: number;
  speed: number;
  timestamp: string;
}

// ── Camera Types ──
export interface PhotoResult {
  path: string;
  name: string;
  size: number;
  mimeType: string;
}


// ── AI types ──
export interface AiModelFile { name: string; path: string; size: number }
export interface AiModel {
  id: string;
  kind: string;
  name: string;
  dir: string;
  files: AiModelFile[];
  directories: string[];
  sizeBytes: number;
  createdAt: string;
}
export interface LlmLoadOptions {
  /** A model of the modelManager (kind 'llm'): its .gguf and mmproj are found by name. */
  modelId?: string;
  /** Or a file inside the models folder. */
  path?: string;
  mmproj?: string;
  contextSize?: number;
  device?: 'auto' | 'cpu' | 'gpu';
  gpuLayers?: number;
  threads?: number;
  threadsBatch?: number;
  batchSize?: number;
  microBatchSize?: number;
  flashAttention?: 'auto' | 'on' | 'off';
  useMmap?: boolean;
  useMlock?: boolean;
  kvCacheType?: 'f16' | 'q8_0' | 'q4_0';
  chatTemplate?: string;
  ropeFrequencyBase?: number;
  ropeFrequencyScale?: number;
  systemPrompt?: string;
  maxContextTokens?: number;
}
export interface LlmChatOptions {
  images?: string[];
  systemPrompt?: string;
  requestId?: string;
  params?: {
    maxTokens?: number;
    temperature?: number;
    topK?: number;
    topP?: number;
    minP?: number;
    repeatPenalty?: number;
    presencePenalty?: number;
    seed?: number;
    stop?: string[];
    enableThinking?: boolean;
    thinkingBudget?: number;
    streamBatchTokens?: number;
  };
}

// ── w2ray tunnel types ──
export interface W2rayShareConfig {
  enabled: boolean;
  /** Address to listen on. Default '0.0.0.0'. */
  bind?: string;
  /** Default 1080. */
  port?: number;
  authEnabled?: boolean;
  username?: string;
  password?: string;
  maxConnections?: number;
  /** Allow destinations on private networks. Loopback, link-local and multicast are always refused. */
  allowPrivate?: boolean;
}
export interface W2rayConfig {
  /** 'wss://host:4431/api/stream', instead of serverHost / serverPort / useTls / wsPath. */
  url?: string;
  serverHost?: string;
  serverPort?: number;
  useTls?: boolean;
  wsPath?: string;
  password: string;
  sni?: string;
  hostHeader?: string;
  allowInsecure?: boolean;
  connectTimeoutMs?: number;
  handshakeTimeoutMs?: number;
  pingIntervalSec?: number;
  idleTimeoutMs?: number;
  bufferSize?: number;
  warmPool?: number;
  maxConnections?: number;
  preferIpv6?: boolean;
  /** 'vpn' (default) or 'proxy' (sharing only, needs share.enabled). */
  mode?: 'vpn' | 'proxy';
  label?: string;
  tunnelMtu?: number;
  enableIpv4?: boolean;
  enableIpv6?: boolean;
  blockIpv6?: boolean;
  globalMode?: boolean;
  bypassLan?: boolean;
  remoteDns?: boolean;
  mapDnsAddress?: string;
  mapDnsPort?: number;
  mapDnsNetwork?: string;
  mapDnsNetmask?: string;
  mapDnsCacheSize?: number;
  dnsIpv4?: string;
  dnsIpv6?: string;
  udpDns?: boolean;
  icmpReply?: boolean;
  tcpBufferSize?: number;
  taskStackSize?: number;
  maxSessionCount?: number;
  logLevel?: 'debug' | 'info' | 'warn' | 'error';
  splitMode?: 'off' | 'exclude' | 'include';
  apps?: string[];
  excludeGoogleServices?: boolean;
  killSwitch?: boolean;
  autoReconnect?: boolean;
  notification?: { connecting?: string; connected?: string; reconnecting?: string; disconnect?: string; download?: string; upload?: string };
  share?: W2rayShareConfig;
}
export type W2rayState = 'idle' | 'connecting' | 'connected' | 'reconnecting' | 'disconnecting' | 'error';
export interface W2rayShareStatus {
  enabled: boolean;
  bind?: string;
  port?: number;
  auth?: boolean;
  username?: string;
  clients?: string[];
  connections?: number;
  totalConnections?: number;
  /** Bytes sent to the shared clients. */
  rx?: number;
  /** Bytes received from the shared clients. */
  tx?: number;
}
export interface W2rayStatus {
  state: W2rayState;
  message: string | null;
  mode: string;
  label: string;
  server: string;
  connectedAt: number;
  rx: number;
  tx: number;
  rxRate: number;
  txRate: number;
  connections: number;
  share: W2rayShareStatus;
  running: boolean;
}

// ── NativeSDK Interface ──
export interface NativeSDKInterface {
  waitForReady(timeoutMs?: number): Promise<NativeBridgeInfo>;
  info(): NativeBridgeInfo;
  call(plugin: string, method: string, args?: any, extra?: any): Promise<any>;
  batch(requests: BatchRequest[], options?: BatchOptions): Promise<any[]>;
  on<T = any>(event: string, callback: (data: T) => void): () => void;
  off(event: string, callback: (data: any) => void): void;

  permission: {
    check(permission: string): Promise<PermissionResult>;
    request(permission: string): Promise<PermissionResult>;
    checkMany(permissions: string[]): Promise<{ results: Record<string, PermissionResult> }>;
    requestMany(permissions: string[]): Promise<{ results: Record<string, PermissionResult> }>;
    openSettings(): Promise<{ opened: boolean }>;
    getKnownPermissions(): Promise<{ permissions: string[] }>;
  };

  appLifecycle: {
    getState(): Promise<{ state: string }>;
    enableEvents(): Promise<{ enabled: boolean }>;
    disableEvents(): Promise<{ enabled: boolean }>;
    getInfo(): Promise<any>;
  };

  deviceInfo: {
    getDeviceInfo(): Promise<DeviceInfo>;
    getAppInfo(): Promise<AppInfo>;
    getAll(): Promise<{ device: DeviceInfo; app: AppInfo }>;
  };

  connectivity: {
    getStatus(): Promise<{ online: boolean; primary: string; types: string[] }>;
    isOnline(): Promise<{ online: boolean }>;
    startWatch(): Promise<any>;
    stopWatch(): Promise<any>;
  };

  storage: {
    get(key: string): Promise<any>;
    set(key: string, value: any): Promise<boolean>;
    remove(key: string): Promise<boolean>;
    clear(): Promise<number>;
    keys(): Promise<StorageKeysResult>;
    has(key: string): Promise<StorageHasResult>;
  };

  fileSystem: {
    getDirectories(): Promise<FileSystemDirectories>;
    readFile(path: string, baseDir?: string, encoding?: string): Promise<any>;
    writeFile(path: string, content: string, options?: any): Promise<any>;
    deleteFile(path: string, baseDir?: string): Promise<any>;
    fileExists(path: string, baseDir?: string): Promise<{ exists: boolean }>;
    listFiles(path?: string, options?: any): Promise<{ items: FileInfo[] }>;
    browse(path?: string, options?: { extensions?: string[] }): Promise<{ path: string; parent: string | null; items: FileInfo[] }>;
    createDirectory(path: string, options?: any): Promise<any>;
    deleteDirectory(path: string, options?: any): Promise<any>;
    stat(path: string, options?: any): Promise<any>;
  };

  http: {
    get<T = any>(url: string, options?: any): Promise<HttpResponse<T>>;
    post<T = any>(url: string, body?: any, options?: any): Promise<HttpResponse<T>>;
    put<T = any>(url: string, body?: any, options?: any): Promise<HttpResponse<T>>;
    patch<T = any>(url: string, body?: any, options?: any): Promise<HttpResponse<T>>;
    delete<T = any>(url: string, options?: any): Promise<HttpResponse<T>>;
    request<T = any>(options: any): Promise<HttpResponse<T>>;
    download(options: any): Promise<DownloadResult>;
  };

  intent: {
    openUrl(url: string, mode?: string): Promise<{ opened: boolean }>;
    canOpenUrl(url: string): Promise<{ canOpen: boolean }>;
    getInitialLink(): Promise<{ url: string | null }>;
    getLatestLink(): Promise<{ url: string | null }>;
    startListening(): Promise<any>;
    stopListening(): Promise<any>;
  };

  clipboard: {
    readText(): Promise<{ text: string | null }>;
    writeText(text: string): Promise<{ written: boolean }>;
    hasText(): Promise<{ hasText: boolean }>;
    clear(): Promise<{ cleared: boolean }>;
  };

  share: {
    shareText(text: string, subject?: string): Promise<any>;
    shareFiles(paths: string[], text?: string, subject?: string): Promise<any>;
  };

  camera: {
    takePhoto(options?: { quality?: number; maxWidth?: number; maxHeight?: number }): Promise<PhotoResult>;
    pickFromGallery(options?: { multiple?: boolean }): Promise<any>;
    getInfo(): Promise<any>;
  };

  geolocation: {
    getCurrentPosition(options?: { accuracy?: string }): Promise<Position>;
    watchPosition(options?: any): Promise<any>;
    clearWatch(): Promise<any>;
    checkPermission(): Promise<{ permission: string }>;
    requestPermission(): Promise<{ permission: string }>;
    isLocationEnabled(): Promise<boolean>;
  };

  backButton: {
    enableIntercept(): Promise<any>;
    disableIntercept(): Promise<any>;
    getState(): Promise<{ interceptEnabled: boolean; exitOnBack: boolean }>;
    exitApp(): Promise<any>;
    setExitOnBack(enabled: boolean): Promise<any>;
    minimizeApp(): Promise<any>;
  };

  encryption: {
    aesEncrypt(data: string, key: string, iv?: string): Promise<{ encrypted: string; iv: string }>;
    aesDecrypt(data: string, key: string, iv: string): Promise<{ decrypted: string }>;
    generateAesKey(bits?: 128 | 256): Promise<{ key: string; iv: string }>;
    hashSha256(data: string): Promise<{ hash: string; base64: string }>;
    hashSha512(data: string): Promise<{ hash: string; base64: string }>;
    hashMd5(data: string): Promise<{ hash: string; base64: string }>;
    hmacSha256(data: string, key: string): Promise<{ hmac: string; base64: string }>;
    generateRandomBytes(length?: number): Promise<{ hex: string; base64: string }>;
    base64Encode(data: string): Promise<{ encoded: string }>;
    base64Decode(data: string): Promise<{ decoded: string }>;
  };

  dialog: {
    alert(options: { message: string; title?: string; buttonTitle?: string } | string): Promise<{ dismissed: boolean }>;
    confirm(options: { message: string; title?: string; okButtonTitle?: string; cancelButtonTitle?: string }): Promise<{ confirmed: boolean }>;
    prompt(options: { message?: string; title?: string; placeholder?: string; defaultValue?: string; inputType?: string }): Promise<{ cancelled: boolean; value: string | null }>;
  };

  toast: {
    show(text: string, options?: { duration?: 'short' | 'long'; backgroundColor?: string; textColor?: string }): Promise<any>;
  };

  database: {
    open(name: string, options?: { version?: number; onCreate?: string[] }): Promise<any>;
    close(name: string): Promise<any>;
    query(name: string, table: string, options?: any): Promise<{ rows: any[]; count: number }>;
    insert(name: string, table: string, values: Record<string, any>): Promise<{ id: number }>;
    update(name: string, table: string, values: Record<string, any>, options?: any): Promise<{ updated: number }>;
    delete(name: string, table: string, options?: any): Promise<{ deleted: number }>;
    rawQuery(name: string, sql: string, params?: any[]): Promise<{ rows: any[]; count: number }>;
    rawInsert(name: string, sql: string, params?: any[]): Promise<{ id: number }>;
    rawUpdate(name: string, sql: string, params?: any[]): Promise<{ affected: number }>;
    rawDelete(name: string, sql: string, params?: any[]): Promise<{ affected: number }>;
    execute(name: string, sql: string, params?: any[]): Promise<any>;
    batch(name: string, statements: any[]): Promise<any>;
    tableExists(name: string, table: string): Promise<{ exists: boolean }>;
    deleteDatabase(name: string): Promise<any>;
    getOpenDatabases(): Promise<{ databases: string[] }>;
    getInfo(): Promise<any>;
  };

  alarm: {
    set(options: { alarmId?: string; delayMs?: number; atMs?: number; title?: string; body?: string; repeating?: boolean; intervalMs?: number; payload?: any }): Promise<{ set: boolean; alarmId: string; fireAt: string }>;
    cancel(alarmId: string): Promise<any>;
    cancelAll(): Promise<any>;
    getAlarm(alarmId: string): Promise<any>;
    getAllAlarms(): Promise<{ alarms: any[]; count: number }>;
  };

  modelManager: {
    /** Opens the file picker; files or an archive (.zip, .tar.gz, .tar.bz2, .tar.xz) become one model. */
    import(options: { kind: string; name?: string; extensions?: string[]; extract?: boolean }): Promise<{ imported: boolean; reason?: string; model?: AiModel }>;
    list(kind?: string): Promise<{ models: AiModel[] }>;
    get(id: string): Promise<{ found: boolean; model?: AiModel }>;
    remove(id: string): Promise<{ removed: boolean }>;
    rename(id: string, name: string): Promise<{ model: AiModel }>;
    getInfo(): Promise<{ name: string; version: string; root: string; count: number; sizeBytes: number }>;
  };

  llm: {
    load(options: LlmLoadOptions): Promise<{ loaded: boolean; modelId?: string; contextSize: number; backend: string; vision: boolean; reason?: string }>;
    unload(): Promise<{ unloaded: boolean }>;
    /** Returns at once. Tokens arrive as 'llm.token' events, the end as 'llm.done' (or 'llm.error'). */
    chat(text: string, options?: LlmChatOptions): Promise<{ started: boolean; requestId?: string; reason?: string }>;
    stop(): Promise<{ stopped: boolean }>;
    reset(options?: { keepSystemPrompt?: boolean }): Promise<{ reset: boolean }>;
    setSystemPrompt(text: string | null): Promise<{ set: boolean }>;
    getHistory(): Promise<{ systemPrompt?: string; messages: { role: string; text: string }[] }>;
    countTokens(text: string): Promise<{ tokens: number }>;
    status(): Promise<{ loaded: boolean; loading: boolean; generating: boolean; modelId?: string; vision: boolean }>;
    getInfo(): Promise<any>;
  };

  speechOffline: {
    loadRecognizer(options: { modelId: string; type?: 'auto' | 'whisper' | 'transducer' | 'sense_voice' | 'paraformer'; language?: string; task?: 'transcribe' | 'translate'; threads?: number; tailPaddings?: number; decodingMethod?: string; useItn?: boolean }): Promise<{ loaded: boolean; modelId: string; type: string }>;
    unloadRecognizer(): Promise<{ unloaded: boolean }>;
    startListening(options?: { sampleRate?: number; maxSeconds?: number }): Promise<{ started: boolean; reason?: string; sampleRate?: number }>;
    stopListening(options?: { recognize?: boolean }): Promise<{ text: string; audioSeconds?: number; decodeMs?: number; reason?: string }>;
    cancelListening(): Promise<{ cancelled: boolean }>;
    transcribeFile(path: string): Promise<{ text: string; audioSeconds?: number; decodeMs?: number }>;
    loadSynthesizer(options: { modelId: string; type?: 'auto' | 'vits' | 'kokoro'; threads?: number; noiseScale?: number; noiseScaleW?: number; lengthScale?: number; silenceScale?: number; maxNumSentences?: number; lang?: string }): Promise<{ loaded: boolean; modelId: string; type: string; sampleRate: number; speakers: number }>;
    unloadSynthesizer(): Promise<{ unloaded: boolean }>;
    /** Queues text; synthesised ahead of playback. Events 'speechOffline.speak'. */
    speak(text: string, options?: { id?: string; speed?: number; speakerId?: number; silenceScale?: number; volume?: number; rate?: number }): Promise<{ queued: boolean; id?: string; reason?: string }>;
    synthesize(text: string, options?: { speed?: number; speakerId?: number; silenceScale?: number }): Promise<{ path: string; sampleRate: number; durationMs: number; synthMs: number }>;
    stopSpeaking(): Promise<{ stopped: boolean }>;
    setVolume(volume: number): Promise<{ volume: number }>;
    status(): Promise<any>;
    getInfo(): Promise<any>;
  };

  w2rayTunnel: {
    /** Shows the system VPN dialog the first time; resolves true when allowed. */
    prepare(): Promise<boolean>;
    /** Returns at once; follow 'w2rayTunnel.state' events. */
    start(config: W2rayConfig): Promise<boolean>;
    stop(): Promise<boolean>;
    status(): Promise<W2rayStatus>;
    logs(): Promise<{ level: 'D' | 'I' | 'W' | 'E'; time: number; message: string }[]>;
    clearLogs(): Promise<boolean>;
    /** Starts, changes or stops sharing while connected. */
    setShare(share: W2rayShareConfig): Promise<W2rayStatus>;
    /** Where other devices can reach this phone. */
    addresses(): Promise<{ interface: string; address: string; ipv6: boolean; kind: 'wifi' | 'hotspot' | 'usb' | 'bluetooth' | 'mobile' | 'other' }[]>;
    apps(): Promise<{ packageName: string; appName: string; isSystem: boolean }[]>;
    /** Base64 PNG, or null. */
    appIcon(packageName: string, size?: number): Promise<string | null>;
    test(config: W2rayConfig, deep?: boolean): Promise<{ serverMs: number; targetMs?: number }>;
    netInfo(): Promise<{ ip?: string; country?: string; countryCode?: string; region?: string; city?: string; isp?: string; org?: string; timezone?: string; serverMs: number; targetMs: number }>;
    openVpnSettings(): Promise<boolean>;
    getInfo(): Promise<any>;
  };

  // ... (rest of plugins follow same pattern)
  [key: string]: any;
}
