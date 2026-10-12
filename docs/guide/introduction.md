# Introduction

## What is Sweetmelon?

Sweetmelon is a **Flutter-based native bridge** that lets you run HTML/CSS/JS applications (Angular, React, Vue, or vanilla) inside a Flutter WebView while providing access to **104 native device APIs** through a simple JavaScript SDK.

Think of it as an alternative to **Capacitor** or **Cordova**, but built on Flutter's powerful engine.

## Why Sweetmelon?

### vs Capacitor
| Feature | Sweetmelon | Capacitor |
|---------|-----------|-----------|
| Runtime | Flutter | Native Android/iOS |
| Plugins | 104 built-in | ~80 (community) |
| Live Updates | ✅ Built-in | Via Capgo (paid) |
| Security | ✅ 5 layers | Basic |
| Offline Queue | ✅ Built-in | Manual |
| Plugin Dev | Dart | Java/Kotlin + Swift |

### vs React Native / Flutter
| Feature | Sweetmelon | React Native | Pure Flutter |
|---------|-----------|-------------|-------------|
| UI Technology | HTML/CSS/JS | React | Dart/Widgets |
| Learning Curve | Low (web devs) | Medium | High |
| Web Reuse | ✅ 100% | ❌ | ❌ |
| Native Access | 104 plugins | Many packages | Many packages |
| Performance | Good | Very Good | Excellent |

### When to use Sweetmelon

✅ **Use when:**
- You have an existing web app (Angular/React/Vue)
- Your team knows web technologies
- You need quick native features
- You want live updates without store review
- You need offline-first with sync

❌ **Don't use when:**
- You need maximum performance (games, heavy animations)
- You're building from scratch (consider pure Flutter)
- You need advanced native UI components

## Core Concepts

### 1. Bridge
The communication layer between JavaScript and Dart/Native code.

### 2. Plugins
Self-contained modules that expose native APIs to JavaScript.

### 3. NativeSDK
The JavaScript wrapper that provides a clean API for all plugins.

### 4. Asset Server
A local HTTP server that serves your HTML/CSS/JS files to the WebView.

### 5. Security Manager
Authentication, signing, and protection for the bridge communication.

## Architecture

```
Your Web App (Angular/React/Vue)
        ↓
   NativeSDK.call()
        ↓
   Message Bridge (JSON protocol)
        ↓
   Security Layer (auth + signing)
        ↓
   Plugin Manager (cache + rate limit)
        ↓
   Plugin Registry (104 plugins)
        ↓
   Native APIs (Android/iOS)
```
