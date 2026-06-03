# ⚡ VLESS over WebSocket (WS) on Google Cloud Run + CDN

This project allows you to deploy a **VLESS proxy** server over **WebSocket** using **Xray-core**, fully containerized with Docker and deployed to **Google Cloud Run**, fronted by **Google Cloud CDN**.

---

## 🌟 Features

- ✔️ VLESS over WebSocket (WS)
- ✔️ Deployed on Google Cloud Run (serverless + autoscaling)
- ✔️ Works with Google Cloud Load Balancer + CDN
- ✔️ Dockerized and easy to deploy
- ✔️ Designed for domain fronting, bypassing, FreeNet

---

## ⚠️ Important Notice

- ❌ Google Cloud IPs starting with `34.*` and `35.*` **do NOT work** reliably with V2Ray/VLESS.
- ✅ Use a **custom domain with HTTPS** via **Google Load Balancer + CDN** for proper functionality.


## 📲 Client Configuration (V2Ray, Xray)

Use the following settings in your client app:

| Setting    | Value                                  |
| ---------- | -------------------------------------- |
| Protocol   | VLESS                                  |
| Address    | `your.domain.com`                      |
| Port       | `443` (HTTPS)                          |
| UUID       | `3675119c-14fc-46a4-b5f3-9a2c91a7d802` |
| Encryption | none                                   |
| Transport  | WebSocket (WS)                         |
| WS Path    | `/vless`                         |
| TLS        | Yes (via Google CDN)                   |

---

## 🧪 Tested Clients

* ✅ **Windows**: V2RayN
* ✅ **Android**: SagerNet / V2RayNG
* ✅ **iOS**: Shadowrocket / V2Box
* ✅ **macOS/Linux**: Xray CLI

---

## #Crd

---

## 🚀 Cloud Run One-Click GCP-VLESS-Cloud-Run

Run this script directly in **Google Cloud Shell**:

```bash

cd ~ && rm -rf VLESS-Cloud-Run && git clone https://github.com/niceday77/VLESS-Cloud-Run.git && cd VLESS-Cloud-Run && bash <(curl -Ls https://raw.githubusercontent.com/niceday77/VLESS-Cloud-Run/refs/heads/main/gcp-vless-cloud-run.sh)
