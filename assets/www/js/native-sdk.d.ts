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

  // ... (rest of plugins follow same pattern)
  [key: string]: any;
}
