import { defineConfig } from 'vitepress';

export default defineConfig({
  title: 'Sweetmelon',
  description: 'Flutter Native Bridge — JS to Native',
  themeConfig: {
    logo: '🍈',
    nav: [
      { text: 'Guide', link: '/guide/getting-started' },
      { text: 'Plugins', link: '/plugins/overview' },
      { text: 'API', link: '/api/native-sdk' },
      { text: 'Changelog', link: '/changelog' },
    ],
    sidebar: {
      '/guide/': [
        {
          text: 'Getting Started',
          items: [
            { text: 'Introduction', link: '/guide/introduction' },
            { text: 'Installation', link: '/guide/installation' },
            { text: 'Quick Start', link: '/guide/quick-start' },
            { text: 'Configuration', link: '/guide/configuration' },
          ],
        },
        {
          text: 'Framework Integration',
          items: [
            { text: 'Angular', link: '/guide/angular' },
            { text: 'React', link: '/guide/react' },
            { text: 'Vue', link: '/guide/vue' },
            { text: 'Vanilla JS', link: '/guide/vanilla' },
          ],
        },
      ],
      '/plugins/': [
        {
          text: 'Phase 1 — Core',
          items: [
            { text: 'Permission', link: '/plugins/permission' },
            { text: 'App Lifecycle', link: '/plugins/app-lifecycle' },
            { text: 'Device Info', link: '/plugins/device-info' },
            { text: 'Connectivity', link: '/plugins/connectivity' },
            { text: 'Storage', link: '/plugins/storage' },
            { text: 'File System', link: '/plugins/file-system' },
            { text: 'HTTP', link: '/plugins/http' },
            { text: 'Intent', link: '/plugins/intent' },
            { text: 'Clipboard', link: '/plugins/clipboard' },
            { text: 'Share', link: '/plugins/share' },
            { text: 'Camera', link: '/plugins/camera' },
            { text: 'Geolocation', link: '/plugins/geolocation' },
          ],
        },
        {
          text: 'Firebase',
          items: [
            { text: 'Analytics', link: '/plugins/firebase-analytics' },
            { text: 'Crashlytics', link: '/plugins/firebase-crashlytics' },
            { text: 'Remote Config', link: '/plugins/firebase-remote-config' },
            { text: 'Auth', link: '/plugins/firebase-auth' },
          ],
        },
      ],
    },
    socialLinks: [
      { icon: 'github', link: 'https://github.com/your-org/sweetmelon' },
    ],
    footer: {
      message: 'Sweetmelon Native Bridge',
      copyright: 'MIT License',
    },
  },
});
