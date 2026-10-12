import { defineConfig } from 'vitepress';

export default defineConfig({
  title: 'Sweetmelon',
  description: 'Flutter Native Bridge — Run HTML apps with 91 native plugins',
  
  // SEO
  lang: 'en-US',
  head: [
    ['link', { rel: 'icon', href: '/favicon.ico' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:title', content: 'Sweetmelon — Flutter Native Bridge' }],
    ['meta', { property: 'og:description', content: 'Run Angular/React/Vue inside Flutter with 91 native plugins' }],
    ['meta', { property: 'og:image', content: '/og-image.png' }],
    ['meta', { name: 'twitter:card', content: 'summary_large_image' }],
  ],

  // Sitemap
  sitemap: {
    hostname: 'https://sweetmelon.dev',
  },

  // Theme
  themeConfig: {
    logo: '/logo.svg',
    siteTitle: 'Sweetmelon',
    
    // Search
    search: {
      provider: 'local',
      options: {
        detailedView: true,
      },
    },

    // Top Nav
    nav: [
      { text: 'Guide', link: '/guide/introduction' },
      { text: 'Plugins', link: '/plugins/overview' },
      { text: 'API', link: '/api/native-sdk' },
      { text: 'CLI', link: '/cli/overview' },
      { text: 'Examples', link: '/examples/angular-crud' },
      {
        text: 'v1.0.0',
        items: [
          { text: 'Changelog', link: '/changelog' },
          { text: 'Contributing', link: '/contributing' },
        ],
      },
    ],

    // Sidebar
    sidebar: {
      '/guide/': [
        {
          text: 'Getting Started',
          items: [
            { text: 'Introduction', link: '/guide/introduction' },
            { text: 'Getting Started', link: '/guide/getting-started' },
            { text: 'Installation', link: '/guide/installation' },
            { text: 'Configuration', link: '/guide/configuration' },
            { text: 'Project Structure', link: '/guide/project-structure' },
            { text: 'How It Works', link: '/guide/how-it-works' },
          ],
        },
        {
          text: 'Framework Integration',
          items: [
            { text: 'Angular', link: '/guide/frameworks/angular' },
            { text: 'React', link: '/guide/frameworks/react' },
            { text: 'Vue', link: '/guide/frameworks/vue' },
            { text: 'Vanilla JS', link: '/guide/frameworks/vanilla' },
          ],
        },
      ],

      '/plugins/': [
        {
          text: 'Overview',
          items: [
            { text: 'All Plugins', link: '/plugins/overview' },
          ],
        },
        {
          text: 'Core',
          collapsed: false,
          items: [
            { text: 'Permission', link: '/plugins/core/permission' },
            { text: 'App Lifecycle', link: '/plugins/core/app-lifecycle' },
            { text: 'Device Info', link: '/plugins/core/device-info' },
            { text: 'Connectivity', link: '/plugins/core/connectivity' },
            { text: 'Storage', link: '/plugins/core/storage' },
            { text: 'File System', link: '/plugins/core/file-system' },
            { text: 'HTTP', link: '/plugins/core/http' },
            { text: 'Intent / Deep Link', link: '/plugins/core/intent' },
            { text: 'Clipboard', link: '/plugins/core/clipboard' },
            { text: 'Share', link: '/plugins/core/share' },
          ],
        },
        {
          text: 'Media',
          collapsed: true,
          items: [
            { text: 'Camera', link: '/plugins/media/camera' },
            { text: 'Camera Preview', link: '/plugins/media/camera-preview' },
            { text: 'Audio', link: '/plugins/media/audio' },
            { text: 'Video Player', link: '/plugins/media/video-player' },
            { text: 'QR Scanner', link: '/plugins/media/qr-scanner' },
            { text: 'Document Scanner', link: '/plugins/media/document-scanner' },
          ],
        },
        {
          text: 'UI',
          collapsed: true,
          items: [
            { text: 'Dialog', link: '/plugins/ui/dialog' },
            { text: 'Toast', link: '/plugins/ui/toast' },
            { text: 'Action Sheet', link: '/plugins/ui/action-sheet' },
            { text: 'Date Picker', link: '/plugins/ui/date-picker' },
            { text: 'Status Bar', link: '/plugins/ui/status-bar' },
            { text: 'Navigation Bar', link: '/plugins/ui/navigation-bar' },
            { text: 'Orientation', link: '/plugins/ui/orientation' },
            { text: 'Splash Screen', link: '/plugins/ui/splash-screen' },
            { text: 'Text Zoom', link: '/plugins/ui/text-zoom' },
          ],
        },
        {
          text: 'Device',
          collapsed: true,
          items: [
            { text: 'Geolocation', link: '/plugins/device/geolocation' },
            { text: 'Sensors', link: '/plugins/device/sensors' },
            { text: 'Bluetooth', link: '/plugins/device/bluetooth' },
            { text: 'NFC', link: '/plugins/device/nfc' },
            { text: 'Biometrics', link: '/plugins/device/biometrics' },
            { text: 'Contacts', link: '/plugins/device/contacts' },
          ],
        },
        {
          text: 'Storage & Files',
          collapsed: true,
          items: [
            { text: 'Secure Storage', link: '/plugins/storage/secure-storage' },
            { text: 'Database', link: '/plugins/storage/database' },
            { text: 'File Picker', link: '/plugins/storage/file-picker' },
            { text: 'File Compressor', link: '/plugins/storage/file-compressor' },
            { text: 'Zip', link: '/plugins/storage/zip' },
          ],
        },
        {
          text: 'Network',
          collapsed: true,
          items: [
            { text: 'WebSocket', link: '/plugins/network/websocket' },
            { text: 'Download Manager', link: '/plugins/network/download-manager' },
            { text: 'WiFi', link: '/plugins/network/wifi-manager' },
          ],
        },
        {
          text: 'Security',
          collapsed: true,
          items: [
            { text: 'Encryption', link: '/plugins/security/encryption' },
            { text: 'Root Detection', link: '/plugins/security/root-detection' },
            { text: 'App Integrity', link: '/plugins/security/app-integrity' },
            { text: 'Privacy Screen', link: '/plugins/security/privacy-screen' },
          ],
        },
        {
          text: 'Firebase',
          collapsed: true,
          items: [
            { text: 'Analytics', link: '/plugins/firebase/analytics' },
            { text: 'Crashlytics', link: '/plugins/firebase/crashlytics' },
            { text: 'Auth', link: '/plugins/firebase/auth' },
            { text: 'Remote Config', link: '/plugins/firebase/remote-config' },
            { text: 'Push Notifications', link: '/plugins/firebase/push-notification' },
          ],
        },
        {
          text: 'Advanced',
          collapsed: true,
          items: [
            { text: 'Live Updater', link: '/plugins/advanced/live-updater' },
            { text: 'Background Task', link: '/plugins/advanced/background-task' },
            { text: 'In-App Purchase', link: '/plugins/advanced/in-app-purchase' },
            { text: 'OAuth2', link: '/plugins/advanced/oauth2' },
            { text: 'Social Login', link: '/plugins/advanced/social-login' },
            { text: 'Google Maps', link: '/plugins/advanced/google-maps' },
          ],
        },
      ],

      '/api/': [
        {
          text: 'API Reference',
          items: [
            { text: 'NativeSDK', link: '/api/native-sdk' },
            { text: 'NativeResilience', link: '/api/native-resilience' },
            { text: 'Events', link: '/api/events' },
            { text: 'TypeScript', link: '/api/typescript' },
          ],
        },
      ],

      '/cli/': [
        {
          text: 'CLI',
          items: [
            { text: 'Overview', link: '/cli/overview' },
            { text: 'Commands', link: '/cli/commands' },
            { text: 'Plugin Manager', link: '/cli/plugin-manager' },
          ],
        },
      ],

      '/advanced/': [
        {
          text: 'Advanced',
          items: [
            { text: 'Security', link: '/advanced/security' },
            { text: 'Performance', link: '/advanced/performance' },
            { text: 'Error Handling', link: '/advanced/error-handling' },
            { text: 'Offline Support', link: '/advanced/offline-support' },
            { text: 'Plugin Development', link: '/advanced/plugin-development' },
            { text: 'Migration', link: '/advanced/migration' },
          ],
        },
      ],

      '/deployment/': [
        {
          text: 'Deployment',
          items: [
            { text: 'Android', link: '/deployment/android' },
            { text: 'Play Store', link: '/deployment/play-store' },
            { text: 'ProGuard', link: '/deployment/proguard' },
            { text: 'Release Checklist', link: '/deployment/release-checklist' },
          ],
        },
      ],
    },

    // Footer
    footer: {
      message: 'Released under the MIT License',
      copyright: 'Copyright © 2024 Sweetmelon',
    },

    // Social links
    socialLinks: [
      { icon: 'github', link: 'https://github.com/your-org/sweetmelon' },
      { icon: 'discord', link: 'https://discord.gg/sweetmelon' },
    ],

    // Edit link
    editLink: {
      pattern: 'https://github.com/your-org/sweetmelon/edit/main/docs/:path',
      text: 'Edit this page on GitHub',
    },

    // Last updated
    lastUpdated: {
      text: 'Updated at',
      formatOptions: {
        dateStyle: 'medium',
        timeStyle: 'short',
      },
    },
  },

  // Markdown
  markdown: {
    lineNumbers: true,
    theme: {
      light: 'github-light',
      dark: 'github-dark',
    },
  },
});
