# ⚡ VLESS over WebSocket (WS) on Google Cloud Run + CDN

This project allows you to deploy a **VLESS proxy** server over **WebSocket** using **Xray-core**, fully containerized with Docker and deployed to **Google Cloud Run**, fronted by **Google Cloud CDN**.

---

## 🌟 Features

- ✔️ VLESS over WebSocket (WS)
- ✔️ Deployed on Google Cloud Run (serverless + autoscaling)
- ✔️ Dockerized and easy to deploy

---

## 📲 Client Configuration (V2Ray, Xray)

Use the following settings in your client app:

| Setting    | Value                                  |
| ---------- | -------------------------------------- |
| Protocol   | VLESS                                  |
| Address    | `your.domain.com`                      |
| Port       | `443` (HTTPS)                          |
| UUID       | `33d55e97-26ab-4e59-9f37-7a944044baaa` |
| Encryption | none                                   |
| Transport  | WebSocket (WS)                         |
| WS Path    | `/`                                    |
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

## 🚀 Cloud Run One-Click with the Virtual meters

Run this script directly in **Google Cloud Shell**:

```bash

cd ~ && rm -rf VLESS-Cloud-Run && git clone https://github.com/niceday77/VLESS-Cloud-Run.git && cd VLESS-Cloud-Run && bash <(curl -Ls https://raw.githubusercontent.com/niceday77/VLESS-Cloud-Run/refs/heads/main/gcp-vless-cloud-run2.sh)

---

## #Crd2

---

## 🚀 Cloud Run One-Click GCP-VLESS-Cloud-Run

Run this script directly in **Google Cloud Shell**:

```bash

cd ~ && rm -rf VLESS-Cloud-Run && git clone https://github.com/niceday77/VLESS-Cloud-Run.git && cd VLESS-Cloud-Run && bash <(curl -Ls https://raw.githubusercontent.com/niceday77/VLESS-Cloud-Run/refs/heads/main/gcp-vless-cloud-run.sh)
